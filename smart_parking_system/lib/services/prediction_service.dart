import '../models/parking_model.dart';

class PredictionService {
  
  
  static double erlangB(double lambda, double mu, int n) {
    if (n <= 0 || mu <= 0) return 1.0;
    final double a = lambda / mu;
    double numerator = _powDouble(a, n) / _factorial(n);
    double sum = 0;
    for (int k = 0; k <= n; k++) {
      sum += _powDouble(a, k) / _factorial(k);
    }
    return (sum == 0) ? 0 : numerator / sum;
  }

  
  static int predictAvailableSpots(ParkingModel parking, int minutesAhead) {
    final double arrivalRate = parking.lambda / 60; 
    final double departureRate = parking.mu / 60;   
    final int occupied = parking.totalSpots - parking.availableSpots;

    
    final double netChange = (departureRate * occupied - arrivalRate * parking.availableSpots) * minutesAhead;
    final int predicted = parking.availableSpots + netChange.round();
    return predicted.clamp(0, parking.totalSpots);
  }

  
  static double getHeatIntensity(ParkingModel parking) {
    return parking.occupancyRate.clamp(0.0, 1.0);
  }

  
  static String timeUntilFull(ParkingModel parking) {
    final spots = parking.availableSpots;
    if (spots == 0) return 'PUNO';
    if (parking.lambda <= 0) return '∞';

    final double netFillRate = (parking.lambda - parking.mu * (parking.totalSpots - spots)) / 60;
    if (netFillRate <= 0) return 'Stabilno';

    final int minutes = (spots / netFillRate).abs().round();
    if (minutes > 120) return '${(minutes / 60).round()}h';
    return '${minutes}min';
  }

  
  static double recommendationScore(ParkingModel parking, double distanceKm) {
    final double availabilityScore = parking.occupancyRate < 0.85 ? 1 : 0;
    final double proximityScore = 1 / (1 + distanceKm);
    final double priceScore = 1 / parking.pricePerHour;
    final double blockingScore = 1 - parking.erlangBProbability;

    return (availabilityScore * 0.4 +
        proximityScore * 0.3 +
        priceScore * 0.15 +
        blockingScore * 0.15);
  }

  static double _powDouble(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) result *= base;
    return result;
  }

  static double _factorial(int n) {
    if (n <= 1) return 1;
    double result = 1;
    for (int i = 2; i <= n; i++) result *= i;
    return result;
  }
}
