import os
import random
from datetime import datetime, timedelta

from flask import Blueprint, request, jsonify
from flask_jwt_extended import (
    create_access_token, create_refresh_token,
    jwt_required, get_jwt_identity
)
import bcrypt
from models.db import execute_query, execute_one
from models.audit import log_action
from utils.mailer import send_verification_email

auth_bp = Blueprint('auth', __name__)


MAX_FAILED_ATTEMPTS = 5           
LOCKOUT_MINUTES = 15              
VERIFICATION_CODE_TTL_MIN = 15    


def _generate_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def _issue_tokens(user_id):
    identity = str(user_id)
    return {
        'access_token': create_access_token(identity=identity),
        'refresh_token': create_refresh_token(identity=identity),
    }


def _user_public_bundle(user_id):
    user = execute_one(
        '''SELECT u.id, u.ime, u.prezime, u.email, u.telefon, u.premium, u.role,
                  u.email_verified, u.created_at, u.parking_id, p.naziv AS parking_naziv
           FROM users u LEFT JOIN parkings p ON p.id = u.parking_id
           WHERE u.id = %s''',
        (user_id,)
    )
    vehicles = execute_query('SELECT * FROM vehicles WHERE user_id = %s', (user_id,))
    stats = execute_one(
        '''SELECT
            COUNT(*) AS total_parkings,
            COALESCE(SUM(trajanje_min), 0) AS total_minutes,
            ROUND(COALESCE(SUM(trajanje_min), 0) * 0.04, 2) AS co2_saved_kg
           FROM parking_history WHERE user_id = %s''',
        (user_id,)
    )
    return user, vehicles, stats


@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()

    required = ['ime', 'prezime', 'email', 'lozinka']
    for field in required:
        if not data.get(field):
            return jsonify({'error': f'Polje "{field}" je obavezno'}), 400

    existing = execute_one(
        'SELECT id, email_verified FROM users WHERE email = %s', (data['email'],)
    )

    hashed = bcrypt.hashpw(
        data['lozinka'].encode('utf-8'),
        bcrypt.gensalt()
    ).decode('utf-8')

    code = _generate_code()
    expires = datetime.utcnow() + timedelta(minutes=VERIFICATION_CODE_TTL_MIN)

    if existing:
        if existing.get('email_verified'):
            
            return jsonify({'error': 'Korisnik s ovim emailom već postoji'}), 409

        
        user_id = existing['id']
        execute_query(
            '''UPDATE users SET ime=%s, prezime=%s, lozinka=%s, telefon=%s,
               verification_code=%s, verification_expires=%s
               WHERE id=%s''',
            (data['ime'], data['prezime'], hashed, data.get('telefon'),
             code, expires, user_id),
            fetch=False, commit=True
        )
    else:
        user_id = execute_query(
            '''INSERT INTO users (ime, prezime, email, lozinka, telefon,
                                   email_verified, verification_code, verification_expires)
               VALUES (%s, %s, %s, %s, %s, FALSE, %s, %s)''',
            (data['ime'], data['prezime'], data['email'], hashed, data.get('telefon'), code, expires),
            fetch=False, commit=True
        )

    vehicle_data = data.get('vozilo')
    if vehicle_data and vehicle_data.get('tablice'):
        try:
            execute_query(
                '''INSERT INTO vehicles (user_id, tablice, vrsta, marka, model, boja)
                   VALUES (%s, %s, %s, %s, %s, %s)''',
                (
                    user_id,
                    vehicle_data['tablice'].upper(),
                    vehicle_data.get('vrsta', 'automobil'),
                    vehicle_data.get('marka'),
                    vehicle_data.get('model'),
                    vehicle_data.get('boja'),
                ),
                fetch=False, commit=True
            )
        except Exception:
            pass  

    send_verification_email(data['email'], data['ime'], code)
    log_action('register', user_id=user_id, actor_email=data['email'])

    user, vehicles, stats = _user_public_bundle(user_id)

    return jsonify({
        'message': 'Registracija uspješna! Provjeri email za verifikacioni kod.',
        'requires_verification': True,
        'email': data['email'],
        'user': user,
        'vehicles': vehicles,
        'stats': stats
    }), 201


