import bcrypt
from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from models.db import execute_query, execute_one
from models.audit import log_action
from utils.auth_utils import admin_required
from notifications import notify_user
from utils.mailer import send_manager_welcome_email

admin_bp = Blueprint('admin', __name__)


@admin_bp.route('/dashboard', methods=['GET'])
@admin_required
def dashboard():
    users_count = execute_one('SELECT COUNT(*) AS c FROM users')['c']
    parkings_count = execute_one('SELECT COUNT(*) AS c FROM parkings WHERE aktivno=1')['c']
    reservations_today = execute_one(
        "SELECT COUNT(*) AS c FROM reservations WHERE DATE(created_at)=CURDATE()"
    )['c']
    spots = execute_one(
        'SELECT COALESCE(SUM(total_spots),0) AS total, COALESCE(SUM(available_spots),0) AS free '
        'FROM parkings WHERE aktivno=1'
    )
    recent_actions = execute_query(
        'SELECT id, actor_email, action, created_at FROM audit_log ORDER BY created_at DESC LIMIT 10'
    )
    return jsonify({
        'users_count': users_count,
        'parkings_count': parkings_count,
        'reservations_today': reservations_today,
        'total_spots': spots['total'],
        'free_spots': spots['free'],
        'occupancy_pct': round(100 * (1 - spots['free'] / spots['total']), 1) if spots['total'] else 0,
        'recent_actions': recent_actions,
    }), 200


@admin_bp.route('/users', methods=['GET'])
@admin_required
def list_users():
    search = request.args.get('q', '').strip()
    base = '''SELECT u.id, u.ime, u.prezime, u.email, u.telefon, u.premium,
                     u.role, u.status, u.created_at,
                     (SELECT COUNT(*) FROM reservations r WHERE r.user_id=u.id) AS reservations_count,
                     (SELECT COUNT(*) FROM vehicles v WHERE v.user_id=u.id) AS vehicles_count
              FROM users u'''
    params = ()
    if search:
        base += ' WHERE u.ime LIKE %s OR u.prezime LIKE %s OR u.email LIKE %s'
        like = f'%{search}%'
        params = (like, like, like)
    base += ' ORDER BY u.created_at DESC'
    users = execute_query(base, params)
    return jsonify(users), 200


@admin_bp.route('/users/<int:user_id>', methods=['PUT'])
@admin_required
def update_user(user_id):
    admin_id = int(get_jwt_identity())
    data = request.get_json() or {}

    fields, params = [], []
    if 'role' in data and data['role'] in ('user', 'admin'):
        fields.append('role=%s'); params.append(data['role'])
    if 'status' in data and data['status'] in ('active', 'blocked'):
        fields.append('status=%s'); params.append(data['status'])
    if 'premium' in data:
        fields.append('premium=%s'); params.append(bool(data['premium']))

    if not fields:
        return jsonify({'error': 'Nema polja za ažuriranje'}), 400

    params.append(user_id)
    execute_query(f'UPDATE users SET {", ".join(fields)} WHERE id=%s', tuple(params),
                   fetch=False, commit=True)

    admin = execute_one('SELECT email FROM users WHERE id=%s', (admin_id,))
    log_action('admin_user_update', user_id=admin_id,
               actor_email=admin['email'] if admin else None,
               details={'target_user_id': user_id, 'changes': data})

    return jsonify({'message': 'Korisnik ažuriran'}), 200


@admin_bp.route('/audit-log', methods=['GET'])
@admin_required
def audit_log_list():
    limit = min(int(request.args.get('limit', 100)), 500)
    action_filter = request.args.get('action')

    query = 'SELECT * FROM audit_log'
    params = []
    if action_filter:
        query += ' WHERE action = %s'
        params.append(action_filter)
    query += ' ORDER BY created_at DESC LIMIT %s'
    params.append(limit)

    logs = execute_query(query, tuple(params))
    return jsonify(logs), 200


@admin_bp.route('/parkings', methods=['GET'])
@admin_required
def admin_list_parkings():
    parkings = execute_query('SELECT * FROM parking_status ORDER BY naziv')
    return jsonify(parkings), 200


