/// soroush — see doc/soroush.md and AGENTS.md
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'soroush_guard.dart';
import 'soroush_options.dart';

abstract interface class SoroushProvider {
  /// Canonical provider name (e.g. `openai`, `anthropic`).
  String get name;

  /// Endpoint used when the user did not override it.
  String get defaultEndpoint;

  /// Model used when the user did not override it.
  String get defaultModel;

  /// Builds the HTTP request for one chat completion.
  ///
  /// [prompt] is already sanitized by the guard.
  http.Request buildRequest({
    required SoroushOptions options,
    required String endpoint,
    required String prompt,
  });

  /// Extracts the completion text from a successful JSON response body.
  String parseResponse(String json);
}

class OpenAICompatibleProvider implements SoroushProvider {
  const OpenAICompatibleProvider();

  @override
  String get name => SoroushProviders.openAiCompatible;

  @override
  String get defaultEndpoint => SoroushDefaults.openAiCompatibleEndpoint;

  @override
  String get defaultModel => SoroushDefaults.openAiCompatibleModel;

  @override
  http.Request buildRequest({
    required SoroushOptions options,
    required String endpoint,
    required String prompt,
  }) {
    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers['content-type'] = 'application/json';

    final apiKey = options.apiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $apiKey';
    }

    request.body = jsonEncode({
      'model': options.model ?? defaultModel,
      'max_tokens': options.maxTokens,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });
    return request;
  }

  @override
  String parseResponse(String json) {
    try {
      final decoded = jsonDecode(json);
      final choices = (decoded as Map)['choices'] as List;
      final message = (choices.first as Map)['message'] as Map;
      return SoroushGuard.validateResponse(message['content'] as String?);
    } catch (error) {
      if (error is SoroushException) rethrow;
      throw SoroushException(
        'The AI provider returned an unexpected OpenAI-compatible response shape.',
        cause: error,
      );
    }
  }
}

class AnthropicProvider implements SoroushProvider {
  const AnthropicProvider({this.apiVersion = defaultApiVersion});

  /// API version sent when no override is configured.
  static const String defaultApiVersion = '2023-06-01';

  /// Value of the `anthropic-version` header.
  final String apiVersion;

  /// Validates the configured API version.
  ///
  /// The C# provider throws from its constructor; Dart's const constructors cannot throw,
  /// so the same contract is enforced here and called from [buildRequest] — a blank version
  /// must never reach the wire as an empty header.
  void validate() {
    if (apiVersion.trim().isEmpty) {
      throw ArgumentError.value(
        apiVersion,
        'apiVersion',
        'API version must not be empty',
      );
    }
  }

  @override
  String get name => SoroushProviders.anthropic;

  @override
  String get defaultEndpoint => SoroushDefaults.anthropicEndpoint;

  @override
  String get defaultModel => SoroushDefaults.anthropicModel;

  @override
  http.Request buildRequest({
    required SoroushOptions options,
    required String endpoint,
    required String prompt,
  }) {
    validate();

    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers['content-type'] = 'application/json'
      ..headers['anthropic-version'] = apiVersion;

    final apiKey = options.apiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      request.headers['x-api-key'] = apiKey;
    }

    request.body = jsonEncode({
      'model': options.model ?? defaultModel,
      'max_tokens': options.maxTokens,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });
    return request;
  }

  @override
  String parseResponse(String json) {
    try {
      final decoded = jsonDecode(json) as Map;
      for (final block in (decoded['content'] as List)) {
        final text = (block as Map)['text'];
        if (text is String) return SoroushGuard.validateResponse(text);
      }
      throw const SoroushException(
        'The Anthropic response contained no text blocks.',
      );
    } catch (error) {
      if (error is SoroushException) rethrow;
      throw SoroushException(
        'The AI provider returned an unexpected Anthropic response shape.',
        cause: error,
      );
    }
  }
}

abstract final class SoroushProviders {
  /// Canonical name of the OpenAI-compatible provider.
  static const String openAiCompatible =
      SoroushDefaults.openAiCompatibleProviderName;

  /// Canonical name of the Anthropic provider.
  static const String anthropic = SoroushDefaults.anthropicProviderName;

  static final Map<String, SoroushProvider> _known = _createKnown();

  /// All known provider names (canonical + aliases), sorted for display.
  static List<String> get names {
    final all = _known.keys.toList()..sort();
    return List.unmodifiable(all);
  }

  /// The canonical names only — what the settings dropdown offers.
  static const List<String> canonical = [openAiCompatible, anthropic];

  /// Resolves a provider name (case-insensitive, alias-aware). Blank defaults to
  /// OpenAI-compatible.
  static SoroushProvider resolve(String? name) {
    if (name == null || name.trim().isEmpty) return _known[openAiCompatible]!;
    final trimmed = name.trim().toLowerCase();
    final provider = _known[trimmed];
    if (provider != null) return provider;

    throw SoroushException(
      "Unknown AI provider '$name'. Known: ${_known.keys.join(', ')}.",
    );
  }

  static Map<String, SoroushProvider> _createKnown() {
    const openAi = OpenAICompatibleProvider();
    const anthropicProvider = AnthropicProvider();

    return <String, SoroushProvider>{
      // Canonical
      openAiCompatible: openAi,
      anthropic: anthropicProvider,

      // OpenAI-compatible aliases (they all speak the same wire format)
      'openai-compatible': openAi,
      'azure': openAi,
      'groq': openAi,
      'deepseek': openAi,
      'mistral': openAi,
      'openrouter': openAi,
      'together': openAi,
      'xai': openAi,
      'ollama': openAi,
      'lmstudio': openAi,

      // Anthropic aliases
      'claude': anthropicProvider,
    };
  }
}
