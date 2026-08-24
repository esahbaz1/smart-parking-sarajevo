from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from models.db import execute_query, execute_one
from notifications import notify_staff

chat_bp = Blueprint('chat', __name__)


@chat_bp.route('/<int:parking_id>', methods=['GET'])
@jwt_required()
def get_messages(parking_id):
    user_id = int(get_jwt_identity())

    parking = execute_one('SELECT id, naziv FROM parkings WHERE id=%s', (parking_id,))
    if not parking:
        return jsonify({'error': 'Parking nije pronađen'}), 404

    messages = execute_query(
        '''SELECT * FROM parking_chat_messages
           WHERE user_id = %s AND parking_id = %s
           ORDER BY created_at ASC''',
        (user_id, parking_id)
    )

    execute_query(
        '''UPDATE parking_chat_messages SET procitano = TRUE
           WHERE user_id = %s AND parking_id = %s AND sender = 'parking' ''',
        (user_id, parking_id), fetch=False, commit=True
    )

    return jsonify({'parking': parking, 'messages': messages}), 200


@chat_bp.route('/<int:parking_id>', methods=['POST'])
@jwt_required()
def send_message(parking_id):
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    poruka = (data.get('poruka') or '').strip()

    if not poruka:
        return jsonify({'error': 'Poruka ne smije biti prazna'}), 400

    parking = execute_one('SELECT id, naziv FROM parkings WHERE id=%s', (parking_id,))
    if not parking:
        return jsonify({'error': 'Parking nije pronađen'}), 404

    user = execute_one('SELECT ime, prezime FROM users WHERE id=%s', (user_id,))

    msg_id = execute_query(
        '''INSERT INTO parking_chat_messages (user_id, parking_id, sender, poruka)
           VALUES (%s, %s, 'user', %s)''',
        (user_id, parking_id, poruka), fetch=False, commit=True
    )
    sent = execute_one('SELECT * FROM parking_chat_messages WHERE id=%s', (msg_id,))

    
    notify_staff(parking_id, 'chat_message', {
        'user_id': user_id,
        'parking_id': parking_id,
        'parking_naziv': parking['naziv'],
        'user_ime': f"{(user or {}).get('ime', '')} {(user or {}).get('prezime', '')}".strip(),
        'poruka': poruka,
        'message': sent,
    })

    return jsonify({'message': sent}), 201
