import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/parking_model.dart';
import '../services/api_service.dart';
import '../core/constants.dart';

class ParkingProvider extends ChangeNotifier {
  List<ParkingModel> _parkings = [];
  ParkingModel? _selectedParking;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  Timer? _refreshTimer;
  String _searchQuery = '';

  List<ParkingModel> get parkings    => _filteredParkings;
  List<ParkingModel> get allParkings => _parkings;
  ParkingModel? get selectedParking  => _selectedParking;
  bool get isLoading                 => _isLoading;
  String? get error                  => _error;
  String get searchQuery             => _searchQuery;

  List<ParkingModel> get _filteredParkings {
    if (_searchQuery.isEmpty) return _parkings;
    return _parkings
        .where((p) =>
            p.naziv.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.adresa.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  
  List<ParkingModel> get nearbyParkings {
    final sorted = List<ParkingModel>.from(_parkings);
    sorted.sort((a, b) => a.occupancyRate.compareTo(b.occupancyRate));
    return sorted;
  }

  Future<void> loadParkings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _parkings = await ApiService.getParkings();
      _startAutoRefresh();
    } catch (e) {
      _error = 'Greška pri učitavanju: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    
    
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final List<ParkingModel> fresh = await ApiService.getParkings();

      
      for (int i = 0; i < fresh.length; i++) {
        final existing = _parkings.firstWhere(
          (p) => p.id == fresh[i].id,
          orElse: () => fresh[i],
        );
        
        
        if (existing.availableSpots != fresh[i].availableSpots) {
          fresh[i] = fresh[i].copyWith(
            availableSpots: existing.availableSpots,
          );
        }
      }

      _parkings = fresh;

      if (_selectedParking != null) {
        _selectedParking = _parkings.firstWhere(
          (p) => p.id == _selectedParking!.id,
          orElse: () => _selectedParking!,
        );
      }

      notifyListeners();
    } catch (_) {
      
    } finally {
      _isRefreshing = false;
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: AppConstants.refreshInterval),
      (_) => refresh(),
    );
  }

  void selectParking(ParkingModel parking) {
    _selectedParking = parking;
    notifyListeners();
  }

  void clearSelection() {
    _selectedParking = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  
  void updateAvailability(String parkingId, int newAvailableSpots) {
    final index = _parkings.indexWhere((p) => p.id == parkingId);
    if (index == -1) return; 

    _parkings[index] = _parkings[index].copyWith(
      availableSpots: newAvailableSpots,
    );

    
    if (_selectedParking?.id == parkingId) {
      _selectedParking = _parkings[index];
    }

    notifyListeners();
  }

  
  ParkingModel? getParking(String id) {
    try {
      return _parkings.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
