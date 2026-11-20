import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_telemetry_mobile/models/telemetry_point.dart';
import 'package:fleet_telemetry_mobile/providers/tracking_provider.dart';
import 'package:fleet_telemetry_mobile/services/offline_queue_store.dart';
import 'package:fleet_telemetry_mobile/services/telemetry_sync_client.dart';

void main() {
  test('TrackingProvider buffers points offline and clears pending queue after sync', () async {
    final store = InMemoryTelemetryStore();
    final transport = SimulatedTelemetryTransport()..simulateOffline = true;
    final provider = TrackingProvider(store: store, transport: transport);

    final baseTime = DateTime.utc(2026, 11, 20, 10, 0);
    final ok1 = await provider.recordPoint(TelemetryPoint(
      clientEventId: 'e1',
      tripId: provider.tripId,
      latitude: 13.6929,
      longitude: -89.2182,
      accuracyMeters: 8.0,
      speedKmh: 30.0,
      heading: 0.0,
      recordedAt: baseTime,
    ));
    final ok2 = await provider.recordPoint(TelemetryPoint(
      clientEventId: 'e2',
      tripId: provider.tripId,
      latitude: 13.6960,
      longitude: -89.2182,
      accuracyMeters: 8.0,
      speedKmh: 35.0,
      heading: 0.0,
      recordedAt: baseTime.add(const Duration(seconds: 30)),
    ));

    expect(ok1, isTrue);
    expect(ok2, isTrue);
    expect(provider.pendingCount, 2);
    expect(provider.distanceKm, greaterThan(0.3));

    // Sync fails while offline -> points stay queued
    await provider.syncPendingBatch();
    expect(provider.pendingCount, 2);

    // Restore network and sync -> queue drained
    provider.toggleOfflineSimulation(false);
    await provider.syncPendingBatch();
    expect(provider.pendingCount, 0);
  });
}
