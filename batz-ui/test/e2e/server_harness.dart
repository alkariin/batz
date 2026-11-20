import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs the real batz-web server for end-to-end tests.
///
/// The binary comes from BATZ_SERVER_BIN when set (CI builds it once);
/// otherwise it is built from ../batz-web/src with the Go toolchain on PATH.
class LocalServer {
  LocalServer._(this.dataDir, this.port, this._process, this._logs);

  static String? _binary;

  static Future<String> binary() async {
    if (_binary != null) return _binary!;
    final fromEnv = Platform.environment['BATZ_SERVER_BIN'];
    if (fromEnv != null && fromEnv.isNotEmpty) return _binary = fromEnv;
    final out = '${Directory.systemTemp.createTempSync('batz-server').path}/batz-web';
    final ProcessResult build;
    try {
      build = await Process.run('go', [
        'build',
        '-ldflags',
        '-X github.com/alkariin/batz/batz-web/internal/version.Version=v0.1.0-e2e',
        '-o',
        out,
        '.',
      ], workingDirectory: '../batz-web/src');
    } on ProcessException catch (e) {
      throw StateError('End-to-end tests need the server: set BATZ_SERVER_BIN or put Go on PATH ($e)');
    }
    if (build.exitCode != 0) throw StateError('Building batz-web failed:\n${build.stderr}');
    return _binary = out;
  }

  static Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  /// Starts a server on [dataDir] (a new one by default) and a free port.
  ///
  /// Test files run concurrently and each starts servers: a port found free
  /// can be taken by another server before this one binds it. The server is
  /// thus considered started only once its own process reports that it
  /// listens; if it could not bind, another port is tried.
  static Future<LocalServer> start({Directory? dataDir}) async {
    final dir = dataDir ?? Directory.systemTemp.createTempSync('batz-e2e');
    for (var attempt = 1; ; attempt++) {
      final port = await _freePort();
      final process = await Process.start(await binary(), ['serve'], environment: _env(dir, port));
      final logs = StringBuffer();
      process.stdout.transform(utf8.decoder).listen(logs.write);
      process.stderr.transform(utf8.decoder).listen(logs.write);
      final server = LocalServer._(dir, port, process, logs);
      if (await server._waitUntilListening()) return server;
      if (attempt == 5) throw StateError('batz-web did not start:\n$logs');
    }
  }

  static Map<String, String> _env(Directory dir, int port) => {
    ...Platform.environment,
    'BATZ_DATA_DIR': dir.path,
    'BATZ_PORT': '$port',
  };

  final Directory dataDir;
  final int port;
  final Process _process;
  final StringBuffer _logs;

  Uri get address => Uri(scheme: 'https', host: '127.0.0.1', port: port);

  String get logs => _logs.toString();

  /// True once this process listens; false if it exited first (port taken).
  Future<bool> _waitUntilListening() async {
    var exited = false;
    unawaited(_process.exitCode.then((_) => exited = true));
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (logs.contains('batz-web started')) return true;
      if (exited) return false;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('batz-web did not start:\n$logs');
  }

  /// Runs `batz-web pairing-code` and returns the code and the fingerprint
  /// it prints.
  Future<({String code, String fingerprint})> pairingCode({String? ttl}) async {
    final result = await Process.run(await binary(), [
      'pairing-code',
      if (ttl != null) ...['-ttl', ttl],
    ], environment: _env(dataDir, port));
    if (result.exitCode != 0) throw StateError('pairing-code failed: ${result.stderr}');
    final out = result.stdout as String;
    final code = RegExp(r'Pairing code: (\S+)').firstMatch(out)!.group(1)!;
    final fingerprint = RegExp(r'((?:[0-9A-F]{2}:){31}[0-9A-F]{2})').firstMatch(out)!.group(1)!;
    return (code: code, fingerprint: fingerprint);
  }

  Future<void> stop() async {
    _process.kill(ProcessSignal.sigterm);
    await _process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}
