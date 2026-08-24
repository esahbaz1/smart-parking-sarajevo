import os
import uuid
from datetime import datetime

from flask import Blueprint, request, jsonify, current_app, g
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.utils import secure_filename

from utils.auth_utils import staff_required

from models.db import execute_query, execute_one
from models.audit import log_action
from notifications import notify_staff, notify_user

reports_bp = Blueprint('reports', __name__)

ALLOWED_EXT = {'png', 'jpg', 'jpeg', 'webp', 'heic'}
UPLOAD_SUBDIR = 'reports'


def _allowed(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXT


def _upload_dir():
    base = os.path.join(current_app.root_path, 'uploads', UPLOAD_SUBDIR)
    os.makedirs(base, exist_ok=True)
    return base


@reports_bp.route('/', methods=['POST'])
@jwt_required()
def create_report():
    user_id = int(get_jwt_identity())

    parking_id = request.form.get('parking_id')
    opis = request.form.get('opis', '').strip()
    spot_number = (request.form.get('spot_number') or '').strip() or None

    if not parking_id:
        return jsonify({'error': 'parking_id je obavezan'}), 400

    parking = execute_one('SELECT id, naziv FROM parkings WHERE id=%s', (parking_id,))
    if not parking:
        return jsonify({'error': 'Parking nije pronađen'}), 404

    
    spot_id = None
    if spot_number:
        spot = execute_one(
            'SELECT id FROM parking_spots WHERE parking_id=%s AND spot_number=%s',
            (parking_id, spot_number)
        )
        if spot:
            spot_id = spot['id']

    photo_path = None
    file = request.files.get('photo')
    if file and file.filename:
        if not _allowed(file.filename):
            return jsonify({'error': 'Nepodržan format slike (dozvoljeno: jpg, png, webp, heic)'}), 400
        ext = file.filename.rsplit('.', 1)[1].lower()
        filename = secure_filename(f"{uuid.uuid4().hex}.{ext}")
        file.save(os.path.join(_upload_dir(), filename))
        photo_path = f"/uploads/{UPLOAD_SUBDIR}/{filename}"

    report_id = execute_query(
        '''INSERT INTO parking_reports (user_id, parking_id, spot_id, spot_number, opis, photo_path, status)
           VALUES (%s, %s, %s, %s, %s, %s, 'nova')''',
        (user_id, parking_id, spot_id, spot_number, opis, photo_path),
        fetch=False, commit=True
    )

    log_action('report_created', user_id=user_id, actor_email=None,
               details={'parking_id': parking_id, 'report_id': report_id, 'spot_number': spot_number})

    report = execute_one('SELECT * FROM parking_reports WHERE id=%s', (report_id,))
    user = execute_one('SELECT ime, prezime FROM users WHERE id=%s', (user_id,))

    
    notify_staff(parking_id, 'new_report', {
        'parking_id': int(parking_id),
        'parking_naziv': parking['naziv'],
        'report': report,
        'user_ime': f"{(user or {}).get('ime', '')} {(user or {}).get('prezime', '')}".strip(),
    })

    return jsonify({'message': 'Prijava uspješno poslana. Hvala!', 'report': report}), 201


@reports_bp.route('/my', methods=['GET'])
@jwt_required()
def my_reports():
    user_id = int(get_jwt_identity())
    reports = execute_query(
        '''SELECT r.*, p.naziv AS parking_naziv
           FROM parking_reports r
           JOIN parkings p ON r.parking_id = p.id
           WHERE r.user_id = %s
           ORDER BY r.created_at DESC''',
        (user_id,)
    )
    return jsonify(reports), 200


@reports_bp.route('/parking/<int:parking_id>', methods=['GET'])
@jwt_required()
def reports_for_parking(parking_id):
    reports = execute_query(
        '''SELECT r.*, u.ime, u.prezime
           FROM parking_reports r
           JOIN users u ON r.user_id = u.id
           WHERE r.parking_id = %s
           ORDER BY r.created_at DESC''',
        (parking_id,)
    )
    return jsonify(reports), 200


@reports_bp.route('/<int:report_id>', methods=['PUT'])
@staff_required
def update_report(report_id):
    data = request.get_json() or {}
    report = execute_one('SELECT * FROM parking_reports WHERE id=%s', (report_id,))
    if not report:
        return jsonify({'error': 'Prijava nije pronađena'}), 404

    if g.manager_parking_id and report['parking_id'] != g.manager_parking_id:
        return jsonify({'error': 'Ova prijava ne pripada tvom parkingu'}), 403

    fields, params = [], []
    if 'status' in data and data['status'] in ('nova', 'u_obradi', 'rijesena'):
        fields.append('status=%s'); params.append(data['status'])
        if data['status'] == 'rijesena':
            fields.append('resolved_at=NOW()')
    if 'manager_response' in data:
        fields.append('manager_response=%s'); params.append(data['manager_response'])

    if not fields:
        return jsonify({'error': 'Nema polja za ažuriranje'}), 400

    params.append(report_id)
    execute_query(f'UPDATE parking_reports SET {", ".join(fields)} WHERE id=%s',
                  tuple(params), fetch=False, commit=True)

    updated = execute_one('SELECT * FROM parking_reports WHERE id=%s', (report_id,))

    log_action('report_updated', user_id=g.manager_user_id, actor_email=g.manager_email,
               details={'report_id': report_id, 'changes': data})

    
    if updated:
        parking = execute_one('SELECT naziv FROM parkings WHERE id=%s', (updated['parking_id'],))
        status_labels = {'nova': 'primljena', 'u_obradi': 'u obradi', 'rijesena': 'riješena'}
        notify_user(
            updated['user_id'], 'report',
            f"Prijava ažurirana — {(parking or {}).get('naziv', 'parking')} 🛠️",
            f"Status tvoje prijave je sad: {status_labels.get(updated['status'], updated['status'])}."
            + (f" Poruka: {updated['manager_response']}" if updated.get('manager_response') else ''),
            {'report_id': report_id, 'parking_id': updated['parking_id']},
        )

    return jsonify({'message': 'Prijava ažurirana', 'report': updated}), 200
