/// soroush — see doc/soroush.md and AGENTS.md
import '../../core/text_guard.dart';
import 'soroush_options.dart';

abstract final class SoroushGuard {
  /// Strips control characters, trims, and enforces the maximum prompt length.
  ///
  /// Throws [ArgumentError] for empty input and [SoroushException] when the sanitized
  /// prompt is longer than [maxLength] (a prompt is a payload, not a user field —
  /// truncating it silently would change what the model answers).
  static String sanitizePrompt(
    String? prompt, [
    int maxLength = SoroushLimits.defaultMaxPromptLength,
  ]) {
    if (prompt == null || prompt.trim().isEmpty) {
      throw ArgumentError.value(prompt, 'prompt', 'Prompt must not be empty');
    }
    if (maxLength < 1) {
      throw ArgumentError.value(maxLength, 'maxLength', 'Must be at least 1');
    }

    final trimmed = prompt.trim();

    // Slow path only when there is actually a control character to drop: one pass keeps
    // formatting whitespace (\n, \t) and drops the rest.
    final sanitized = TextGuard.hasControlChars(trimmed)
        ? TextGuard.clip(trimmed, trimmed.length)
        : trimmed;

    if (sanitized.isEmpty) {
      throw ArgumentError.value(
        prompt,
        'prompt',
        'Prompt contains no readable characters',
      );
    }
    if (sanitized.length > maxLength) {
      throw SoroushException(
        'Prompt exceeds the maximum length of $maxLength characters.',
      );
    }
    return sanitized;
  }

  /// Validates an AI endpoint.
  ///
  /// HTTPS is always allowed; plain HTTP only on loopback, so local models via
  /// Ollama/LM Studio keep working without weakening cloud calls.
  static Uri validateEndpoint(String? endpoint) {
    final uri = endpoint == null ? null : Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw SoroushException("Invalid AI endpoint '$endpoint'.");
    }

    final secureEnough =
        uri.scheme == 'https' || (uri.scheme == 'http' && isLoopback(uri));
    if (!secureEnough) {
      throw SoroushException(
        "Insecure AI endpoint '$endpoint'. Use HTTPS (plain HTTP is only allowed on loopback).",
      );
    }
    return uri;
  }

  /// True for `localhost`, `127.0.0.0/8`, and `::1` — the .NET `Uri.IsLoopback` equivalent.
  static bool isLoopback(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '::1') return true;
    if (host.startsWith('127.')) return true;
    return false;
  }

  /// Fast-fail validation of a full options object, called before every client run.
  static void validateOptions(SoroushOptions options) {
    if (options.maxTokens < 1 ||
        options.maxTokens > SoroushLimits.maxTokensBound) {
      throw SoroushException(
        'MaxTokens must be between 1 and ${SoroushLimits.maxTokensBound}.',
      );
    }
    if (options.requestTimeout <= Duration.zero ||
        options.requestTimeout > SoroushLimits.requestTimeoutBound) {
      throw SoroushException(
        'RequestTimeout must be positive and at most '
        '${SoroushLimits.requestTimeoutBound.inMinutes} minutes.',
      );
    }
    if (options.maxRetries < 0 ||
        options.maxRetries > SoroushLimits.maxRetriesBound) {
      throw SoroushException(
        'MaxRetries must be between 0 and ${SoroushLimits.maxRetriesBound}.',
      );
    }
    if (options.retryBaseDelay < Duration.zero) {
      throw const SoroushException('RetryBaseDelay must not be negative.');
    }
    if (options.maxPromptLength < 1) {
      throw const SoroushException('MaxPromptLength must be at least 1.');
    }
    if (options.maxErrorBodyLength < SoroushLimits.minErrorBodyLength ||
        options.maxErrorBodyLength > SoroushLimits.maxErrorBodyLengthBound) {
      throw SoroushException(
        'MaxErrorBodyLength must be between ${SoroushLimits.minErrorBodyLength} '
        'and ${SoroushLimits.maxErrorBodyLengthBound}.',
      );
    }
    if (options.jitterScale < 0 || options.jitterScale > 1) {
      throw const SoroushException(
        'JitterScale must be between 0 (deterministic) and 1 (fully jittered).',
      );
    }
    if (options.endpoint != null) {
      validateEndpoint(options.endpoint);
    }
  }

  /// Validates a non-empty completion coming back from a provider.
  static String validateResponse(String? content) {
    if (content == null || content.trim().isEmpty) {
      throw const SoroushException('AI provider returned an empty completion.');
    }
    return content.trim();
  }

  /// Masks a secret so it can safely appear in logs or error messages.
  static String redact(
    String? secret, [
    int suffixLength = SoroushLimits.redactDefaultSuffixLength,
  ]) {
    _validateSuffixLength(suffixLength);

    if (secret == null || secret.trim().isEmpty) return '(none)';

    final visible = secret.length <= suffixLength
        ? ''
        : secret.substring(secret.length - suffixLength);
    return '****$visible';
  }

  /// Redacts [secret] wherever it appears inside [text] — used on provider error bodies.
  static String redactIn(
    String text,
    String? secret, [
    int suffixLength = SoroushLimits.redactDefaultSuffixLength,
  ]) {
    if (secret == null || secret.isEmpty || text.isEmpty) return text;
    if (!text.contains(secret)) return text;
    return text.replaceAll(secret, redact(secret, suffixLength));
  }

  static void _validateSuffixLength(int suffixLength) {
    if (suffixLength < 0 ||
        suffixLength > SoroushLimits.redactSuffixLengthBound) {
      throw RangeError.range(
        suffixLength,
        0,
        SoroushLimits.redactSuffixLengthBound,
        'suffixLength',
      );
    }
  }
}
