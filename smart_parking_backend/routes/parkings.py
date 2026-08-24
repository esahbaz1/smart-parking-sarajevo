from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from models.db import execute_query, execute_one
from notifications import notify_users
import math
import json

parkings_bp = Blueprint('parkings', __name__)


@parkings_bp.route('/', methods=['GET'])
def get_parkings():
    parkings = execute_query('SELECT * FROM parking_status WHERE aktivno = 1')

    for p in parkings:
        hourly = execute_query(
            '''SELECT
                HOUR(created_at) AS sat,
                COUNT(CASE WHEN event_type = 'entry' THEN 1 END) AS ulasci,
                COUNT(CASE WHEN event_type = 'exit'  THEN 1 END) AS izlasci
               FROM sensor_logs
               WHERE parking_id = %s
                 AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
               GROUP BY HOUR(created_at)
               ORDER BY sat''',
            (p['id'],)
        )
        hourly_map = {row['sat']: row for row in hourly}
        p['hourly_data'] = [
            hourly_map.get(h, {'sat': h, 'ulasci': 0, 'izlasci': 0})
            for h in range(24)
        ]
        p['erlang_blocking'] = round(_erlang_b(
            float(p['lambda']),
            float(p['mu']),
            int(p['total_spots'])
        ), 4)

    return jsonify(parkings), 200


@parkings_bp.route('/<int:parking_id>', methods=['GET'])
def get_parking(parking_id):
    parking = execute_one(
        'SELECT * FROM parking_status WHERE id = %s', (parking_id,)
    )
    if not parking:
        return jsonify({'error': 'Parking nije pronađen'}), 404

    free_spots = execute_query(
        '''SELECT spot_number, sensor_id
           FROM parking_spots
           WHERE parking_id = %s AND zaueto = FALSE
           LIMIT 20''',
        (parking_id,)
    )

    occupied_spots = execute_query(
        '''SELECT spot_number, vehicle_tablice, zauzeto_od
           FROM parking_spots
           WHERE parking_id = %s AND zaueto = TRUE''',
        (parking_id,)
    )

    parking['free_spots_sample']  = free_spots
    parking['occupied_spots']     = occupied_spots
    parking['prediction_30min']   = _predict_spots(parking, 30)
    parking['prediction_60min']   = _predict_spots(parking, 60)
    parking['erlang_blocking']    = round(_erlang_b(
        float(parking['lambda']),
        float(parking['mu']),
        int(parking['total_spots'])
    ), 4)

    return jsonify(parking), 200


@parkings_bp.route('/<int:parking_id>/spots', methods=['GET'])
def get_spots(parking_id):
    spots = execute_query(
        '''SELECT id, spot_number, zaueto, vehicle_tablice, zauzeto_od
           FROM parking_spots
           WHERE parking_id = %s
           ORDER BY spot_number''',
        (parking_id,)
    )
    return jsonify(spots), 200


@parkings_bp.route('/sensor', methods=['POST'])
def sensor_update():
    data = request.get_json()

    parking_id  = data.get('parking_id')
    spot_number = data.get('spot_number')
    event       = data.get('event')
    tablice     = data.get('vehicle_tablice')

    if not all([parking_id, event]):
        return jsonify({'error': 'parking_id i event su obavezni'}), 400

    
    spot_id = int(spot_number) if spot_number is not None else None

    if event == 'entry':
        
        
        if spot_id is not None:
            try:
                execute_query(
                    '''UPDATE parking_spots
                       SET zaueto=TRUE, vehicle_tablice=%s, zauzeto_od=NOW()
                       WHERE parking_id=%s AND spot_number=%s''',
                    (tablice, parking_id, spot_id),
                    fetch=False, commit=True
                )
            except Exception:
                pass

        execute_query(
            '''UPDATE parkings
               SET available_spots = GREATEST(0, available_spots - 1)
               WHERE id = %s''',
            (parking_id,), fetch=False, commit=True
        )

    elif event == 'exit':
        
        
        pre_state = execute_one(
            'SELECT available_spots, naziv FROM parkings WHERE id=%s', (parking_id,)
        )

        if spot_id is not None:
            try:
                execute_query(
                    '''UPDATE parking_spots
                       SET zaueto=FALSE, vehicle_tablice=NULL, zauzeto_od=NULL
                       WHERE parking_id=%s AND spot_number=%s''',
                    (parking_id, spot_id),
                    fetch=False, commit=True
                )
            except Exception:
                pass

        execute_query(
            '''UPDATE parkings
               SET available_spots = LEAST(total_spots, available_spots + 1)
               WHERE id = %s''',
            (parking_id,), fetch=False, commit=True
        )

        if pre_state and pre_state['available_spots'] == 0:
            fav_users = execute_query(
                'SELECT user_id FROM favorites WHERE parking_id=%s', (parking_id,)
            )
            notify_users(
                [f['user_id'] for f in fav_users],
                'freeSpot',
                'Oslobodilo se mjesto! 🅿️',
                f"Parking {pre_state['naziv']} ponovo ima slobodnih mjesta.",
                {'parking_id': parking_id},
            )

    
    execute_query(
        '''INSERT INTO sensor_logs (parking_id, spot_id, event_type, sensor_data)
           VALUES (%s, %s, %s, %s)''',
        (parking_id, spot_id, event, json.dumps(data)),
        fetch=False, commit=True
    )

    updated = execute_one(
        'SELECT available_spots, total_spots FROM parkings WHERE id=%s',
        (parking_id,)
    )

    return jsonify({
        'success':         True,
        'parking_id':      parking_id,
        'available_spots': updated['available_spots'],
        'total_spots':     updated['total_spots']
    }), 200


def _erlang_b(lambda_rate, mu_rate, n):
    if n <= 0 or mu_rate <= 0:
        return 1.0
    a = lambda_rate / mu_rate
    numerator = (a ** n) / math.factorial(min(n, 20))
    denominator = sum(
        (a ** k) / math.factorial(min(k, 20)) for k in range(min(n, 20) + 1)
    )
    return numerator / denominator if denominator else 0


def _predict_spots(parking, minutes_ahead):
    available = parking['available_spots']
    total     = parking['total_spots']
    occupied  = total - available
    lambda_r  = float(parking['lambda']) / 60
    mu_r      = float(parking['mu']) / 60
    net_change = (mu_r * occupied - lambda_r * available) * minutes_ahead
    predicted  = available + round(net_change)
    return max(0, min(total, predicted))
