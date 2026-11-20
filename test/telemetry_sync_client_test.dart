import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fleet_telemetry_mobile/models/telemetry_point.dart';
import 'package:fleet_telemetry_mobile/services/telemetry_sync_client.dart';

void main() {
  test('HttpTelemetryTransport sends batch payload and parses accepted count', () async {
    String? capturedPath;
    String? capturedAuth;
    int sentPoints = 0;

    final mockClient = MockClient((request) async {
      capturedPath = request.url.path;
      capturedAuth = request.headers['Authorization'];
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      sentPoints = (decoded['points'] as List).length;
      return http.Response(jsonEncode({'accepted': sentPoints}), 200);
    });

    final transport = HttpTelemetryTransport(
      baseUrl: 'https://api.example.test',
      authToken: 'demo-token',
      client: mockClient,
    );

    final result = await transport.sendBatch(
      tripId: 'TRIP-42',
      points: [
        TelemetryPoint(
          clientEventId: 'evt-1',
          tripId: 'TRIP-42',
          latitude: 13.69,
          longitude: -89.21,
          accuracyMeters: 8.0,
          speedKmh: 25.0,
          heading: 10.0,
          recordedAt: DateTime.utc(2026, 11, 20, 12, 0),
        ),
      ],
    );

    expect(result.success, isTrue);
    expect(result.acknowledgedCount, 1);
    expect(capturedPath, '/api/v1/trips/TRIP-42/telemetry-batch');
    expect(capturedAuth, 'Bearer demo-token');
  });

  test('HttpTelemetryTransport handles 500 server failures gracefully', () async {
    final mockClient = MockClient((_) async => http.Response('Server Error', 500));
    final transport = HttpTelemetryTransport(
      baseUrl: 'https://api.example.test',
      authToken: '',
      client: mockClient,
    );

    final result = await transport.sendBatch(
      tripId: 'TRIP-42',
      points: [
        TelemetryPoint(
          clientEventId: 'evt-1',
          tripId: 'TRIP-42',
          latitude: 13.69,
          longitude: -89.21,
          accuracyMeters: 8.0,
          speedKmh: 25.0,
          heading: 10.0,
          recordedAt: DateTime.utc(2026, 11, 20, 12, 0),
        ),
      ],
    );

    expect(result.success, isFalse);
    expect(result.acknowledgedCount, 0);
  });
}
