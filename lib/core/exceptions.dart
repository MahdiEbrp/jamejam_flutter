/// The exception hierarchy shared by every JameJam service.
///
/// One base type means the UI can catch a single thing and still tell the user which
/// service failed. Messages are always safe to show: secrets are redacted at the seam
/// where they could otherwise leak (see `SoroushGuard.redact`).
library;

/// Base class for every failure a JameJam service reports to the UI.
class JameJamException implements Exception {
  const JameJamException(this.message, {this.service, this.cause});

  /// Safe, human-readable description of the failure.
  final String message;

  /// Which service raised it (e.g. `soroush`, `haftkhan`).
  final String? service;

  /// The underlying error, when there was one.
  final Object? cause;

  @override
  String toString() =>
      service == null ? 'JameJamException: $message' : '[$service] $message';
}

/// Thrown when a guard rejects input before it reaches a store or a network call.
class JameJamValidationException extends JameJamException {
  const JameJamValidationException(super.message, {super.service, super.cause});
}

/// Thrown when storage (SQLite, secure storage, files) fails.
class JameJamStorageException extends JameJamException {
  const JameJamStorageException(super.message, {super.service, super.cause});
}

/// Thrown when a network call fails after retries are exhausted.
class JameJamNetworkException extends JameJamException {
  const JameJamNetworkException(
    super.message, {
    this.statusCode,
    super.service,
    super.cause,
  });

  /// HTTP status code, when the failure came from a response.
  final int? statusCode;
}

/// Thrown when a feature is not available on the current platform or configuration.
class JameJamUnsupportedException extends JameJamException {
  const JameJamUnsupportedException(
    super.message, {
    super.service,
    super.cause,
  });
}
