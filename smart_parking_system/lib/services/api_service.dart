import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import '../models/parking_model.dart';
import 'session_store.dart';

class ApiService {
  static String? _accessToken;
  static String? _refreshToken;

  static bool get isLoggedIn => _accessToken != null;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  static void setTokens({required String access, required String refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
    SessionStore.save(accessToken: access, refreshToken: refresh);
  }

  static void setAccessToken(String token) => _accessToken = token;

  static void clearToken() {
    _accessToken = null;
    _refreshToken = null;
    SessionStore.clear();
  }

  
  static Future<bool> loadSession() async {
    final saved = await SessionStore.load();
    _accessToken = saved['access'];
    _refreshToken = saved['refresh'];
    return _refreshToken != null;
  }

  
  static Future<bool> tryRefreshSession() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_refreshToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        if (_accessToken != null) {
          await SessionStore.saveAccessToken(_accessToken!);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  
  static Future<http.Response> _authorized(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();
    if (response.statusCode == 401) {
      final refreshed = await tryRefreshSession();
      if (refreshed) {
        response = await request();
      }
    }
    return response;
  }

  
  static Future<List<ParkingModel>> getParkings() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/parkings/'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => ParkingModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Status: ${response.statusCode}');
    } catch (_) {
      return _mockParkings();
    }
  }

  static Future<ParkingModel> getParkingById(String id) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/parkings/$id'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ParkingModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Status: ${response.statusCode}');
    } catch (_) {
      return _mockParkings().firstWhere(
        (p) => p.id == id,
        orElse: () => _mockParkings().first,
      );
    }
  }

  
  static Future<Map<String, dynamic>> createReservation({
    required String parkingId,
    required String vehicleId,
    required DateTime startTime,
    required Duration duration,
  }) async {
    try {
      final response = await _authorized(() => http
          .post(
            Uri.parse('${AppConstants.baseUrl}/reservations/'),
            headers: _headers,
            body: jsonEncode({
              'parking_id':   int.tryParse(parkingId) ?? 1,
              'vehicle_id':   int.tryParse(vehicleId) ?? 1,
              'start_time':   startTime.toIso8601String(),
              'duration_min': duration.inMinutes,
            }),
          )
          .timeout(const Duration(seconds: 10)));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201) return data;
      throw Exception(data['error'] ?? 'Greška pri rezervaciji');
    } catch (_) {
      return {
        'reservation_id': DateTime.now().millisecondsSinceEpoch,
        'qr_code':        'SP-${DateTime.now().millisecondsSinceEpoch}',
        'status':         'confirmed',
      };
    }
  }

  
  static Future<Map<String, dynamic>> login({
    required String email,
    required String lozinka,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/auth/login'),
          headers: _headers,
          body: jsonEncode({'email': email, 'lozinka': lozinka}),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access != null && refresh != null) {
        setTokens(access: access, refresh: refresh);
      }
      return data;
    }
    
    
    throw ApiException(data['error'] ?? 'Pogrešan email ili lozinka', data, response.statusCode);
  }

  
  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/auth/google'),
          headers: _headers,
          body: jsonEncode({'id_token': idToken}),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access != null && refresh != null) {
        setTokens(access: access, refresh: refresh);
      }
      return data;
    }
    throw ApiException(data['error'] ?? 'Google prijava neuspješna', data, response.statusCode);
  }

  static Future<Map<String, dynamic>> register({
    required String ime,
    required String prezime,
    required String email,
    required String lozinka,
    String? telefon,
    Map<String, dynamic>? vozilo,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/auth/register'),
          headers: _headers,
          body: jsonEncode({
            'ime':     ime,
            'prezime': prezime,
            'email':   email,
            'lozinka': lozinka,
            if (telefon != null) 'telefon': telefon,
            if (vozilo  != null) 'vozilo':  vozilo,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      
      return data;
    }
    throw ApiException(data['error'] ?? 'Greška pri registraciji', data, response.statusCode);
  }

  static Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/auth/verify-email'),
          headers: _headers,
          body: jsonEncode({'email': email, 'code': code}),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access != null && refresh != null) {
        setTokens(access: access, refresh: refresh);
      }
      return data;
    }
    throw ApiException(data['error'] ?? 'Pogrešan kod', data, response.statusCode);
  }

  static Future<void> resendVerification(String email) async {
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/auth/resend-verification'),
          headers: _headers,
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(data['error'] ?? 'Greška pri slanju koda', data, response.statusCode);
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUserRaw() async {
    final response = await _authorized(() => http
        .get(Uri.parse('${AppConstants.baseUrl}/auth/me'), headers: _headers)
        .timeout(const Duration(seconds: 10)));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<bool> upgradeToPremium() async {
    final response = await _authorized(() => http
        .post(Uri.parse('${AppConstants.baseUrl}/auth/upgrade'), headers: _headers)
        .timeout(const Duration(seconds: 10)));
    return response.statusCode == 200;
  }

  
  static Future<void> changePassword({
    required String trenutnaLozinka,
    required String novaLozinka,
  }) async {
    final response = await _authorized(() => http.post(
          Uri.parse('${AppConstants.baseUrl}/auth/change-password'),
          headers: _headers,
          body: jsonEncode({
            'trenutna_lozinka': trenutnaLozinka,
            'nova_lozinka': novaLozinka,
          }),
        ).timeout(const Duration(seconds: 10)));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(data['error'] ?? 'Greška pri promjeni lozinke', data, response.statusCode);
    }
  }

  
  static Future<List<dynamic>> getParkingSpots(String parkingId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/parkings/$parkingId/spots'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> submitParkingReport({
    required String parkingId,
    required String opis,
    XFile? photo,
    String? spotNumber,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/reports/');

    Future<http.Response> doRequest() async {
      final request = http.MultipartRequest('POST', uri);
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }
      request.fields['parking_id'] = parkingId;
      request.fields['opis'] = opis;
      if (spotNumber != null && spotNumber.isNotEmpty) {
        request.fields['spot_number'] = spotNumber;
      }

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: photo.name,
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      return http.Response.fromStream(streamed);
    }

    final response = await _authorized(doRequest);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return data;
    throw ApiException(data['error'] ?? 'Greška pri slanju prijave', data, response.statusCode);
  }

  static Future<List<dynamic>> getMyReports() async {
    final response = await _authorized(() => http
        .get(Uri.parse('${AppConstants.baseUrl}/reports/my'), headers: _headers)
        .timeout(const Duration(seconds: 10)));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  
  static Future<List<dynamic>> getChatMessages(String parkingId) async {
    final response = await _authorized(() => http
        .get(Uri.parse('${AppConstants.baseUrl}/chat/$parkingId'), headers: _headers)
        .timeout(const Duration(seconds: 10)));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['messages'] as List<dynamic>?) ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required String parkingId,
    required String poruka,
  }) async {
    final response = await _authorized(() => http
        .post(
          Uri.parse('${AppConstants.baseUrl}/chat/$parkingId'),
          headers: _headers,
          body: jsonEncode({'poruka': poruka}),
        )
        .timeout(const Duration(seconds: 15)));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return data;
    throw ApiException(data['error'] ?? 'Greška pri slanju poruke', data, response.statusCode);
  }

  
  static Future<bool> toggleFavorite(String parkingId) async {
    final response = await _authorized(() => http
        .post(Uri.parse('${AppConstants.baseUrl}/favorites/$parkingId'), headers: _headers)
        .timeout(const Duration(seconds: 10)));
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['favorited'] as bool? ?? false;
    }
    return false;
  }

  static Future<List<String>> getFavoriteIds() async {
    final response = await _authorized(() => http
        .get(Uri.parse('${AppConstants.baseUrl}/favorites/'), headers: _headers)
        .timeout(const Duration(seconds: 10)));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => e['id'].toString()).toList();
    }
    return [];
  }

  
  static Future<List<ParkingModel>> getFavoriteParkings() async {
    final response = await _authorized(() => http
        .get(Uri.parse('${AppConstants.baseUrl}/favorites/'), headers: _headers)
        .timeout(const Duration(seconds: 10)));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => ParkingModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  
  static List<ParkingModel> _mockParkings() {
    return [
      ParkingModel(
        id: '1',
        naziv: 'Parking BBI Centar',
        lat: 43.8580, lng: 18.4136,
        totalSpots: 350, availableSpots: 42,
        pricePerHour: 3.0,
        lambda: 2.8, mu: 0.5,
        adresa: 'Trg djece Sarajeva bb',
        hourlyOccupancy: [0.2,0.1,0.1,0.1,0.15,0.25,0.4,0.65,0.85,0.9,0.88,0.85,0.8,0.82,0.84,0.88,0.92,0.85,0.7,0.55,0.45,0.35,0.25,0.2],
      ),
      ParkingModel(
        id: '2',
        naziv: 'Parking Skenderija',
        lat: 43.8535, lng: 18.4200,
        totalSpots: 200, availableSpots: 128,
        pricePerHour: 2.0,
        lambda: 1.5, mu: 0.4,
        adresa: 'Terezija 1, Sarajevo',
        hourlyOccupancy: [0.1,0.1,0.1,0.1,0.1,0.2,0.35,0.55,0.65,0.7,0.68,0.65,0.6,0.62,0.65,0.7,0.75,0.65,0.5,0.4,0.3,0.2,0.15,0.1],
      ),
      ParkingModel(
        id: '3',
        naziv: 'Parking Baščaršija',
        lat: 43.8600, lng: 18.4310,
        totalSpots: 120, availableSpots: 4,
        pricePerHour: 2.5,
        lambda: 3.2, mu: 0.3,
        adresa: 'Bravadžiluk 2, Sarajevo',
        hourlyOccupancy: [0.3,0.2,0.15,0.15,0.2,0.4,0.6,0.8,0.92,0.95,0.97,0.98,0.95,0.96,0.97,0.98,0.99,0.97,0.9,0.8,0.7,0.55,0.4,0.3],
      ),
      ParkingModel(
        id: '4',
        naziv: 'Parking City Center',
        lat: 43.8490, lng: 18.3950,
        totalSpots: 500, availableSpots: 215,
        pricePerHour: 2.0,
        lambda: 2.0, mu: 0.6,
        adresa: 'Džemala Bijedića 185',
        hourlyOccupancy: [0.1,0.1,0.1,0.1,0.15,0.3,0.5,0.7,0.8,0.78,0.75,0.72,0.68,0.7,0.72,0.75,0.82,0.75,0.6,0.5,0.4,0.3,0.2,0.15],
      ),
      ParkingModel(
        id: '5',
        naziv: 'Parking Hotel Holiday',
        lat: 43.8470, lng: 18.3890,
        totalSpots: 150, availableSpots: 89,
        pricePerHour: 3.5,
        lambda: 1.2, mu: 0.45,
        adresa: 'Zmaja od Bosne 4',
        hourlyOccupancy: [0.2,0.15,0.15,0.1,0.1,0.2,0.3,0.5,0.6,0.65,0.62,0.6,0.55,0.58,0.6,0.65,0.7,0.65,0.5,0.4,0.35,0.3,0.25,0.2],
      ),
    ];
  }
}


class ApiException implements Exception {
  final String message;
  final Map<String, dynamic> body;
  final int statusCode;
  ApiException(this.message, this.body, this.statusCode);

  @override
  String toString() => message;
}
