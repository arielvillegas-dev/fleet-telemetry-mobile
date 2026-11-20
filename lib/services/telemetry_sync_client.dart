import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/telemetry_point.dart';

class BatchSyncResult {
  final bool success;
  final int acknowledgedCount;
  final String message;

  const BatchSyncResult({
    required this.success,
    required this.acknowledgedCount,
    required this.message,
  });
}

abstract class TelemetryTransport {
  Future<BatchSyncResult> sendBatch({
    required String tripId,
    required List<TelemetryPoint> points,
  });
}

/// REST batch client with timeout protection and idempotent payload structure.
class HttpTelemetryTransport implements TelemetryTransport {
  final String baseUrl;
  final String authToken;
  final http.Client client;
  final Duration timeout;

  HttpTelemetryTransport({
    required this.baseUrl,
    required this.authToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : client = client ?? http.Client();

  @override
  Future<BatchSyncResult> sendBatch({
    required String tripId,
    required List<TelemetryPoint> points,
  }) async {
    if (points.isEmpty) {
      return const BatchSyncResult(
        success: true,
        acknowledgedCount: 0,
        message: 'Nothing to sync',
      );
    }

    final uri = Uri.parse('$baseUrl/api/v1/trips/$tripId/telemetry-batch');
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'points': points.map((p) => p.toApiJson()).toList(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final accepted = (decoded['accepted'] as num?)?.toInt() ?? points.length;
        return BatchSyncResult(
          success: true,
          acknowledgedCount: accepted,
          message: 'Synced $accepted points',
        );
      }

      return BatchSyncResult(
        success: false,
        acknowledgedCount: 0,
        message: 'Server returned HTTP ${response.statusCode}',
      );
    } on TimeoutException {
      return const BatchSyncResult(
        success: false,
        acknowledgedCount: 0,
        message: 'Network timeout while syncing telemetry batch',
      );
    } catch (e) {
      return BatchSyncResult(
        success: false,
        acknowledgedCount: 0,
        message: 'Network error: $e',
      );
    }
  }
}

/// Simulated transport used in offline/standalone UI demonstration mode.
class SimulatedTelemetryTransport implements TelemetryTransport {
  bool simulateOffline = false;

  @override
  Future<BatchSyncResult> sendBatch({
    required String tripId,
    required List<TelemetryPoint> points,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (simulateOffline) {
      return const BatchSyncResult(
        success: false,
        acknowledgedCount: 0,
        message: 'Simulated network offline (kept safely in SQLite queue)',
      );
    }
    return BatchSyncResult(
      success: true,
      acknowledgedCount: points.length,
      message: 'Synced ${points.length} points to sandbox API',
    );
  }
}
