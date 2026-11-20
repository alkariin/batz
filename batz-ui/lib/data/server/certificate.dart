import 'dart:io';

import 'package:crypto/crypto.dart';

/// SHA-256 of a DER certificate, as upper-case hex pairs separated by colons:
/// the form the server prints with `batz-web pairing-code`.
String fingerprintOf(List<int> der) =>
    sha256.convert(der).bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');

/// The server presented a certificate other than the one memorised at
/// pairing: the connection is refused before any request is sent.
class CertificateMismatchException implements Exception {
  CertificateMismatchException(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() => 'CertificateMismatchException: expected $expected, got $actual';
}

/// Creates the HttpClient used for the server.
///
/// The system roots are not trusted at all, so that every certificate goes
/// through [onCertificate], which accepts it or not. With a [pin], only the
/// certificate with that fingerprint is accepted. Without one (first contact
/// during pairing), the certificate is accepted and its fingerprint recorded
/// through [onCertificate] so it can be pinned.
HttpClient pinnedHttpClient({String? pin, void Function(String fingerprint)? seen}) {
  final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
    ..connectionTimeout = const Duration(seconds: 5);
  client.badCertificateCallback = (cert, host, port) {
    final actual = fingerprintOf(cert.der);
    seen?.call(actual);
    return pin == null || actual == pin;
  };
  return client;
}
