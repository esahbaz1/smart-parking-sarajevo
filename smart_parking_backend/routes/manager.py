from flask import Blueprint, request, jsonify, g
from flask_jwt_extended import get_jwt_identity

from models.db import execute_query, execute_one
from models.audit import log_action
from utils.auth_utils import manager_required
from notifications import notify_user

manager_bp = Blueprint('manager', __name__)


@manager_bp.route('/dashboard', methods=['GET'])
@manager_required
def dashboard():
    pid = g.manager_parking_id
    parking = execute_one('SELECT * FROM parking_status WHERE id=%s', (pid,))
    if not parking:
        return jsonify({'error': 'Parking nije pronađen'}), 404

    reservations_today = execute_one(
        "SELECT COUNT(*) AS c FROM reservations WHERE parking_id=%s AND DATE(created_at)=CURDATE()",
        (pid,)
    )['c']

    open_reports = execute_one(
        "SELECT COUNT(*) AS c FROM parking_reports WHERE parking_id=%s AND status != 'rijesena'",
        (pid,)
    )['c']

    unread_chat = execute_one(
        "SELECT COUNT(*) AS c FROM parking_chat_messages "
        "WHERE parking_id=%s AND sender='user' AND procitano_admin=FALSE",
        (pid,)
    )['c']

    hourly = execute_query(
        '''SELECT
             HOUR(created_at) AS sat,
             COUNT(CASE WHEN event_type = 'entry' THEN 1 END) AS ulasci,
             COUNT(CASE WHEN event_type = 'exit'  THEN 1 END) AS izlasci
           FROM sensor_logs
           WHERE parking_id = %s AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
           GROUP BY HOUR(created_at)
           ORDER BY sat''',
        (pid,)
    )
    hourly_map = {row['sat']: row for row in hourly}
    hourly_data = [hourly_map.get(h, {'sat': h, 'ulasci': 0, 'izlasci': 0}) for h in range(24)]

    return jsonify({
        'parking': parking,
        'reservations_today': reservations_today,
        'open_reports': open_reports,
        'unread_chat': unread_chat,
        'hourly_data': hourly_data,
    }), 200


@manager_bp.route('/spots', methods=['GET'])
@manager_required
def spots():
    pid = g.manager_parking_id
    rows = execute_query(
        '''SELECT s.id, s.spot_number, s.zaueto, s.vehicle_tablice, s.zauzeto_od,
                  r.id AS report_id, r.status AS report_status, r.opis AS report_opis
           FROM parking_spots s
           LEFT JOIN parking_reports r
             ON r.spot_id = s.id AND r.status != 'rijesena'
           WHERE s.parking_id = %s
           ORDER BY s.spot_number''',
        (pid,)
    )
    return jsonify(rows), 200


@manager_bp.route('/reports', methods=['GET'])
@manager_required
def reports():
    pid = g.manager_parking_id
    status_filter = request.args.get('status')
    query = '''SELECT r.*, u.ime, u.prezime, u.email
               FROM parking_reports r
               JOIN users u ON r.user_id = u.id
               WHERE r.parking_id = %s'''
    params = [pid]
    if status_filter:
        query += ' AND r.status = %s'
        params.append(status_filter)
    query += ' ORDER BY r.created_at DESC'
    rows = execute_query(query, tuple(params))
    return jsonify(rows), 200


@manager_bp.route('/chat/threads', methods=['GET'])
@manager_required
def chat_threads():
    pid = g.manager_parking_id
    threads = execute_query(
        '''SELECT
             m.user_id, m.parking_id,
             u.ime, u.prezime, u.email,
             MAX(m.created_at) AS last_message_at,
             SUBSTRING_INDEX(GROUP_CONCAT(m.poruka ORDER BY m.created_at DESC SEPARATOR '\u0001'), '\u0001', 1) AS last_message,
             SUM(CASE WHEN m.sender = 'user' AND m.procitano_admin = FALSE THEN 1 ELSE 0 END) AS unread_count
           FROM parking_chat_messages m
           JOIN users u ON u.id = m.user_id
           WHERE m.parking_id = %s
           GROUP BY m.user_id, m.parking_id, u.ime, u.prezime, u.email
           ORDER BY unread_count DESC, last_message_at DESC''',
        (pid,)
    )
    return jsonify(threads), 200


@manager_bp.route('/chat/<int:user_id>', methods=['GET'])
@manager_required
def chat_thread_messages(user_id):
    pid = g.manager_parking_id
    messages = execute_query(
        '''SELECT * FROM parking_chat_messages
           WHERE user_id=%s AND parking_id=%s
           ORDER BY created_at ASC''',
        (user_id, pid)
    )
    execute_query(
        '''UPDATE parking_chat_messages SET procitano_admin = TRUE
           WHERE user_id=%s AND parking_id=%s AND sender='user' ''',
        (user_id, pid), fetch=False, commit=True
    )
    user = execute_one('SELECT id, ime, prezime, email FROM users WHERE id=%s', (user_id,))
    return jsonify({'messages': messages, 'user': user}), 200


@manager_bp.route('/chat/<int:user_id>', methods=['POST'])
@manager_required
def chat_thread_reply(user_id):
    pid = g.manager_parking_id
    data = request.get_json() or {}
    poruka = (data.get('poruka') or '').strip()
    if not poruka:
        return jsonify({'error': 'Poruka ne smije biti prazna'}), 400

    parking = execute_one('SELECT naziv FROM parkings WHERE id=%s', (pid,))

    msg_id = execute_query(
        '''INSERT INTO parking_chat_messages (user_id, parking_id, sender, poruka, procitano)
           VALUES (%s, %s, 'parking', %s, FALSE)''',
        (user_id, pid, poruka), fetch=False, commit=True
    )
    sent = execute_one('SELECT * FROM parking_chat_messages WHERE id=%s', (msg_id,))

    notify_user(
        user_id, 'chat',
        f"Nova poruka — {parking['naziv']} 💬",
        poruka,
        {'parking_id': pid},
    )

    log_action('manager_chat_reply', user_id=g.manager_user_id, actor_email=g.manager_email,
               details={'target_user_id': user_id, 'parking_id': pid})

    return jsonify({'message': sent}), 201
