import threading
from datetime import date, datetime

from flask_socketio import SocketIO, join_room, emit

socketio = SocketIO(cors_allowed_origins="*", async_mode="threading")


def _json_safe(value):
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def init_app(app):
    socketio.init_app(app, cors_allowed_origins="*", async_mode="threading")

    @socketio.on("connect", namespace="/ws/notifications")
    def _on_connect():
        
        
        pass

    @socketio.on("authenticate", namespace="/ws/notifications")
    def _on_authenticate(data):
        user_id = (data or {}).get("user_id")
        if not user_id:
            return
        join_room(f"user_{user_id}", namespace="/ws/notifications")

        
        role = (data or {}).get("role")
        if role == "admin":
            join_room("admin_room", namespace="/ws/notifications")
        elif role == "manager":
            parking_id = (data or {}).get("parking_id")
            if parking_id:
                join_room(f"manager_parking_{parking_id}", namespace="/ws/notifications")

        emit("authenticated", {"ok": True})

    @socketio.on("disconnect", namespace="/ws/notifications")
    def _on_disconnect():
        pass

    return socketio


def notify_user(user_id, ntype, title, body, data=None):
    if not user_id:
        return
    socketio.emit(
        "notification",
        _json_safe({
            "type": ntype,       
            "title": title,
            "body": body,
            "data": data or {},
        }),
        room=f"user_{user_id}",
        namespace="/ws/notifications",
    )


def notify_users(user_ids, ntype, title, body, data=None):
    for uid in set(uid for uid in (user_ids or []) if uid):
        notify_user(uid, ntype, title, body, data)


def notify_staff(parking_id, event, payload):
    payload = _json_safe(payload)
    socketio.emit(event, payload, room="admin_room", namespace="/ws/notifications")
    if parking_id:
        socketio.emit(
            event, payload,
            room=f"manager_parking_{parking_id}",
            namespace="/ws/notifications",
        )


def schedule_notification(user_id, delay_seconds, ntype, title, body, data=None):
    if delay_seconds is None or delay_seconds <= 0:
        return
    timer = threading.Timer(
        delay_seconds, notify_user, args=(user_id, ntype, title, body, data)
    )
    timer.daemon = True
    timer.start()
