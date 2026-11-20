import 'package:flutter/foundation.dart';
import '../models/telemetry_point.dart';
import '../services/gps_quality_filter.dart';
import '../services/offline_queue_store.dart';
import '../services/telemetry_sync_client.dart';

class TrackingProvider extends ChangeNotifier {
  final TelemetryQueueStore store;
  final TelemetryTransport transport;
  final String tripId;

  final List<TelemetryPoint> _acceptedPoints = [];
  int _pendingCount = 0;
  int _rejectedCount = 0;
  double _distanceKm = 0.0;
  String _statusMessage = 'Ready to record GPS telemetry';
  bool _isSyncing = false;
  bool _offlineSimulated = false;

  TrackingProvider({
    required this.store,
    required this.transport,
    this.tripId = 'TRIP-DEMO-01',
  });

  List<TelemetryPoint> get acceptedPoints => List.unmodifiable(_acceptedPoints);
  int get pendingCount => _pendingCount;
  int get rejectedCount => _rejectedCount;
  double get distanceKm => _distanceKm;
  String get statusMessage => _statusMessage;
  bool get isSyncing => _isSyncing;
  bool get offlineSimulated => _offlineSimulated;

  Future<void> loadInitialState() async {
    final existing = await store.getAllForTrip(tripId);
    _acceptedPoints
      ..clear()
      ..addAll(existing);
    _recomputeDistance();
    _pendingCount = await store.countPending();
    notifyListeners();
  }

  void toggleOfflineSimulation(bool value) {
    _offlineSimulated = value;
    if (transport is SimulatedTelemetryTransport) {
      (transport as SimulatedTelemetryTransport).simulateOffline = value;
    }
    _statusMessage = value
        ? 'Offline mode enabled: points will buffer locally'
        : 'Online mode restored';
    notifyListeners();
  }

  /// Validates incoming GPS point, stores it in the offline SQLite queue, and
  /// updates accumulated Haversine distance.
  Future<bool> recordPoint(TelemetryPoint candidate) async {
    final previous = _acceptedPoints.isNotEmpty ? _acceptedPoints.last : null;
    final evaluation = GpsQualityFilter.evaluate(
      candidate: candidate,
      previousAccepted: previous,
    );

    if (!evaluation.accepted) {
      _rejectedCount++;
      _statusMessage = 'Filtered: ${evaluation.reason}';
      notifyListeners();
      return false;
    }

    await store.enqueue(candidate);
    _acceptedPoints.add(candidate);
    _recomputeDistance();
    _pendingCount = await store.countPending();
    _statusMessage = 'Queued point (${candidate.accuracyMeters.toStringAsFixed(0)}m accuracy)';
    notifyListeners();
    return true;
  }

  Future<void> syncPendingBatch() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      final pending = await store.getPending(limit: 50);
      if (pending.isEmpty) {
        _statusMessage = 'Queue is empty — all points synced';
        return;
      }

      final result = await transport.sendBatch(tripId: tripId, points: pending);
      if (result.success) {
        await store.markSynced(pending.map((p) => p.clientEventId).toList());
        await loadInitialState();
        _statusMessage = result.message;
      } else {
        _statusMessage = result.message;
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _recomputeDistance() {
    double total = 0.0;
    for (var i = 1; i < _acceptedPoints.length; i++) {
      total += GpsQualityFilter.haversineKm(
        _acceptedPoints[i - 1].latitude,
        _acceptedPoints[i - 1].longitude,
        _acceptedPoints[i].latitude,
        _acceptedPoints[i].longitude,
      );
    }
    _distanceKm = total;
  }
}