@admin_bp.route('/parkings', methods=['POST'])
@admin_required
def create_parking():
    admin_id = int(get_jwt_identity())
    data = request.get_json() or {}

    required = ['naziv', 'lat', 'lng', 'total_spots', 'price_per_hour']
    for f in required:
        if data.get(f) in (None, ''):
            return jsonify({'error': f'Polje "{f}" je obavezno'}), 400

    pid = execute_query(
        '''INSERT INTO parkings
           (naziv, adresa, lat, lng, total_spots, available_spots, price_per_hour,
            lambda_val, mu_val, radno_vrijeme, aktivno)
           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)''',
        (data['naziv'], data.get('adresa'), data['lat'], data['lng'],
         int(data['total_spots']), int(data.get('available_spots', data['total_spots'])),
         float(data['price_per_hour']), float(data.get('lambda_val', 1.5)),
         float(data.get('mu_val', 0.5)), data.get('radno_vrijeme', '00:00 - 24:00'),
         bool(data.get('aktivno', True))),
        fetch=False, commit=True
    )

    admin = execute_one('SELECT email FROM users WHERE id=%s', (admin_id,))
    log_action('admin_parking_create', user_id=admin_id,
               actor_email=admin['email'] if admin else None,
               details={'parking_id': pid, 'naziv': data['naziv']})

    return jsonify({'message': 'Parking kreiran', 'id': pid}), 201


@admin_bp.route('/parkings/<int:parking_id>', methods=['PUT'])
@admin_required
def update_parking(parking_id):
    admin_id = int(get_jwt_identity())
    data = request.get_json() or {}

    allowed = {
        'naziv': 'naziv', 'adresa': 'adresa', 'lat': 'lat', 'lng': 'lng',
        'total_spots': 'total_spots', 'available_spots': 'available_spots',
        'price_per_hour': 'price_per_hour', 'lambda_val': 'lambda_val',
        'mu_val': 'mu_val', 'radno_vrijeme': 'radno_vrijeme', 'aktivno': 'aktivno',
    }
    fields, params = [], []
    for key, col in allowed.items():
        if key in data:
            fields.append(f'{col}=%s')
            params.append(data[key])

    if not fields:
        return jsonify({'error': 'Nema polja za ažuriranje'}), 400

    params.append(parking_id)
    execute_query(f'UPDATE parkings SET {", ".join(fields)} WHERE id=%s', tuple(params),
                   fetch=False, commit=True)

    admin = execute_one('SELECT email FROM users WHERE id=%s', (admin_id,))
    log_action('admin_parking_update', user_id=admin_id,
               actor_email=admin['email'] if admin else None,
               details={'parking_id': parking_id, 'changes': data})

    return jsonify({'message': 'Parking ažuriran'}), 200


@admin_bp.route('/parkings/<int:parking_id>', methods=['DELETE'])
@admin_required
def delete_parking(parking_id):
    admin_id = int(get_jwt_identity())
    execute_query('UPDATE parkings SET aktivno=0 WHERE id=%s', (parking_id,),
                   fetch=False, commit=True)

    admin = execute_one('SELECT email FROM users WHERE id=%s', (admin_id,))
    log_action('admin_parking_delete', user_id=admin_id,
               actor_email=admin['email'] if admin else None,
               details={'parking_id': parking_id})

    return jsonify({'message': 'Parking deaktiviran'}), 200


@admin_bp.route('/chat/threads', methods=['GET'])
@admin_required
def chat_threads():
    threads = execute_query(
        '''SELECT
             m.user_id, m.parking_id,
             u.ime, u.prezime, u.email,
             p.naziv AS parking_naziv,
             MAX(m.created_at) AS last_message_at,
             SUBSTRING_INDEX(GROUP_CONCAT(m.poruka ORDER BY m.created_at DESC SEPARATOR '\u0001'), '\u0001', 1) AS last_message,
             SUM(CASE WHEN m.sender = 'user' AND m.procitano_admin = FALSE THEN 1 ELSE 0 END) AS unread_count
           FROM parking_chat_messages m
           JOIN users u ON u.id = m.user_id
           JOIN parkings p ON p.id = m.parking_id
           GROUP BY m.user_id, m.parking_id, u.ime, u.prezime, u.email, p.naziv
           ORDER BY unread_count DESC, last_message_at DESC''',
    )
    return jsonify(threads), 200


