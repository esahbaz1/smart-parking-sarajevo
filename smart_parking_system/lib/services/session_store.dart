import 'package:shared_preferences/shared_preferences.dart';


class NotificationPrefsStore {
  static const _kFreeSpot = 'sp_notif_free_spot';
  static const _kReservation = 'sp_notif_reservation';
  static const _kPromotions = 'sp_notif_promotions';
  static const _kChat = 'sp_notif_chat';

  static Future<Map<String, bool>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'freeSpot': prefs.getBool(_kFreeSpot) ?? true,
      'reservation': prefs.getBool(_kReservation) ?? true,
      'promotions': prefs.getBool(_kPromotions) ?? false,
      'chat': prefs.getBool(_kChat) ?? true,
    };
  }

  static Future<void> setValue(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    const map = {
      'freeSpot': _kFreeSpot,
      'reservation': _kReservation,
      'promotions': _kPromotions,
      'chat': _kChat,
    };
    final prefKey = map[key];
    if (prefKey != null) await prefs.setBool(prefKey, value);
  }
}


class CarLocationStore {
  static const _kLat = 'sp_car_lat';
  static const _kLng = 'sp_car_lng';
  static const _kLabel = 'sp_car_label';
  static const _kSavedAt = 'sp_car_saved_at';

  static Future<void> save({
    required double lat,
    required double lng,
    required String label,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLng, lng);
    await prefs.setString(_kLabel, label);
    await prefs.setString(_kSavedAt, DateTime.now().toIso8601String());
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    if (lat == null || lng == null) return null;
    return {
      'lat': lat,
      'lng': lng,
      'label': prefs.getString(_kLabel) ?? 'Moj auto',
      'savedAt': prefs.getString(_kSavedAt),
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLat);
    await prefs.remove(_kLng);
    await prefs.remove(_kLabel);
    await prefs.remove(_kSavedAt);
  }
}


class SessionStore {
  static const _kAccess = 'sp_access_token';
  static const _kRefresh = 'sp_refresh_token';
  static const _kUserId = 'sp_user_id';

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, accessToken);
    await prefs.setString(_kRefresh, refreshToken);
    if (userId != null) await prefs.setString(_kUserId, userId);
  }

  static Future<void> saveAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, accessToken);
  }

  static Future<Map<String, String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'access': prefs.getString(_kAccess),
      'refresh': prefs.getString(_kRefresh),
      'userId': prefs.getString(_kUserId),
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUserId);
  }
}
