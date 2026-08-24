import os
import requests
from flask import Blueprint, request, jsonify

routing_bp = Blueprint('routing', __name__)


OSRM_BASE_URL = os.getenv('OSRM_BASE_URL', 'https://router.project-osrm.org')


_MODIFIER_TXT = {
    'uturn': 'napravite U-okret',
    'sharp right': 'oštro desno',
    'right': 'desno',
    'slight right': 'blago desno',
    'straight': 'pravo',
    'slight left': 'blago lijevo',
    'left': 'lijevo',
    'sharp left': 'oštro lijevo',
}


def _street_suffix(name):
    return f' u {name}' if name else ''


def _translate_step(step, is_last):
    maneuver = step.get('maneuver', {})
    mtype = maneuver.get('type')
    modifier = maneuver.get('modifier')
    name = (step.get('name') or '').strip()
    exit_num = maneuver.get('exit')
    side = _MODIFIER_TXT.get(modifier, 'pravo')
    street = _street_suffix(name)

    if is_last or mtype == 'arrive':
        return 'Stigli ste do cilja'
    if mtype == 'depart':
        return f'Krenite pravo{street}'
    if mtype in ('roundabout', 'rotary'):
        if exit_num:
            return f'Na kružnom toku uzmite {exit_num}. izlaz{street}'
        return f'Uđite u kružni tok{street}'
    if mtype in ('exit roundabout', 'exit rotary'):
        return f'Izađite iz kružnog toka{street}'
    if mtype == 'roundabout turn':
        return f'Na kružnom toku skrenite {side}{street}'
    if mtype == 'merge':
        return f'Uključite se na cestu{street}'
    if mtype == 'on ramp':
        return f'Uđite na rampu{street}'
    if mtype == 'off ramp':
        return f'Izađite sa rampe{street}'
    if mtype == 'fork':
        return f'Na račvanju držite se {side}{street}'
    if mtype == 'end of road':
        return f'Na kraju ceste skrenite {side}{street}'
    if mtype in ('continue', 'new name'):
        if modifier in (None, 'straight'):
            return f'Nastavite pravo{street}'
        return f'Skrenite {side}{street}'
    if mtype == 'turn':
        return f'Skrenite {side}{street}'
    
    return f'Nastavite pravo{street}'


def _build_steps(osrm_steps):
    result = []
    n = len(osrm_steps)
    for i, step in enumerate(osrm_steps):
        maneuver = step.get('maneuver', {})
        loc = maneuver.get('location', [0, 0])  
        result.append({
            'instruction': _translate_step(step, is_last=(i == n - 1)),
            'street': (step.get('name') or '').strip() or None,
            'maneuver_type': maneuver.get('type'),
            'modifier': maneuver.get('modifier'),
            'distance_m': round(step.get('distance', 0)),
            'location': [loc[1], loc[0]],  
        })
    return result


@routing_bp.route('/', methods=['GET'])
def get_route():
    try:
        from_lat = float(request.args['from_lat'])
        from_lng = float(request.args['from_lng'])
        to_lat = float(request.args['to_lat'])
        to_lng = float(request.args['to_lng'])
    except (KeyError, ValueError):
        return jsonify({'error': 'Parametri from_lat, from_lng, to_lat, to_lng su obavezni'}), 400

    url = (
        f'{OSRM_BASE_URL}/route/v1/driving/'
        f'{from_lng},{from_lat};{to_lng},{to_lat}'
        f'?overview=full&geometries=geojson&steps=true'
    )

    try:
        resp = requests.get(url, timeout=8)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        return jsonify({'error': f'Routing servis nedostupan: {e}'}), 502

    if data.get('code') != 'Ok' or not data.get('routes'):
        return jsonify({'error': 'Ruta nije pronađena'}), 404

    route = data['routes'][0]
    osrm_steps = route.get('legs', [{}])[0].get('steps', [])

    return jsonify({
        'geometry': route['geometry'],              
        'distance_m': route['distance'],
        'duration_s': route['duration'],
        'distance_km': round(route['distance'] / 1000, 2),
        'duration_min': round(route['duration'] / 60, 1),
        'steps': _build_steps(osrm_steps),          
    }), 200