@admin_bp.route('/chat/<int:user_id>/<int:parking_id>', methods=['GET'])
@admin_required
def chat_thread_messages(user_id, parking_id):
    messages = execute_query(
        '''SELECT * FROM parking_chat_messages
           WHERE user_id=%s AND parking_id=%s
           ORDER BY created_at ASC''',
        (user_id, parking_id)
    )
    execute_query(
        '''UPDATE parking_chat_messages SET procitano_admin = TRUE
           WHERE user_id=%s AND parking_id=%s AND sender='user' ''',
        (user_id, parking_id), fetch=False, commit=True
    )
    user = execute_one('SELECT id, ime, prezime, email FROM users WHERE id=%s', (user_id,))
    parking = execute_one('SELECT id, naziv FROM parkings WHERE id=%s', (parking_id,))
    return jsonify({'messages': messages, 'user': user, 'parking': parking}), 200


@admin_bp.route('/chat/<int:user_id>/<int:parking_id>', methods=['POST'])
@admin_required
def chat_thread_reply(user_id, parking_id):
    admin_id = int(get_jwt_identity())
    data = request.get_json() or {}
    poruka = (data.get('poruka') or '').strip()
    if not poruka:
        return jsonify({'error': 'Poruka ne smije biti prazna'}), 400

    parking = execute_one('SELECT naziv FROM parkings WHERE id=%s', (parking_id,))
    if not parking:
        return jsonify({'error': 'Parking nije pronađen'}), 404

    msg_id = execute_query(
        '''INSERT INTO parking_chat_messages
           (user_id, parking_id, sender, poruka, procitano)
           VALUES (%s, %s, 'parking', %s, FALSE)''',
        (user_id, parking_id, poruka), fetch=False, commit=True
    )
    sent = execute_one('SELECT * FROM parking_chat_messages WHERE id=%s', (msg_id,))

    notify_user(
        user_id, 'chat',
        f"Nova poruka — {parking['naziv']} 💬",
        poruka,
        {'parking_id': parking_id},
    )

    admin = execute_one('SELECT email FROM users WHERE id=%s', (admin_id,))
    log_action('admin_chat_reply', user_id=admin_id,
               actor_email=admin['email'] if admin else None,
               details={'target_user_id': user_id, 'parking_id': parking_id})

    return jsonify({'message': sent}), 201


@admin_bp.route('/reports', methods=['GET'])
@admin_required
def admin_list_reports():
    status_filter = request.args.get('status')
    parking_filter = request.args.get('parking_id')

    query = '''SELECT r.*, u.ime, u.prezime, u.email, p.naziv AS parking_naziv
               FROM parking_reports r
               JOIN users u ON r.user_id = u.id
               JOIN parkings p ON r.parking_id = p.id
               WHERE 1=1'''
    params = []
    if status_filter:
        query += ' AND r.status = %s'
        params.append(status_filter)
    if parking_filter:
        query += ' AND r.parking_id = %s'
        params.append(parking_filter)
    query += ' ORDER BY r.created_at DESC'

    reports = execute_query(query, tuple(params))
    return jsonify(reports), 200


@admin_bp.route('/managers', methods=['GET'])
@admin_required
def list_managers():
    managers = execute_query(
        '''SELECT u.id, u.ime, u.prezime, u.email, u.telefon, u.status, u.created_at,
                  u.parking_id, p.naziv AS parking_naziv
           FROM users u
           LEFT JOIN parkings p ON p.id = u.parking_id
           WHERE u.role = 'manager'
           ORDER BY u.created_at DESC'''
    )
    return jsonify(managers), 200


