/// soroush — see doc/soroush.md and AGENTS.md
import 'package:flutter/foundation.dart';

import 'ai_funnel.dart';
import 'soroush_client.dart';
import 'soroush_options.dart';

class AiCallRecord {
  AiCallRecord({required this.prompt, required this.at});

  /// The prompt that was sent (already sanitized).
  final String prompt;

  /// When the call started.
  final DateTime at;

  /// The completion, when it succeeded.
  SoroushResult? result;

  /// The failure message, when it failed.
  String? error;

  bool get isSuccess => result != null;
}

class SoroushController extends ChangeNotifier {
  SoroushController(this.funnel);

  /// The one AI path in the app.
  final AiFunnel funnel;

  final List<AiCallRecord> _history = <AiCallRecord>[];
  bool _sending = false;
  String? _apiKeyMasked;
  bool _hasKey = false;

  /// Most recent calls first.
  List<AiCallRecord> get history => List.unmodifiable(_history);

  /// True while a call is in flight.
  bool get isSending => _sending;

  /// Masked API key, e.g. `****abcd`, or `(none)`.
  String get apiKeyMasked => _apiKeyMasked ?? '(none)';

  /// True when a key is configured (or the endpoint needs none).
  bool get hasKey => _hasKey;

  /// Re-reads the key state so the header reflects it after a save.
  Future<void> refreshKeyState() async {
    _apiKeyMasked = await funnel.maskedApiKey();
    _hasKey = await funnel.hasUsableKey();
    notifyListeners();
  }

  /// Sends [prompt] and records the outcome. Returns the record for the UI to render.
  Future<AiCallRecord> send(String prompt) async {
    final record = AiCallRecord(prompt: prompt.trim(), at: DateTime.now());
    _history.insert(0, record);
    _sending = true;
    notifyListeners();

    try {
      record.result = await funnel.complete(AiRequest(prompt: record.prompt));
    } on SoroushException catch (error) {
      record.error = error.message;
    } on ArgumentError catch (error) {
      record.error = error.message?.toString() ?? 'Invalid prompt.';
    } catch (error) {
      record.error = '$error';
    } finally {
      _sending = false;
      notifyListeners();
    }

    return record;
  }

  /// Saves the API key to the keychain and refreshes the header state.
  Future<String?> saveApiKey(String apiKey) async {
    try {
      await funnel.saveApiKey(apiKey);
      await refreshKeyState();
      return null;
    } catch (error) {
      return '$error';
    }
  }

  /// Removes the stored API key.
  Future<void> clearApiKey() async {
    await funnel.clearApiKey();
    await refreshKeyState();
  }

  /// Clears the session history (prompts are not written to disk, so this is final).
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
}
