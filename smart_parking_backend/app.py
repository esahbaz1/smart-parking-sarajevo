
import os
from datetime import timedelta
from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from dotenv import load_dotenv

from routes.auth import auth_bp
from routes.parkings import parkings_bp
from routes.reservations import reservations_bp
from routes.admin import admin_bp
from routes.manager import manager_bp
from routes.routing import routing_bp
from routes.reports import reports_bp
from routes.chat import chat_bp
from routes.favorites import favorites_bp
from notifications import init_app as init_notifications_socketio

load_dotenv()

app = Flask(__name__)


app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'dev-secret-change-in-production')


app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(
    minutes=int(os.getenv('ACCESS_TOKEN_MINUTES', 60))
)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = timedelta(
    days=int(os.getenv('REFRESH_TOKEN_DAYS', 30))
)

UPLOAD_FOLDER = os.path.join(app.root_path, 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 8 * 1024 * 1024  


CORS(app, origins='*')  
jwt = JWTManager(app)


socketio = init_notifications_socketio(app)


app.register_blueprint(auth_bp,         url_prefix='/api/auth')
app.register_blueprint(parkings_bp,     url_prefix='/api/parkings')
app.register_blueprint(reservations_bp, url_prefix='/api/reservations')
app.register_blueprint(admin_bp,        url_prefix='/api/admin')
app.register_blueprint(manager_bp,      url_prefix='/api/manager')
app.register_blueprint(routing_bp,      url_prefix='/api/route')
app.register_blueprint(reports_bp,      url_prefix='/api/reports')
app.register_blueprint(chat_bp,         url_prefix='/api/chat')
app.register_blueprint(favorites_bp,    url_prefix='/api/favorites')


@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


@app.route('/')
def health():
    return jsonify({
        'status': 'ok',
        'app': 'Smart Parking Sarajevo API',
        'version': '1.0.0',
        'endpoints': {
            'auth':         '/api/auth/register | /api/auth/login | /api/auth/me',
            'parkings':     '/api/parkings/ | /api/parkings/<id> | /api/parkings/sensor',
            'reservations': '/api/reservations/ | /api/reservations/my',
            'admin':        '/api/admin/dashboard | /api/admin/users | /api/admin/audit-log | /api/admin/parkings | /api/admin/managers | /api/admin/reports',
            'manager':      '/api/manager/dashboard | /api/manager/spots | /api/manager/reports | /api/manager/chat/threads',
            'routing':      '/api/route/?from_lat=&from_lng=&to_lat=&to_lng=',
            'reports':      '/api/reports/ | /api/reports/my | /api/reports/parking/<id>',
            'chat':         '/api/chat/<parking_id>',
            'favorites':    '/api/favorites/ | /api/favorites/<parking_id>',
        }
    })


@jwt.unauthorized_loader
def missing_token(reason):
    return jsonify({'error': 'Token nedostaje', 'reason': reason}), 401

@jwt.invalid_token_loader
def invalid_token(reason):
    return jsonify({'error': 'Nevažeći token', 'reason': reason}), 422

@jwt.expired_token_loader
def expired_token(header, payload):
    return jsonify({'error': 'Token je istekao'}), 401


@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Endpoint nije pronađen'}), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({'error': 'Greška servera', 'detail': str(e)}), 500


if __name__ == '__main__':
    port = int(os.getenv('FLASK_PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'True') == 'True'
    print(f"\n🚀 Smart Parking API pokrenut na http://localhost:{port}")
    print(f"📋 Swagger docs: http://localhost:{port}/")
    print(f"🔔 Notifikacije (WebSocket) na ws://localhost:{port}/ws/notifications\n")
    
    
    socketio.run(app, host='0.0.0.0', port=port, debug=debug, allow_unsafe_werkzeug=True)