@admin_bp.route('/managers', methods=['POST'])
@admin_required
def create_manager():
    admin_id = int(get_jwt_identity())
    data = request.get_json() or {}

    required = ['ime', 'prezime', 'email', 'lozinka', 'parking_id']
    for f in required:
        if not data.get(f):
            return jsonify({'error': f'Polje "{f}" je obavezno'}), 400

    existing = execute_one('SELECT id FROM users WHERE email=%s', (data['email'],))
    if existing:
        return jsonify({'error': 'Korisnik s ovim emailom već postoji'}), 409

    parking = execute_one('SELECT id, naziv FROM parkings WHERE id=%s', (data['parking_id'],))
    if not parking:
        return jsonify({'error': 'Parking nije pronađen'}), 404

    hashed = bcrypt.hashpw(data['lozinka'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    manager_id = execute_query(
        '''INSERT INTO users (ime, prezime, email, lozinka, telefon, role, status,
                               email_verified, parking_id)
           VALUES (%s, %s, %s, %s, %s, 'manager', 'active', TRUE, %s)''',
        (data['ime'], data['prezime'], data['email'], hashed,
         data.get('telefon'), data['parking_id']),
        fetch=False, commit=True
    )

    send_manager_welcome_email(data['email'], data['ime'], parking['naziv'], data['lozinka'])

    admin = execute_one('SELECT email FROM users WHERE id=%s', (admin_id,))
    log_action('admin_manager_create', user_id=admin_id,
               actor_email=admin['email'] if admin else None,
               details={'manager_id': manager_id, 'parking_id': data['parking_id']})

    manager = execute_one(
        '''SELECT u.id, u.ime, u.prezime, u.email, u.telefon, u.status, u.created_at,
                  u.parking_id, p.naziv AS parking_naziv
           FROM users u LEFT JOIN parkings p ON p.id = u.parking_id
           WHERE u.id=%s''',
        (manager_id,)
    )
    return jsonify({'message': 'Upravnik kreiran', 'manager': manager}), 201


@admin_bp.route('/managers/<int:manager_id>', methods=['PUT'])
@admin_required
def update_manager(manager_id):
    admin_id = int(get_jwt_identity())
    data = request.get_json() or {}

    target = execute_one("SELECT id FROM users WHERE id=%s AND role='manager'", (manager_id,))
    if not target:
        return jsonify({'error': 'Upravnik nije pronađen'}), 404

    fields, params = [], []
    if 'ime' in data:
        fields.append('ime=%s'); params.append(data['ime'])
    if 'prezime' in data:
        fields.append('prezime=%s'); params.append(data['prezime'])
    if 'telefon' in data:
        fields.append('telefon=%s'); params.append(data['telefon'])
    if 'parking_id' in data:
        parking = execute_one('SELECT id FROM parkings WHERE id=%s', (data['parking_id'],))
        if not parking:
            return jsonify({'error': 'Parking nije pronađen'}), 404
        fields.append('parking_id=%s'); params.append(data['parking_id'])
    if 'status' in data and data['status'] in ('active', 'blocked'):
        fields.append('status=%s'); params.append(data['status'])
    if data.get('lozinka'):
        hashed = bcrypt.hashpw(data['lozinka'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        fields.append('lozinka=%s'); params.append(hashed)

    if not fields:
        return jsonify({'error': 'Nema polja za ažuriranje'}), 400

    params.append(manager_id)
    execute_query(f'UPDATE users SET {", ".join(fields)} WHERE id=%s', tuple(params),
                   fetch=False, commit=True)

    admin = execute_one('SELECT email FROM users WHERE id=%s', (admin_id,))
    log_action('admin_manager_update', user_id=admin_id,
               actor_email=admin['email'] if admin else None,
               details={'manager_id': manager_id, 'changes': {k: v for k, v in data.items() if k != 'lozinka'}})

    manager = execute_one(
        '''SELECT u.id, u.ime, u.prezime, u.email, u.telefon, u.status, u.created_at,
                  u.parking_id, p.naziv AS parking_naziv
           FROM users u LEFT JOIN parkings p ON p.id = u.parking_id
           WHERE u.id=%s''',
        (manager_id,)
    )
    return jsonify({'message': 'Upravnik ažuriran', 'manager': manager}), 200


@admin_bp.route('/managers/<int:manager_id>', methods=['DELETE'])
@admin_required
def delete_manager(manager_id):
    admin_id = int(get_jwt_identity())
    target = execute_one("SELECT id FROM users WHERE id=%s AND role='manager'", (manager_id,))
    if not target:
        return jsonify({'error': 'Upravnik nije pronađen'}), 404

    execute_query("UPDATE users SET status='blocked' WHERE id=%s", (manager_id,),
                   fetch=False, commit=True)

    admin = execute_one('SELECT email FROM users WHERE id=%s', (admin_id,))
    log_action('admin_manager_delete', user_id=admin_id,
               actor_email=admin['email'] if admin else None,
               details={'manager_id': manager_id})

    return jsonify({'message': 'Upravnik deaktiviran'}), 200
