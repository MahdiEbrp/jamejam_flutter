/// soroush — see doc/soroush.md and AGENTS.md
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/secret_store.dart';
import '../settings/setting_keys.dart';
import '../settings/settings_controller.dart';
import 'soroush_client.dart';
import 'soroush_guard.dart';
import 'soroush_options.dart';
import 'soroush_registry.dart';

class AiFunnel {
  AiFunnel({
    required this.settings,
    required SecretStore secrets,
    http.Client? httpClient,
    Random? random,
  }) : _secrets = secrets,
       _http = httpClient ?? http.Client(),
       _random = random;

  /// The settings store this funnel reads provider/endpoint/model from.
  final SettingsController settings;

  final SecretStore _secrets;
  final http.Client _http;
  final Random? _random;

  /// Where the last resolved call went — shown in the UI so a wrong model is obvious.
  SoroushResult? lastResult;

  /// Resolves the effective options for a call.
  ///
  /// Nothing here reads the API key from a setting: keys live in the secret store only.
  Future<SoroushOptions> resolve({
    String? provider,
    String? model,
    String? endpoint,
    int? maxTokens,
    int? maxRetries,
  }) async {
    final providerName =
        _nonEmpty(provider) ??
        _nonEmpty(settings.value(SettingKeys.soroushProvider));
    final resolvedProvider = SoroushProviders.resolve(providerName);

    final resolvedEndpoint =
        _nonEmpty(endpoint) ??
        _nonEmpty(settings.value(SettingKeys.soroushEndpoint)) ??
        resolvedProvider.defaultEndpoint;

    final resolvedModel =
        _nonEmpty(model) ?? _nonEmpty(settings.value(SettingKeys.soroushModel));

    final apiKey = await readApiKey();

    return SoroushOptions(
      provider: resolvedProvider.name,
      endpoint: resolvedEndpoint,
      apiKey: apiKey,
      model: resolvedModel,
      maxTokens: maxTokens ?? SoroushLimits.defaultMaxTokens,
      maxRetries: maxRetries ?? SoroushLimits.defaultMaxRetries,
    );
  }

  /// Completes one prompt through the safety layer.
  ///
  /// The key gate lives **here**, not in each feature: the .NET's `CompleteAiRequestAsync`
  /// refused with `Missing API key. …` before anything left the process whenever the
  /// endpoint was not loopback, and a port that relies on the server answering 401 is a
  /// worse experience and one leaked request. Loopback endpoints may still omit a key.
  Future<SoroushResult> complete(AiRequest request) async {
    final options = await resolve(
      provider: request.provider,
      model: request.model,
      endpoint: request.endpoint,
    );

    final endpoint = Uri.tryParse(options.endpoint ?? '');
    final loopback = endpoint != null && SoroushGuard.isLoopback(endpoint);
    if (!loopback && (options.apiKey == null || options.apiKey!.isEmpty)) {
      throw SoroushException(
        'Missing API key. Set the ${SecretKeys.aiApiKeyEnv} '
        'environment variable (keys are never accepted on the command line for safety; '
        'loopback endpoints may omit it).',
      );
    }

    final client = HttpSoroushClient(
      httpClient: _http,
      options: options,
      random: _random,
    );
    final result = await client.complete(request.prompt);
    lastResult = result;
    return result;
  }

  /// Convenience for services that only need the string back.
  ///
  /// Every AI-using feature calls this — and only this.
  Future<String> completeText(
    String prompt, {
    String? provider,
    String? model,
  }) async {
    final result = await complete(
      AiRequest(prompt: prompt, provider: provider, model: model),
    );
    return result.content;
  }

  /// Reads the provider API key — the environment variable wins, then the keychain.
  Future<String?> readApiKey() async {
    final value = await _secrets.read(SecretKeys.aiApiKey);
    return _nonEmpty(value);
  }

  /// True when a key is available (or the endpoint is loopback and needs none).
  Future<bool> hasUsableKey() async {
    if (await readApiKey() != null) return true;
    try {
      final options = await resolve();
      final uri = Uri.tryParse(options.endpoint ?? '');
      return uri != null && SoroushGuard.isLoopback(uri);
    } on SoroushException {
      return false;
    }
  }

  /// Stores the API key in the platform keychain (never in the settings database).
  Future<void> saveApiKey(String apiKey) =>
      _secrets.write(SecretKeys.aiApiKey, apiKey.trim());

  /// Removes the stored API key.
  Future<void> clearApiKey() => _secrets.delete(SecretKeys.aiApiKey);

  /// A masked form of the key, safe to render on screen.
  Future<String> maskedApiKey() async =>
      SoroushGuard.redact(await readApiKey());

  /// Closes the underlying HTTP client.
  void dispose() => _http.close();

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