@auth_bp.route('/verify-email', methods=['POST'])
def verify_email():
    data = request.get_json() or {}
    email = data.get('email')
    code = data.get('code')

    if not email or not code:
        return jsonify({'error': 'Email i kod su obavezni'}), 400

    user = execute_one('SELECT * FROM users WHERE email = %s', (email,))
    if not user:
        return jsonify({'error': 'Korisnik nije pronađen'}), 404

    if user.get('email_verified'):
        tokens = _issue_tokens(user['id'])
        u, vehicles, stats = _user_public_bundle(user['id'])
        return jsonify({'message': 'Email je već verifikovan', **tokens,
                         'user': u, 'vehicles': vehicles, 'stats': stats}), 200

    if not user.get('verification_code') or user['verification_code'] != str(code):
        return jsonify({'error': 'Pogrešan verifikacioni kod'}), 400

    if user.get('verification_expires') and user['verification_expires'] < datetime.utcnow():
        return jsonify({'error': 'Kod je istekao. Zatraži novi kod.'}), 400

    execute_query(
        '''UPDATE users SET email_verified = TRUE, verification_code = NULL,
           verification_expires = NULL WHERE id = %s''',
        (user['id'],), fetch=False, commit=True
    )
    log_action('email_verified', user_id=user['id'], actor_email=email)

    tokens = _issue_tokens(user['id'])
    u, vehicles, stats = _user_public_bundle(user['id'])
    return jsonify({
        'message': 'Email uspješno verifikovan!',
        **tokens,
        'user': u, 'vehicles': vehicles, 'stats': stats
    }), 200


@auth_bp.route('/resend-verification', methods=['POST'])
def resend_verification():
    data = request.get_json() or {}
    email = data.get('email')
    if not email:
        return jsonify({'error': 'Email je obavezan'}), 400

    user = execute_one('SELECT * FROM users WHERE email = %s', (email,))
    if not user:
        return jsonify({'error': 'Korisnik nije pronađen'}), 404
    if user.get('email_verified'):
        return jsonify({'message': 'Email je već verifikovan'}), 200

    code = _generate_code()
    expires = datetime.utcnow() + timedelta(minutes=VERIFICATION_CODE_TTL_MIN)
    execute_query(
        'UPDATE users SET verification_code=%s, verification_expires=%s WHERE id=%s',
        (code, expires, user['id']), fetch=False, commit=True
    )
    send_verification_email(email, user['ime'], code)
    return jsonify({'message': 'Novi kod je poslan na email'}), 200


