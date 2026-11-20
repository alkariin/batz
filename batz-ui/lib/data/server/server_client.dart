import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../sync/sync_engine.dart';
import '../sync/sync_protocol.dart';
import 'certificate.dart';

/// Default HTTPS port of batz-web.
const defaultServerPort = 8443;

final _host = RegExp(
  r'^(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*$|^[0-9a-fA-F:]+$',
);

/// Turns what the user typed (`192.168.1.95`, `192.168.1.95:8443`,
/// `https://nas.local:9443/`) into the base URL of the server, or null.
Uri? parseServerAddress(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || !_host.hasMatch(uri.host)) return null;
  if ((uri.path.isNotEmpty && uri.path != '/') || uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
    return null;
  }
  return Uri(scheme: 'https', host: uri.host, port: uri.hasPort ? uri.port : defaultServerPort);
}

/// A failure reported by the server, with its machine-readable code.
class ServerException implements Exception {
  ServerException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => 'ServerException($status $code): $message';
}

/// The server could not be reached (off, wrong address, other network).
class ServerUnreachableException implements Exception {
  ServerUnreachableException(this.cause);
  final Object cause;

  @override
  String toString() => 'ServerUnreachableException: $cause';
}

class Health {
  Health({required this.version, required this.minAppVersion, this.syncProtocol});
  final String version;
  final String minAppVersion;

  /// The exchange protocol the server speaks; null for a server older than
  /// the synchronisation (before 0.3.0).
  final int? syncProtocol;
}

class PairingResult {
  PairingResult({required this.deviceId, required this.deviceKey});
  final String deviceId;
  final String deviceKey;
}

class ServerDevice {
  ServerDevice({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastSeenAt,
    required this.revokedAt,
    required this.current,
  });

  factory ServerDevice.fromJson(Map<String, dynamic> json) => ServerDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastSeenAt: json['lastSeenAt'] == null ? null : DateTime.parse(json['lastSeenAt'] as String),
    revokedAt: json['revokedAt'] == null ? null : DateTime.parse(json['revokedAt'] as String),
    current: json['current'] as bool,
  );

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;
  final bool current;

  bool get revoked => revokedAt != null;
}

/// Thin HTTP client of the batz-web API (batz-web/docs/api.md).
class ServerClient implements SyncTransport {
  /// [pin] is the certificate fingerprint to require; without it the first
  /// certificate seen is accepted and reported to [onCertificate].
  ServerClient(this.baseUrl, {this.pin, this.onCertificate, String? deviceKey})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl.toString(),
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 15),
          headers: {if (deviceKey != null) 'Authorization': 'Bearer $deviceKey'},
          // Errors are mapped below from the JSON body.
          validateStatus: (_) => true,
        ),
      ) {
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => pinnedHttpClient(pin: pin, seen: (f) => _lastFingerprint = f),
    );
  }

  final Uri baseUrl;
  final Dio _dio;
  final String? pin;
  final void Function(String)? onCertificate;
  String? _lastFingerprint;

  void close() => _dio.close(force: true);

  @override
  Future<Health> health() async {
    final body = await _send('GET', '/healthz') as Map<String, dynamic>;
    return Health(
      version: body['version'] as String,
      minAppVersion: body['minAppVersion'] as String,
      syncProtocol: body['syncProtocol'] as int?,
    );
  }

  /// One call of an exchange (`POST /api/v1/sync`).
  @override
  Future<SyncResponse> exchange(SyncRequest request) async {
    final body = await _send('POST', '/api/v1/sync', data: request.toJson(), timeout: const Duration(seconds: 60));
    return SyncResponse.fromJson(body);
  }

  Future<PairingResult> pair({required String code, required String name}) async {
    final body = await _send('POST', '/api/v1/pairing', data: {'code': code, 'name': name}) as Map<String, dynamic>;
    return PairingResult(deviceId: body['deviceId'] as String, deviceKey: body['deviceKey'] as String);
  }

  Future<List<ServerDevice>> devices() async {
    final body = await _send('GET', '/api/v1/devices') as Map<String, dynamic>;
    return [for (final d in body['devices'] as List<dynamic>) ServerDevice.fromJson(d as Map<String, dynamic>)];
  }

  Future<void> revoke(String deviceId) async {
    await _send('DELETE', '/api/v1/devices/${Uri.encodeComponent(deviceId)}');
  }

  Future<Object?> _send(String method, String path, {Object? data, Duration? timeout}) async {
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        path,
        data: data,
        options: Options(method: method, receiveTimeout: timeout, sendTimeout: timeout),
      );
    } on DioException catch (e) {
      final seen = _lastFingerprint;
      if (pin case final expected? when seen != null && seen != expected) {
        throw CertificateMismatchException(expected, seen);
      }
      throw ServerUnreachableException(e.error ?? e);
    }
    if (pin == null && _lastFingerprint != null) onCertificate?.call(_lastFingerprint!);
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return response.data;
    final body = response.data;
    if (body is Map<String, dynamic>) {
      throw ServerException(status, body['code'] as String? ?? 'UNKNOWN', body['message'] as String? ?? '');
    }
    throw ServerException(status, 'UNKNOWN', 'HTTP $status');
  }
}

/// Whether [error] means the server cannot be reached at all.
bool isNetworkError(Object error) => error is ServerUnreachableException || error is SocketException;
