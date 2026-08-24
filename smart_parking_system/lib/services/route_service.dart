import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import '../core/constants.dart';


String formatRouteDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}


class RouteStep {
  final String instruction;
  final String? street;
  final String maneuverType;
  final String? modifier;
  final double distanceMeters;
  final ll.LatLng location;

  RouteStep({
    required this.instruction,
    required this.street,
    required this.maneuverType,
    required this.modifier,
    required this.distanceMeters,
    required this.location,
  });

  factory RouteStep.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] as List;
    return RouteStep(
      instruction: j['instruction'] as String,
      street: j['street'] as String?,
      maneuverType: j['maneuver_type'] as String? ?? '',
      modifier: j['modifier'] as String?,
      distanceMeters: (j['distance_m'] as num).toDouble(),
      location: ll.LatLng((loc[0] as num).toDouble(), (loc[1] as num).toDouble()),
    );
  }

  
  IconData get icon {
    switch (maneuverType) {
      case 'depart':
        return Icons.navigation_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      case 'roundabout':
      case 'rotary':
      case 'roundabout turn':
      case 'exit roundabout':
      case 'exit rotary':
        return Icons.roundabout_left_rounded;
      case 'merge':
      case 'on ramp':
      case 'off ramp':
      case 'fork':
        return Icons.merge_rounded;
      default:
        switch (modifier) {
          case 'uturn':
            return Icons.u_turn_left_rounded;
          case 'sharp right':
          case 'right':
            return Icons.turn_right_rounded;
          case 'slight right':
            return Icons.turn_slight_right_rounded;
          case 'sharp left':
          case 'left':
            return Icons.turn_left_rounded;
          case 'slight left':
            return Icons.turn_slight_left_rounded;
          default:
            return Icons.straight_rounded;
        }
    }
  }
}

class RouteResult {
  final List<ll.LatLng> points;
  final double distanceKm;
  final double durationMin;
  final List<RouteStep> steps;

  RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    required this.steps,
  });
}


class RouteService {
  static Future<RouteResult> getDrivingRoute({
    required ll.LatLng from,
    required ll.LatLng to,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl.replaceFirst('/api', '')}/api/route/'
      '?from_lat=${from.latitude}&from_lng=${from.longitude}'
      '&to_lat=${to.latitude}&to_lng=${to.longitude}',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Ruta nije dostupna');
    }

    final coords = (data['geometry']['coordinates'] as List)
        .map((c) => ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final steps = ((data['steps'] as List?) ?? [])
        .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
        .toList();

    return RouteResult(
      points: coords,
      distanceKm: (data['distance_km'] as num).toDouble(),
      durationMin: (data['duration_min'] as num).toDouble(),
      steps: steps,
    );
  }
}
