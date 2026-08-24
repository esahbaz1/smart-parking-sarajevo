import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  
  
  static const String _lanIp = '192.168.20.20'; 

  static const String _apiBaseOverride = String.fromEnvironment('API_BASE_URL');
  static const String _wsBaseOverride = String.fromEnvironment('WS_BASE_URL');

  static String get baseUrl {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    if (kIsWeb) return 'http://localhost:5000/api';
    return 'http://$_lanIp:5000/api';
  }

  static String get wsUrl {
    if (_wsBaseOverride.isNotEmpty) return '$_wsBaseOverride/ws/parking';
    if (kIsWeb) return 'http://localhost:5001/ws/parking';
    return 'http://$_lanIp:5001/ws/parking';
  }

  
  static String get notificationsWsUrl {
    if (_apiBaseOverride.isNotEmpty) {
      final base = _apiBaseOverride.endsWith('/api')
          ? _apiBaseOverride.substring(0, _apiBaseOverride.length - 4)
          : _apiBaseOverride;
      return '$base/ws/notifications';
    }
    if (kIsWeb) return 'http://localhost:5000/ws/notifications';
    return 'http://$_lanIp:5000/ws/notifications';
  }

  static const int refreshInterval = 20; 
  
  
  static const double sarajevoLat = 43.8563;
  static const double sarajevoLng = 18.4131;

  
  static const double defaultZoom = 14.5;

  
  static const double defaultMu = 0.5;

  
  static const String currency = 'KM';

  
  static const Duration shortAnim = Duration(milliseconds: 200);
  static const Duration mediumAnim = Duration(milliseconds: 400);
  static const Duration longAnim = Duration(milliseconds: 700);
}
