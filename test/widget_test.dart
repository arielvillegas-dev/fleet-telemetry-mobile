import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_telemetry_mobile/main.dart';
import 'package:fleet_telemetry_mobile/services/offline_queue_store.dart';
import 'package:fleet_telemetry_mobile/services/telemetry_sync_client.dart';

void main() {
  testWidgets('Dashboard queues valid GPS, rejects noisy GPS, and syncs batch', (tester) async {
    final store = InMemoryTelemetryStore();
    final transport = SimulatedTelemetryTransport();

    await tester.pumpWidget(
      FleetTelemetryApp(
        store: store,
        transport: transport,
        enableMapTiles: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queued: 0'), findsOneWidget);

    await tester.tap(find.text('Valid GPS'));
    await tester.pumpAndSettle();
    expect(find.text('Queued: 1'), findsOneWidget);
    expect(find.text('Accepted: 1'), findsOneWidget);

    await tester.tap(find.text('Noisy GPS'));
    await tester.pumpAndSettle();
    expect(find.text('Rejected: 1'), findsOneWidget);

    await tester.tap(find.text('Sync Batch'));
    await tester.pumpAndSettle();
    expect(find.text('Queued: 0'), findsOneWidget);
  });
}