@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()

    if not data.get('email') or not data.get('lozinka'):
        return jsonify({'error': 'Email i lozinka su obavezni'}), 400

    user = execute_one('SELECT * FROM users WHERE email = %s', (data['email'],))

    if not user:
        log_action('login_failed', actor_email=data['email'])
        return jsonify({'error': 'Pogrešan email ili lozinka'}), 401

    
    if user.get('locked_until') and user['locked_until'] > datetime.utcnow():
        preostalo = int((user['locked_until'] - datetime.utcnow()).total_seconds() // 60) + 1
        log_action('login_locked', user_id=user['id'], actor_email=user['email'])
        return jsonify({
            'error': f'Previše pogrešnih pokušaja. Nalog je privremeno zaključan '
                     f'još ~{preostalo} min.'
        }), 423

    if not bcrypt.checkpw(data['lozinka'].encode('utf-8'), user['lozinka'].encode('utf-8')):
        attempts = (user.get('failed_attempts') or 0) + 1
        if attempts >= MAX_FAILED_ATTEMPTS:
            locked_until = datetime.utcnow() + timedelta(minutes=LOCKOUT_MINUTES)
            execute_query(
                'UPDATE users SET failed_attempts=%s, locked_until=%s WHERE id=%s',
                (attempts, locked_until, user['id']), fetch=False, commit=True
            )
            log_action('login_locked', user_id=user['id'], actor_email=user['email'])
            return jsonify({
                'error': f'Previše pogrešnih pokušaja. Nalog je zaključan na {LOCKOUT_MINUTES} minuta.'
            }), 423
        execute_query(
            'UPDATE users SET failed_attempts=%s WHERE id=%s',
            (attempts, user['id']), fetch=False, commit=True
        )
        log_action('login_failed', user_id=user['id'], actor_email=data['email'])
        return jsonify({
            'error': 'Pogrešan email ili lozinka',
            'attempts_left': max(0, MAX_FAILED_ATTEMPTS - attempts)
        }), 401

    if user.get('status') == 'blocked':
        log_action('login_blocked', user_id=user['id'], actor_email=user['email'])
        return jsonify({'error': 'Nalog je blokiran. Kontaktirajte podršku.'}), 403

    if not user.get('email_verified'):
        return jsonify({
            'error': 'Email nije verifikovan. Provjeri email i unesi kod.',
            'requires_verification': True,
            'email': user['email'],
        }), 403

    
    execute_query(
        'UPDATE users SET failed_attempts=0, locked_until=NULL WHERE id=%s',
        (user['id'],), fetch=False, commit=True
    )

    tokens = _issue_tokens(user['id'])
    log_action('login', user_id=user['id'], actor_email=user['email'])

    u, vehicles, stats = _user_public_bundle(user['id'])

    return jsonify({
        **tokens,
        'user': u,
        'vehicles': vehicles,
        'stats': stats
    }), 200


@auth_bp.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    user_id = get_jwt_identity()
    new_access = create_access_token(identity=str(user_id))
    return jsonify({'access_token': new_access}), 200


@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def me():
    user_id = int(get_jwt_identity())

    user = execute_one(
        '''SELECT u.id, u.ime, u.prezime, u.email, u.telefon, u.premium, u.role, u.status,
                  u.email_verified, u.created_at, u.parking_id, p.naziv AS parking_naziv
           FROM users u LEFT JOIN parkings p ON p.id = u.parking_id
           WHERE u.id = %s''',
        (user_id,)
    )
    if not user:
        return jsonify({'error': 'Korisnik nije pronađen'}), 404

    vehicles = execute_query(
        'SELECT * FROM vehicles WHERE user_id = %s', (user_id,)
    )

    stats = execute_one(
        '''SELECT
            COUNT(*) AS total_parkings,
            COALESCE(SUM(trajanje_min), 0) AS total_minutes,
            COALESCE(SUM(cijena), 0) AS total_spent,
            ROUND(COALESCE(SUM(trajanje_min), 0) * 0.04, 2) AS co2_saved_kg
           FROM parking_history WHERE user_id = %s''',
        (user_id,)
    )

    history = execute_query(
        '''SELECT ph.*, p.naziv AS parking_naziv
           FROM parking_history ph
           JOIN parkings p ON ph.parking_id = p.id
           WHERE ph.user_id = %s
           ORDER BY ph.ulaz_vrijeme DESC
           LIMIT 10''',
        (user_id,)
    )

    return jsonify({
        'user': user,
        'vehicles': vehicles,
        'stats': stats,
        'history': history
    }), 200


@auth_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    user_id = int(get_jwt_identity())
    data = request.get_json()

    execute_query(
        '''UPDATE users SET ime=%s, prezime=%s, telefon=%s
           WHERE id=%s''',
        (data.get('ime'), data.get('prezime'), data.get('telefon'), user_id),
        fetch=False, commit=True
    )

    return jsonify({'message': 'Profil ažuriran'}), 200


@auth_bp.route('/vehicle', methods=['POST'])
@jwt_required()
def add_vehicle():
    user_id = int(get_jwt_identity())
    data = request.get_json()

    if not data.get('tablice'):
        return jsonify({'error': 'Tablice su obavezne'}), 400

    try:
        vid = execute_query(
            '''INSERT INTO vehicles (user_id, tablice, vrsta, marka, model, boja)
               VALUES (%s, %s, %s, %s, %s, %s)''',
            (
                user_id,
                data['tablice'].upper(),
                data.get('vrsta', 'automobil'),
                data.get('marka'),
                data.get('model'),
                data.get('boja'),
            ),
            fetch=False, commit=True
        )
        return jsonify({'message': 'Vozilo dodano', 'vehicle_id': vid}), 201
    except Exception as e:
        if 'Duplicate' in str(e):
            return jsonify({'error': 'Vozilo s ovim tablicama već postoji'}), 409
        return jsonify({'error': str(e)}), 500


@auth_bp.route('/google', methods=['POST'])
def google_login():
    data = request.get_json() or {}
    id_token_str = data.get('id_token')

    if not id_token_str:
        return jsonify({'error': 'id_token je obavezan'}), 400

    client_id = os.getenv('GOOGLE_CLIENT_ID')
    if not client_id:
        return jsonify({
            'error': 'Google prijava nije podešena na serveru. '
                     'Postavi GOOGLE_CLIENT_ID u .env (vidi POKRETANJE.md).'
        }), 501

    try:
        
        from google.oauth2 import id_token as google_id_token
        from google.auth.transport import requests as google_requests

        payload = google_id_token.verify_oauth2_token(
            id_token_str, google_requests.Request(), client_id
        )
    except Exception as e:
        return jsonify({'error': f'Nevažeći Google token: {e}'}), 401

    email = payload.get('email')
    if not email:
        return jsonify({'error': 'Google nalog nema email'}), 400

    ime = payload.get('given_name') or payload.get('name') or 'Korisnik'
    prezime = payload.get('family_name') or ''

    user = execute_one('SELECT * FROM users WHERE email = %s', (email,))

    if not user:
        
        random_password = bcrypt.hashpw(
            os.urandom(24), bcrypt.gensalt()
        ).decode('utf-8')
        user_id = execute_query(
            '''INSERT INTO users (ime, prezime, email, lozinka, email_verified)
               VALUES (%s, %s, %s, %s, TRUE)''',
            (ime, prezime, email, random_password),
            fetch=False, commit=True
        )
        log_action('register_google', user_id=user_id, actor_email=email)
    else:
        user_id = user['id']
        if not user.get('email_verified'):
            execute_query(
                'UPDATE users SET email_verified=TRUE WHERE id=%s',
                (user_id,), fetch=False, commit=True
            )
        if user.get('status') == 'blocked':
            return jsonify({'error': 'Nalog je blokiran. Kontaktirajte podršku.'}), 403

    tokens = _issue_tokens(user_id)
    log_action('login_google', user_id=user_id, actor_email=email)

    u, vehicles, stats = _user_public_bundle(user_id)
    return jsonify({**tokens, 'user': u, 'vehicles': vehicles, 'stats': stats}), 200


@auth_bp.route('/upgrade', methods=['POST'])
@jwt_required()
def upgrade_to_premium():
    user_id = int(get_jwt_identity())
    execute_query(
        'UPDATE users SET premium=TRUE WHERE id=%s',
        (user_id,), fetch=False, commit=True
    )
    log_action('premium_upgrade', user_id=user_id)
    return jsonify({'message': 'Premium aktiviran! Hvala ti.'}), 200


@auth_bp.route('/change-password', methods=['POST'])
@jwt_required()
def change_password():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}

    trenutna = data.get('trenutna_lozinka')
    nova = data.get('nova_lozinka')

    if not trenutna or not nova:
        return jsonify({'error': 'Trenutna i nova lozinka su obavezne'}), 400
    if len(nova) < 6:
        return jsonify({'error': 'Nova lozinka mora imati najmanje 6 karaktera'}), 400

    user = execute_one('SELECT lozinka FROM users WHERE id=%s', (user_id,))
    if not user or not bcrypt.checkpw(trenutna.encode('utf-8'), user['lozinka'].encode('utf-8')):
        return jsonify({'error': 'Trenutna lozinka nije ispravna'}), 401

    new_hash = bcrypt.hashpw(nova.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    execute_query(
        'UPDATE users SET lozinka=%s WHERE id=%s',
        (new_hash, user_id), fetch=False, commit=True
    )
    log_action('password_change', user_id=user_id)
    return jsonify({'message': 'Lozinka je uspješno promijenjena'}), 200
