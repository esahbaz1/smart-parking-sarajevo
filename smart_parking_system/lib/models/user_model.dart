class UserModel {
  final String id;
  final String ime;
  final String prezime;
  final String email;
  final bool premium;
  final String? vehiclePlate;
  final int totalParkings;
  final double totalMinutesSaved;
  final double totalCO2Saved;

  UserModel({
    required this.id,
    required this.ime,
    required this.prezime,
    required this.email,
    this.premium = false,
    this.vehiclePlate,
    this.totalParkings = 0,
    this.totalMinutesSaved = 0,
    this.totalCO2Saved = 0,
  });

  
  static double _toDouble(dynamic value, [double fallback = 0]) {
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      ime: json['ime'] ?? '',
      prezime: json['prezime'] ?? '',
      email: json['email'] ?? '',
      premium: json['premium'] ?? false,
      vehiclePlate: json['vehiclePlate'],
      totalParkings: _toInt(json['totalParkings']),
      totalMinutesSaved: _toDouble(json['totalMinutesSaved']),
      totalCO2Saved: _toDouble(json['totalCO2Saved']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ime': ime,
    'prezime': prezime,
    'email': email,
    'premium': premium,
    'vehiclePlate': vehiclePlate,
    'totalParkings': totalParkings,
    'totalMinutesSaved': totalMinutesSaved,
    'totalCO2Saved': totalCO2Saved,
  };
  
UserModel copyWith({
  String? id,
  String? ime,
  String? prezime, 
  String? email,
  bool? premium,
  String? vehiclePlate,
  int? totalParkings,
  double? totalMinutesSaved,
  double? totalCO2Saved,
}) {
  return UserModel(
    id: id ?? this.id,
    ime: ime ?? this.ime,
    prezime: prezime ?? this.prezime, 
    email: email ?? this.email,
    premium: premium ?? this.premium,
    vehiclePlate: vehiclePlate ?? this.vehiclePlate,
    totalParkings: totalParkings ?? this.totalParkings,
    totalMinutesSaved: totalMinutesSaved ?? this.totalMinutesSaved,
    totalCO2Saved: totalCO2Saved ?? this.totalCO2Saved,
  );
}
}
