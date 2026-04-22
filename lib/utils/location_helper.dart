import 'package:flutter/foundation.dart';

class Position {
  final double latitude;
  final double longitude;

  Position({required this.latitude, required this.longitude});
}

class LocationHelper {
  static Future<Position?> getCurrentLocation() async {
    if (kIsWeb) {
      return Future.error('Location not available on web. Please enter your location manually.');
    }
    return Future.error('Location services are not available.');
  }

  static Future<double?> calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    return null;
  }

  static double calculateDistanceSync(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(endLatitude - startLatitude);
    final double dLon = _toRadians(endLongitude - startLongitude);
    final double lat1 = _toRadians(startLatitude);
    final double lat2 = _toRadians(endLatitude);
    final double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(lat1) * _cos(lat2) * _sin(dLon / 2) * _sin(dLon / 2);
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * 3.14159265359 / 180;
  static double _sin(double x) => _taylorSin(x);
  static double _cos(double x) => _taylorCos(x);
  static double _sqrt(double x) => _newtonSqrt(x);
  static double _atan2(double y, double x) => _approxAtan2(y, x);
  static double _taylorSin(double x) {
    x = x % (2 * 3.14159265359);
    double result = x;
    double term = x;
    for (int i = 1; i <= 5; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _taylorCos(double x) {
    x = x % (2 * 3.14159265359);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 5; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _newtonSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _approxAtan2(double y, double x) {
    if (x == 0) {
      if (y > 0) return 3.14159265359 / 2;
      if (y < 0) return -3.14159265359 / 2;
      return 0;
    }
    double atan = _taylorAtan(y / x);
    if (x < 0) {
      if (y >= 0) return atan + 3.14159265359;
      return atan - 3.14159265359;
    }
    return atan;
  }

  static double _taylorAtan(double x) {
    if (x.abs() > 1) {
      return (3.14159265359 / 2 - _taylorAtan(1 / x)) * x.sign;
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }
}