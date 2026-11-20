import 'dart:math' as math;
import '../models/telemetry_point.dart';

class GpsFixEvaluation {
  final bool accepted;
  final String reason;

  const GpsFixEvaluation({required this.accepted, required this.reason});
}

/// Evaluates GPS fix quality and prevents corrupted or teleported coordinates
/// from entering the offline telemetry queue.
class GpsQualityFilter {
  static const double maxAllowedAccuracyMeters = 50.0;
  static const double maxPlausibleSpeedKmh = 180.0;

  static GpsFixEvaluation evaluate({
    required TelemetryPoint candidate,
    TelemetryPoint? previousAccepted,
  }) {
    if (candidate.latitude < -90 ||
        candidate.latitude > 90 ||
        candidate.longitude < -180 ||
        candidate.longitude > 180) {
      return const GpsFixEvaluation(
        accepted: false,
        reason: 'Coordinates out of geographic bounds',
      );
    }

    if (candidate.latitude == 0.0 && candidate.longitude == 0.0) {
      return const GpsFixEvaluation(
        accepted: false,
        reason: 'Null Island (0,0) coordinate rejected',
      );
    }

    if (candidate.accuracyMeters <= 0 ||
        candidate.accuracyMeters > maxAllowedAccuracyMeters) {
      return GpsFixEvaluation(
        accepted: false,
        reason:
            'Low GPS accuracy (${candidate.accuracyMeters.toStringAsFixed(1)}m > ${maxAllowedAccuracyMeters.toInt()}m)',
      );
    }

    if (previousAccepted != null) {
      final elapsedSeconds = candidate.recordedAt
          .difference(previousAccepted.recordedAt)
          .inMilliseconds /
          1000.0;

      if (elapsedSeconds <= 0) {
        return const GpsFixEvaluation(
          accepted: false,
          reason: 'Out-of-order timestamp rejected',
        );
      }

      final distanceKm = haversineKm(
        previousAccepted.latitude,
        previousAccepted.longitude,
        candidate.latitude,
        candidate.longitude,
      );
      final impliedSpeedKmh = (distanceKm / elapsedSeconds) * 3600.0;

      if (impliedSpeedKmh > maxPlausibleSpeedKmh && distanceKm > 0.05) {
        return GpsFixEvaluation(
          accepted: false,
          reason:
              'Unrealistic GPS jump (${impliedSpeedKmh.toStringAsFixed(0)} km/h)',
        );
      }
    }

    return const GpsFixEvaluation(accepted: true, reason: 'Valid GPS fix');
  }

  /// Computes great-circle distance between two coordinates in kilometers.
  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double deg) => deg * (math.pi / 180.0);
}
