import json
from flask import request
from models.db import execute_query


def log_action(action, user_id=None, actor_email=None, details=None):
    try:
        ip = request.headers.get('X-Forwarded-For', request.remote_addr) if request else None
        execute_query(
            '''INSERT INTO audit_log (user_id, actor_email, action, details, ip_address)
               VALUES (%s, %s, %s, %s, %s)''',
            (user_id, actor_email, action,
             json.dumps(details, default=str) if details is not None else None,
             ip),
            fetch=False, commit=True
        )
    except Exception as e:
        print(f'[audit_log] greška pri logovanju: {e}')
