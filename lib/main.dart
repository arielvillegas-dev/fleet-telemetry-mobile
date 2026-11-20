import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/tracking_provider.dart';
import 'services/offline_queue_store.dart';
import 'services/telemetry_sync_client.dart';
import 'screens/tracking_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SqfliteTelemetryStore();
  final transport = SimulatedTelemetryTransport();

  runApp(FleetTelemetryApp(store: store, transport: transport));
}

class FleetTelemetryApp extends StatelessWidget {
  final TelemetryQueueStore store;
  final TelemetryTransport transport;
  final bool enableMapTiles;

  const FleetTelemetryApp({
    super.key,
    required this.store,
    required this.transport,
    this.enableMapTiles = true,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TrackingProvider(store: store, transport: transport)..loadInitialState(),
      child: MaterialApp(
        title: 'Fleet Telemetry Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: TrackingDashboardScreen(enableMapTiles: enableMapTiles),
      ),
    );
  }
}
