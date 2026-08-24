from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from models.db import execute_query, execute_one

favorites_bp = Blueprint('favorites', __name__)


@favorites_bp.route('/', methods=['GET'])
@jwt_required()
def list_favorites():
    user_id = int(get_jwt_identity())
    rows = execute_query(
        '''SELECT p.* FROM favorites f
           JOIN parkings p ON f.parking_id = p.id
           WHERE f.user_id = %s
           ORDER BY f.created_at DESC''',
        (user_id,)
    )
    return jsonify(rows), 200


@favorites_bp.route('/<int:parking_id>', methods=['POST'])
@jwt_required()
def toggle_favorite(parking_id):
    user_id = int(get_jwt_identity())

    parking = execute_one('SELECT id FROM parkings WHERE id=%s', (parking_id,))
    if not parking:
        return jsonify({'error': 'Parking nije pronađen'}), 404

    existing = execute_one(
        'SELECT id FROM favorites WHERE user_id=%s AND parking_id=%s',
        (user_id, parking_id)
    )

    if existing:
        execute_query(
            'DELETE FROM favorites WHERE id=%s', (existing['id'],),
            fetch=False, commit=True
        )
        return jsonify({'favorited': False}), 200

    execute_query(
        'INSERT INTO favorites (user_id, parking_id) VALUES (%s, %s)',
        (user_id, parking_id), fetch=False, commit=True
    )
    return jsonify({'favorited': True}), 201
