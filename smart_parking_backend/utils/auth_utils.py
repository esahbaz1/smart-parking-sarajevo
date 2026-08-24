from functools import wraps
from flask import jsonify, g
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
from models.db import execute_one


def admin_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
        user_id = int(get_jwt_identity())
        user = execute_one('SELECT role, status FROM users WHERE id=%s', (user_id,))
        if not user or user['role'] != 'admin':
            return jsonify({'error': 'Nemate administratorska prava'}), 403
        if user.get('status') == 'blocked':
            return jsonify({'error': 'Nalog je blokiran'}), 403
        return fn(*args, **kwargs)
    return wrapper


def manager_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
        user_id = int(get_jwt_identity())
        user = execute_one(
            'SELECT id, role, status, parking_id, email FROM users WHERE id=%s',
            (user_id,)
        )
        if not user or user['role'] != 'manager':
            return jsonify({'error': 'Nemate upravnička prava'}), 403
        if user.get('status') == 'blocked':
            return jsonify({'error': 'Nalog je blokiran'}), 403
        if not user.get('parking_id'):
            return jsonify({'error': 'Nalog nije dodijeljen nijednom parkingu. Kontaktiraj administratora.'}), 403
        g.manager_user_id = user['id']
        g.manager_parking_id = user['parking_id']
        g.manager_email = user['email']
        return fn(*args, **kwargs)
    return wrapper


def staff_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
        user_id = int(get_jwt_identity())
        user = execute_one(
            'SELECT id, role, status, parking_id, email FROM users WHERE id=%s',
            (user_id,)
        )
        if not user or user['role'] not in ('admin', 'manager'):
            return jsonify({'error': 'Nemate administratorska/upravnička prava'}), 403
        if user.get('status') == 'blocked':
            return jsonify({'error': 'Nalog je blokiran'}), 403
        if user['role'] == 'manager' and not user.get('parking_id'):
            return jsonify({'error': 'Nalog nije dodijeljen nijednom parkingu. Kontaktiraj administratora.'}), 403
        g.staff_role = user['role']
        g.manager_user_id = user['id']
        g.manager_parking_id = user['parking_id'] if user['role'] == 'manager' else None
        g.manager_email = user['email']
        return fn(*args, **kwargs)
    return wrapper
