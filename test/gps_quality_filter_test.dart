import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_telemetry_mobile/models/telemetry_point.dart';
import 'package:fleet_telemetry_mobile/services/gps_quality_filter.dart';

void main() {
  group('GpsQualityFilter', () {
    final t0 = DateTime.utc(2026, 11, 20, 10, 0, 0);

    test('accepts accurate GPS point with plausible movement', () {
      final p1 = TelemetryPoint(
        clientEventId: 'e1',
        tripId: 'T1',
        latitude: 13.6929,
        longitude: -89.2182,
        accuracyMeters: 10.0,
        speedKmh: 30.0,
        heading: 90.0,
        recordedAt: t0,
      );
      final p2 = TelemetryPoint(
        clientEventId: 'e2',
        tripId: 'T1',
        latitude: 13.6939,
        longitude: -89.2182,
        accuracyMeters: 12.0,
        speedKmh: 35.0,
        heading: 90.0,
        recordedAt: t0.add(const Duration(seconds: 15)),
      );

      expect(GpsQualityFilter.evaluate(candidate: p1).accepted, isTrue);
      expect(
        GpsQualityFilter.evaluate(candidate: p2, previousAccepted: p1).accepted,
        isTrue,
      );
    });

    test('rejects Null Island (0,0), low accuracy, and teleportation jumps', () {
      final nullIsland = TelemetryPoint(
        clientEventId: 'bad1',
        tripId: 'T1',
        latitude: 0.0,
        longitude: 0.0,
        accuracyMeters: 5.0,
        speedKmh: 0.0,
        heading: 0.0,
        recordedAt: t0,
      );
      expect(GpsQualityFilter.evaluate(candidate: nullIsland).accepted, isFalse);

      final noisy = TelemetryPoint(
        clientEventId: 'bad2',
        tripId: 'T1',
        latitude: 13.6929,
        longitude: -89.2182,
        accuracyMeters: 120.0,
        speedKmh: 10.0,
        heading: 0.0,
        recordedAt: t0,
      );
      expect(GpsQualityFilter.evaluate(candidate: noisy).accepted, isFalse);

      final anchor = TelemetryPoint(
        clientEventId: 'ok1',
        tripId: 'T1',
        latitude: 13.6929,
        longitude: -89.2182,
        accuracyMeters: 8.0,
        speedKmh: 30.0,
        heading: 0.0,
        recordedAt: t0,
      );
      final teleport = TelemetryPoint(
        clientEventId: 'bad3',
        tripId: 'T1',
        latitude: 14.5000,
        longitude: -89.2182,
        accuracyMeters: 8.0,
        speedKmh: 30.0,
        heading: 0.0,
        recordedAt: t0.add(const Duration(seconds: 5)),
      );
      expect(
        GpsQualityFilter.evaluate(candidate: teleport, previousAccepted: anchor).accepted,
        isFalse,
      );
    });
  });
}
