class ParkingModel {
  final String id;
  final String naziv;
  final double lat;
  final double lng;
  final int totalSpots;
  int availableSpots;
  final double pricePerHour;
  final double lambda;
  final double mu;
  final String adresa;
  final String? imageUrl;
  final List<double> hourlyOccupancy;
  
  
  final double erlangBlocking;

  ParkingModel({
    required this.id,
    required this.naziv,
    required this.lat,
    required this.lng,
    required this.totalSpots,
    required this.availableSpots,
    required this.pricePerHour,
    required this.lambda,
    required this.mu,
    required this.adresa,
    this.imageUrl,
    List<double>? hourlyOccupancy,
    this.erlangBlocking = 0.0,
  }) : hourlyOccupancy = hourlyOccupancy ?? List.filled(24, 0.0);

  double get occupancyRate =>
      totalSpots > 0 ? (totalSpots - availableSpots) / totalSpots : 0.0;

  bool get isAvailable => availableSpots > 0;

  
  double get erlangBProbability {
    
    if (erlangBlocking > 0.0) return erlangBlocking;
    return _erlangBLocal();
  }

  double _erlangBLocal() {
    const int maxN = 20; 
    final double a = mu > 0 ? lambda / mu : 0.0;
    final int n = totalSpots.clamp(0, maxN);

    double numerator = _pow(a, n) / _factorial(n);
    double denominator = 0;
    for (int k = 0; k <= n; k++) {
      denominator += _pow(a, k) / _factorial(k);
    }
    if (denominator == 0 || denominator.isNaN || denominator.isInfinite) {
      return 0.0;
    }
    final result = numerator / denominator;
    return result.isNaN || result.isInfinite ? 0.0 : result;
  }

  int get minutesUntilFull {
    if (availableSpots == 0) return 0;
    if (lambda <= 0) return 999;
    return ((availableSpots / lambda) * 60).round();
  }

  double _pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  double _factorial(int n) {
    if (n <= 1) return 1;
    double result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  
  static double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
    return fallback;
  }

  factory ParkingModel.fromJson(Map<String, dynamic> json) {
    return ParkingModel(
      
      id: json['id'].toString(),

      naziv: json['naziv'] ?? '',

      
      lat: _toDouble(json['lat'] ?? json['latitude']),
      lng: _toDouble(json['lng'] ?? json['longitude']),

      
      totalSpots:     _toInt(json['total_spots']     ?? json['totalSpots']),
      availableSpots: _toInt(json['available_spots'] ?? json['availableSpots']),

      pricePerHour: _toDouble(json['price_per_hour'] ?? json['pricePerHour']),
      lambda:       _toDouble(json['lambda'], 1.0),
      mu:           _toDouble(json['mu'], 0.5),
      adresa:       (json['adresa']          ?? '') as String,
      imageUrl:     (json['image_url']       ?? json['imageUrl']) as String?,

      
      erlangBlocking: _toDouble(json['erlang_blocking']),

      
      hourlyOccupancy: _parseHourlyData(json),
    );
  }

  
  static List<double> _parseHourlyData(Map<String, dynamic> json) {
    
    final rawHourly = json['hourly_data'] as List<dynamic>?;
    if (rawHourly != null && rawHourly.isNotEmpty) {
      final result = List<double>.filled(24, 0.0);
      for (final item in rawHourly) {
        final sat    = _toInt(item['sat']);
        final ulasci = _toInt(item['ulasci']);
        final izlasci = _toInt(item['izlasci']);
        if (sat >= 0 && sat < 24) {
          
          result[sat] = (ulasci - izlasci).toDouble().clamp(0.0, double.maxFinite);
        }
      }
      return result;
    }

    
    final rawList = json['hourlyOccupancy'] as List<dynamic>?;
    if (rawList != null) {
      return rawList.map((e) => _toDouble(e)).toList();
    }

    return List.filled(24, 0.0);
  }

  Map<String, dynamic> toJson() => {
    'id':              id,
    'naziv':           naziv,
    'lat':             lat,
    'lng':             lng,
    'total_spots':     totalSpots,
    'available_spots': availableSpots,
    'price_per_hour':  pricePerHour,
    'lambda':          lambda,
    'mu':              mu,
    'adresa':          adresa,
    'image_url':       imageUrl,
    'hourlyOccupancy': hourlyOccupancy,
    'erlang_blocking': erlangBlocking,
  };

  ParkingModel copyWith({
    int? availableSpots,
    double? erlangBlocking,
    List<double>? hourlyOccupancy,
  }) {
    return ParkingModel(
      id:              id,
      naziv:           naziv,
      lat:             lat,
      lng:             lng,
      totalSpots:      totalSpots,
      availableSpots:  availableSpots  ?? this.availableSpots,
      pricePerHour:    pricePerHour,
      lambda:          lambda,
      mu:              mu,
      adresa:          adresa,
      imageUrl:        imageUrl,
      erlangBlocking:  erlangBlocking  ?? this.erlangBlocking,
      hourlyOccupancy: hourlyOccupancy ?? this.hourlyOccupancy,
    );
  }
}
