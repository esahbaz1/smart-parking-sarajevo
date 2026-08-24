import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoggedIn = false;
  String? _primaryVehicleId;

  
  String? _pendingVerificationEmail;

  UserModel? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isPremium => _user?.premium ?? false;
  String? get primaryVehicleId => _primaryVehicleId;
  String? get pendingVerificationEmail => _pendingVerificationEmail;

  
  Future<bool> tryAutoLogin() async {
    final hasSavedSession = await ApiService.loadSession();
    if (!hasSavedSession) return false;

    final refreshed = await ApiService.tryRefreshSession();
    if (!refreshed) {
      ApiService.clearToken();
      return false;
    }

    await fetchCurrentUser();
    return _isLoggedIn;
  }

  
  Future<bool> login(String email, String lozinka) async {
    try {
      final data = await ApiService.login(email: email, lozinka: lozinka);
      _pendingVerificationEmail = null;
      _mapBackendUser(data);
      return true;
    } on ApiException catch (e) {
      if (e.body['requires_verification'] == true) {
        _pendingVerificationEmail = e.body['email']?.toString() ?? email;
      }
      debugPrint('LOGIN FAILED: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      return false;
    }
  }

  
  String? googleLoginError;

  Future<bool> loginWithGoogle() async {
    googleLoginError = null;
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        
        return false;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        googleLoginError = 'Google nije vratio validan token.';
        return false;
      }

      final data = await ApiService.loginWithGoogle(idToken);
      _pendingVerificationEmail = null;
      _mapBackendUser(data);
      return true;
    } on ApiException catch (e) {
      googleLoginError = e.message;
      debugPrint('GOOGLE LOGIN FAILED: ${e.message}');
      return false;
    } catch (e) {
      googleLoginError = 'Google prijava nije uspjela: $e';
      debugPrint('GOOGLE LOGIN ERROR: $e');
      return false;
    }
  }

  
  Future<bool> register({
    required String ime,
    required String prezime,
    required String email,
    required String lozinka,
    required String telefon,
    required Map<String, dynamic> vozilo,
  }) async {
    try {
      final data = await ApiService.register(
        ime: ime,
        prezime: prezime,
        email: email,
        lozinka: lozinka,
        telefon: telefon,
        vozilo: vozilo,
      );
      if (data['requires_verification'] == true) {
        _pendingVerificationEmail = data['email']?.toString() ?? email;
      }
      return true;
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      return false;
    }
  }

  
  Future<bool> verifyEmail(String code) async {
    if (_pendingVerificationEmail == null) return false;
    try {
      final data = await ApiService.verifyEmail(
        email: _pendingVerificationEmail!,
        code: code,
      );
      _pendingVerificationEmail = null;
      _mapBackendUser(data);
      return true;
    } catch (e) {
      debugPrint('VERIFY ERROR: $e');
      return false;
    }
  }

  Future<bool> resendVerificationCode() async {
    if (_pendingVerificationEmail == null) return false;
    try {
      await ApiService.resendVerification(_pendingVerificationEmail!);
      return true;
    } catch (e) {
      debugPrint('RESEND ERROR: $e');
      return false;
    }
  }

  
  Future<void> fetchCurrentUser() async {
    if (!ApiService.isLoggedIn) return;

    try {
      final data = await ApiService.getCurrentUserRaw();
      if (data != null) {
        _mapBackendUser(data);
      }
    } catch (e) {
      debugPrint('FETCH USER EXCEPTION: $e');
    }
  }

  
  void _mapBackendUser(Map<String, dynamic> backendResponse) {
    try {
      final userData = backendResponse['user'] as Map<String, dynamic>;
      final vehicles = (backendResponse['vehicles'] as List<dynamic>?) ?? [];
      final stats = backendResponse['stats'] as Map<String, dynamic>? ?? {};

      _user = UserModel(
        id: userData['id'].toString(),
        ime: userData['ime']?.toString() ?? '',
        prezime: userData['prezime']?.toString() ?? '',
        email: userData['email']?.toString() ?? '',
        premium: (userData['premium'] == 1 || userData['premium'] == true),
        vehiclePlate: vehicles.isNotEmpty ? vehicles.first['tablice']?.toString() : null,
        totalParkings: int.tryParse(stats['total_parkings']?.toString() ?? '0') ?? 0,
        totalMinutesSaved: double.tryParse(stats['total_minutes']?.toString() ?? '0') ?? 0,
        totalCO2Saved: double.tryParse(stats['co2_saved_kg']?.toString() ?? '0') ?? 0,
      );

      _primaryVehicleId = vehicles.isNotEmpty ? vehicles.first['id']?.toString() : null;

      _isLoggedIn = true;
      notifyListeners();
    } catch (e) {
      debugPrint('MAP USER ERROR: $e');
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  
  Future<void> logout() async {
    ApiService.clearToken();
    _user = null;
    _isLoggedIn = false;
    _primaryVehicleId = null;
    _pendingVerificationEmail = null;
    notifyListeners();
  }

  
  void setPrimaryVehicle(String vehicleId) {
    _primaryVehicleId = vehicleId;
    notifyListeners();
  }

  
  Future<bool> upgradeToPremium() async {
    if (!ApiService.isLoggedIn || _user == null) return false;

    final ok = await ApiService.upgradeToPremium();
    if (ok) {
      _user = _user!.copyWith(premium: true);
      notifyListeners();
    }
    return ok;
  }
}
