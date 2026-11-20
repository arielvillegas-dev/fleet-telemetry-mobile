class TelemetryPoint {
  final String clientEventId;
  final String tripId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedKmh;
  final double heading;
  final DateTime recordedAt;
  final String syncStatus; // 'pending' | 'synced'

  const TelemetryPoint({
    required this.clientEventId,
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedKmh,
    required this.heading,
    required this.recordedAt,
    this.syncStatus = 'pending',
  });

  TelemetryPoint copyWith({String? syncStatus}) {
    return TelemetryPoint(
      clientEventId: clientEventId,
      tripId: tripId,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      speedKmh: speedKmh,
      heading: heading,
      recordedAt: recordedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toApiJson() => {
        'client_event_id': clientEventId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
        'speed_kmh': speedKmh,
        'heading': heading,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toDbMap() => {
        'client_event_id': clientEventId,
        'trip_id': tripId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
        'speed_kmh': speedKmh,
        'heading': heading,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory TelemetryPoint.fromDbMap(Map<String, dynamic> map) => TelemetryPoint(
        clientEventId: map['client_event_id'] as String,
        tripId: map['trip_id'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracyMeters: (map['accuracy_meters'] as num).toDouble(),
        speedKmh: (map['speed_kmh'] as num).toDouble(),
        heading: (map['heading'] as num).toDouble(),
        recordedAt: DateTime.parse(map['recorded_at'] as String).toUtc(),
        syncStatus: map['sync_status'] as String,
      );
}
