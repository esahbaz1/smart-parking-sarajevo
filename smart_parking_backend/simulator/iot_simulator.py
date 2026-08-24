import threading
import random
import time
import math
import os
import queue
from datetime import datetime, timedelta
from models.db import execute_query, execute_one
from flask import Flask
from flask_socketio import SocketIO


WS_PORT  = 5001   
API_PORT = 5000   


API_HOST = os.getenv('BACKEND_API_HOST', 'localhost')

NETWORK_LATENCY    = (0.05, 0.25)
HEARTBEAT_INTERVAL = 60
EVENT_QUEUE        = queue.Queue()
active_tablice     = set()


app      = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")


def load_parkings():
    rows = execute_query(
        "SELECT id, naziv, total_spots, lambda, mu, radno_vrijeme, available_spots FROM parking_status"
    )
    parkings = []
    for r in rows:
        parkings.append({
            "id":             r["id"],
            "naziv":          r["naziv"],
            "total":          r["total_spots"],
            "lambda_base":    float(r["lambda"]),
            "mu":             float(r["mu"]),
            "radno_vrijeme":  r["radno_vrijeme"],
            "available_spots": r.get("available_spots", 0),
        })
    return parkings


def is_open(radno_vrijeme):
    if radno_vrijeme == "00:00 - 24:00":
        return True
    start_str, end_str = radno_vrijeme.split(" - ")
    now   = datetime.now().time()
    start = datetime.strptime(start_str, "%H:%M").time()
    end   = datetime.strptime(end_str,   "%H:%M").time()
    return start <= now <= end


def poisson(lmbda):
    L = math.exp(-lmbda)
    k, p = 0, 1
    while p > L:
        k += 1
        p *= random.random()
    return max(0, k - 1)


def generate_tablice():
    while True:
        t = (
            f"{random.choice(['A','E','K','T'])}"
            f"{random.randint(10,99)}-"
            f"{random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}-"
            f"{random.randint(100,999)}"
        )
        if t not in active_tablice:
            active_tablice.add(t)
            return t


def emit_event(payload):
    EVENT_QUEUE.put(payload)

    if payload.get("event") in ("entry", "exit"):
        parking_id = payload["parking_id"]

        
        updated = execute_one(
            "SELECT available_spots, total_spots FROM parkings WHERE id=%s",
            (parking_id,)
        )
        if not updated:
            return

        
        socketio.emit(
            "parking_update",
            {
                "parking_id":      parking_id,
                "available_spots": updated["available_spots"],
                "total_spots":     updated["total_spots"],
            },
            namespace="/ws/parking",
        )


import requests

def gateway_worker():
    
    API_BASE = f"http://{API_HOST}:{API_PORT}/api"
    while True:
        payload = EVENT_QUEUE.get()
        time.sleep(random.uniform(*NETWORK_LATENCY))
        try:
            r = requests.post(
                f"{API_BASE}/parkings/sensor",
                json=payload,
                timeout=3,
            )
            if r.status_code != 200:
                print(f"[Gateway] Greška: {r.status_code} {r.text[:100]}")
        except Exception as e:
            print(f"[Gateway] Exception: {e}")
        EVENT_QUEUE.task_done()


class ParkingSensor:
    def __init__(self, parking_id, spot_number):
        self.parking_id        = parking_id
        self.spot_number       = spot_number
        self.sensor_id         = f"SAR-{parking_id}-{spot_number}"
        self.occupied          = False
        self.battery           = random.uniform(75, 100)
        self.online            = True
        self.last_heartbeat    = datetime.now()
        self.vehicle_exit_time = None

    def tick(self):
        if not self.online:
            return

        
        if (datetime.now() - self.last_heartbeat).seconds >= HEARTBEAT_INTERVAL:
            emit_event({
                "sensor_id":  self.sensor_id,
                "parking_id": self.parking_id,
                "event":      "heartbeat",
                "battery":    round(self.battery, 2),
                "timestamp":  datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            })
            self.last_heartbeat = datetime.now()

        
        if not self.occupied and random.random() < 0.02:
            self.occupied          = True
            duration               = max(15, random.gauss(90, 25))
            self.vehicle_exit_time = datetime.now() + timedelta(minutes=duration)
            self.send_event("entry")

        
        if self.occupied and self.vehicle_exit_time and datetime.now() >= self.vehicle_exit_time:
            self.occupied          = False
            self.vehicle_exit_time = None
            self.send_event("exit")

        
        self.battery -= random.uniform(0.001, 0.01)
        if self.battery <= 5:
            self.online = False

    def send_event(self, event_type):
        payload = {
            "sensor_id":       self.sensor_id,
            "parking_id":      self.parking_id,
            "spot_number":     self.spot_number,
            "event":           event_type,
            "battery":         round(self.battery, 2),
            "rssi":            random.randint(-90, -40),
            "firmware":        "1.3.2",
            "vehicle_tablice": generate_tablice() if event_type == "entry" else None,
            "timestamp":       datetime.now().strftime("%Y-%m-%d %H:%M:%S"),  
        }
        emit_event(payload)


def simulate_parking(parking):
    sensors = [ParkingSensor(parking["id"], i + 1) for i in range(parking["total"])]
    print(f"Parking {parking['naziv']} → {len(sensors)} senzora aktivno")

    
    occupied_count = parking["total"] - parking.get("available_spots", 0)
    for i in range(min(occupied_count, len(sensors))):
        sensors[i].occupied          = True
        sensors[i].vehicle_exit_time = datetime.now() + timedelta(minutes=random.randint(15, 120))

    while True:
        if not is_open(parking["radno_vrijeme"]):
            time.sleep(30)
            continue
        for sensor in sensors:
            sensor.tick()
        time.sleep(2)


@socketio.on("connect", namespace="/ws/parking")
def ws_connect():
    print(f"[WS] Klijent povezan  {datetime.now().strftime('%H:%M:%S')}")

@socketio.on("disconnect", namespace="/ws/parking")
def ws_disconnect():
    print(f"[WS] Klijent odspojen {datetime.now().strftime('%H:%M:%S')}")


def main():
    parkings = load_parkings()
    print("=" * 60)
    print("SMART PARKING SARAJEVO - IoT Simulator")
    print(f"WebSocket server → port {WS_PORT}")
    print(f"Backend API      → port {API_PORT}")
    print("=" * 60)

    
    threading.Thread(target=gateway_worker, daemon=True).start()

    
    for parking in parkings:
        threading.Thread(target=simulate_parking, args=(parking,), daemon=True).start()
        time.sleep(0.3)

    print("\nSvi senzori aktivni. Ctrl+C za stop.\n")
    
    socketio.run(app, host="0.0.0.0", port=WS_PORT, debug=False, allow_unsafe_werkzeug=True)


if __name__ == "__main__":
    main()
