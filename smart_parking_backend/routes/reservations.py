from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.db import execute_query, execute_one
from models.audit import log_action
from notifications import notify_user, schedule_notification
from datetime import datetime, timedelta
import secrets
import string

reservations_bp = Blueprint('reservations', __name__)


def _generate_qr_code():
    chars = string.ascii_uppercase + string.digits
    return 'SP-' + ''.join(secrets.choice(chars) for _ in range(12))


@reservations_bp.route('/', methods=['POST'])
@jwt_required()
def create_reservation():
    user_id = int(get_jwt_identity())
    data = request.get_json()

    
    user = execute_one('SELECT premium FROM users WHERE id=%s', (user_id,))
    if not user or not user['premium']:
        return jsonify({'error': 'Rezervacije su dostupne samo Premium korisnicima'}), 403

    
    required = ['parking_id', 'vehicle_id', 'start_time', 'duration_min']
    for f in required:
        if not data.get(f):
            return jsonify({'error': f'Polje {f} je obavezno'}), 400

    
    parking = execute_one(
        'SELECT * FROM parkings WHERE id=%s AND aktivno=TRUE',
        (data['parking_id'],)
    )
    if not parking:
        return jsonify({'error': 'Parking nije dostupan'}), 404

    if parking['available_spots'] == 0:
        return jsonify({'error': 'Parking je pun'}), 409

    
    vehicle = execute_one(
        'SELECT * FROM vehicles WHERE id=%s AND user_id=%s',
        (data['vehicle_id'], user_id)
    )
    if not vehicle:
        return jsonify({'error': 'Vozilo nije pronađeno'}), 404

    
    duration_min = int(data['duration_min'])
    duration_h = duration_min / 60
    total_price = round(float(parking['price_per_hour']) * duration_h, 2)

    start_time = datetime.fromisoformat(data['start_time'])
    end_time = start_time + timedelta(minutes=duration_min)

    qr_code = _generate_qr_code()

    
    res_id = execute_query(
        '''INSERT INTO reservations
           (user_id, parking_id, vehicle_id, status, start_time, end_time,
            duration_min, total_price, qr_code)
           VALUES (%s, %s, %s, 'confirmed', %s, %s, %s, %s, %s)''',
        (user_id, data['parking_id'], data['vehicle_id'],
         start_time, end_time, duration_min, total_price, qr_code),
        fetch=False, commit=True
    )

    user_row = execute_one('SELECT email FROM users WHERE id=%s', (user_id,))
    log_action('reservation_create', user_id=user_id,
               actor_email=user_row['email'] if user_row else None,
               details={'reservation_id': res_id, 'parking_id': data['parking_id'],
                        'total_price': total_price})

    
    notify_user(
        user_id, 'reservation',
        'Rezervacija potvrđena ✅',
        f"Rezervisali ste mjesto na parkingu {parking['naziv']} u trajanju od {duration_min} min.",
        {'reservation_id': res_id, 'parking_id': data['parking_id']},
    )
    
    
    seconds_until_reminder = (end_time - datetime.now()).total_seconds() - 600
    schedule_notification(
        user_id, seconds_until_reminder, 'reservation',
        'Rezervacija uskoro ističe ⏰',
        f"Vaša rezervacija na parkingu {parking['naziv']} ističe za 10 minuta.",
        {'reservation_id': res_id, 'parking_id': data['parking_id']},
    )

    return jsonify({
        'reservation_id': res_id,
        'qr_code': qr_code,
        'status': 'confirmed',
        'parking': parking['naziv'],
        'start_time': start_time.isoformat(),
        'end_time': end_time.isoformat(),
        'duration_min': duration_min,
        'total_price': total_price,
        'vehicle': vehicle['tablice']
    }), 201


@reservations_bp.route('/my', methods=['GET'])
@jwt_required()
def my_reservations():
    user_id = int(get_jwt_identity())

    reservations = execute_query(
        '''SELECT r.*, p.naziv AS parking_naziv, p.adresa,
                  v.tablice, v.vrsta AS vrsta_vozila
           FROM reservations r
           JOIN parkings p ON r.parking_id = p.id
           JOIN vehicles v ON r.vehicle_id = v.id
           WHERE r.user_id = %s
           ORDER BY r.start_time DESC
           LIMIT 20''',
        (user_id,)
    )

    return jsonify(reservations), 200


@reservations_bp.route('/<int:res_id>/cancel', methods=['PUT'])
@jwt_required()
def cancel_reservation(res_id):
    user_id = int(get_jwt_identity())

    res = execute_one(
        'SELECT * FROM reservations WHERE id=%s AND user_id=%s',
        (res_id, user_id)
    )
    if not res:
        return jsonify({'error': 'Rezervacija nije pronađena'}), 404

    if res['status'] in ('completed', 'cancelled'):
        return jsonify({'error': 'Rezervacija se ne može otkazati'}), 400

    execute_query(
        "UPDATE reservations SET status='cancelled' WHERE id=%s",
        (res_id,), fetch=False, commit=True
    )

    user_row = execute_one('SELECT email FROM users WHERE id=%s', (user_id,))
    log_action('reservation_cancel', user_id=user_id,
               actor_email=user_row['email'] if user_row else None,
               details={'reservation_id': res_id})

    notify_user(
        user_id, 'reservation',
        'Rezervacija otkazana',
        'Vaša rezervacija je uspješno otkazana.',
        {'reservation_id': res_id},
    )

    return jsonify({'message': 'Rezervacija otkazana'}), 200
