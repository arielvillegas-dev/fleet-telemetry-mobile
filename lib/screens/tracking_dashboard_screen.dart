import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_point.dart';
import '../providers/tracking_provider.dart';

class TrackingDashboardScreen extends StatefulWidget {
  final bool enableMapTiles;

  const TrackingDashboardScreen({
    super.key,
    this.enableMapTiles = true,
  });

  @override
  State<TrackingDashboardScreen> createState() => _TrackingDashboardScreenState();
}

class _TrackingDashboardScreenState extends State<TrackingDashboardScreen> {
  int _step = 0;

  static const _syntheticRoute = <LatLng>[
    LatLng(13.6929, -89.2182),
    LatLng(13.6952, -89.2141),
    LatLng(13.6980, -89.2104),
    LatLng(13.7011, -89.2060),
    LatLng(13.7042, -89.2015),
  ];

  Future<void> _emitValidFix(TrackingProvider provider) async {
    final coord = _syntheticRoute[_step % _syntheticRoute.length];
    _step++;
    final point = TelemetryPoint(
      clientEventId: 'evt-$_step-${DateTime.now().microsecondsSinceEpoch}',
      tripId: provider.tripId,
      latitude: coord.latitude,
      longitude: coord.longitude,
      accuracyMeters: 8.5,
      speedKmh: 38.0,
      heading: 65.0,
      recordedAt: DateTime.now().toUtc(),
    );
    await provider.recordPoint(point);
  }

  Future<void> _emitNoisyFix(TrackingProvider provider) async {
    final point = TelemetryPoint(
      clientEventId: 'evt-bad-${DateTime.now().microsecondsSinceEpoch}',
      tripId: provider.tripId,
      latitude: 13.6929,
      longitude: -89.2182,
      accuracyMeters: 140.0,
      speedKmh: 12.0,
      heading: 0.0,
      recordedAt: DateTime.now().toUtc(),
    );
    await provider.recordPoint(point);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackingProvider>();
    final points = provider.acceptedPoints;
    final center = points.isNotEmpty
        ? LatLng(points.last.latitude, points.last.longitude)
        : _syntheticRoute.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Telemetry Offline Demo'),
        actions: [
          Row(
            children: [
              const Text('Offline', style: TextStyle(fontSize: 12)),
              Switch(
                value: provider.offlineSimulated,
                onChanged: provider.toggleOfflineSimulation,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: widget.enableMapTiles
                ? FlutterMap(
                    options: MapOptions(initialCenter: center, initialZoom: 14),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'dev.carlosvillegas.demo.fleet_telemetry_mobile',
                      ),
                      if (points.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                              strokeWidth: 4,
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                      if (points.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: center,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.directions_bus, color: Colors.indigo, size: 30),
                            ),
                          ],
                        ),
                    ],
                  )
                : Center(
                    child: Text(
                      'Map preview (${points.length} queued points)',
                      key: const Key('map-placeholder'),
                    ),
                  ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _MetricChip(label: 'Queued', value: '${provider.pendingCount}'),
                      _MetricChip(label: 'Accepted', value: '${points.length}'),
                      _MetricChip(label: 'Rejected', value: '${provider.rejectedCount}'),
                      _MetricChip(
                        label: 'Distance',
                        value: '${provider.distanceKm.toStringAsFixed(2)} km',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.statusMessage,
                    key: const Key('status-message'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _emitValidFix(provider),
                          icon: const Icon(Icons.gps_fixed),
                          label: const Text('Valid GPS'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _emitNoisyFix(provider),
                          icon: const Icon(Icons.gps_off),
                          label: const Text('Noisy GPS'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: provider.isSyncing ? null : provider.syncPendingBatch,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sync Batch'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
