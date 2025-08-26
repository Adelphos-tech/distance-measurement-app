import 'dart:math' as math;

class DistanceUtils {
  static double estimateDistanceMeters({required int txPower, required int rssi, required double pathLossExponent}) {
    // distance = 10 ^ ((txPower - RSSI) / (10 * n))
    final double exponent = (txPower - rssi) / (10 * pathLossExponent);
    return math.pow(10.0, exponent).toDouble();
  }

  static double metersToFeet(double meters) => meters * 3.28084;
}

