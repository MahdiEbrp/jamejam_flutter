/// greeter — see doc/greeter.md and AGENTS.md
import 'package:flutter/foundation.dart';

import '../settings/setting_keys.dart';
import '../settings/settings_controller.dart';
import '../soroush/ai_funnel.dart';
import '../soroush/soroush_options.dart';
import 'ai_greeter.dart';
import 'greeter.dart';

class GreeterController extends ChangeNotifier {
  GreeterController({
    required SettingsController settings,
    required AiFunnel funnel,
    AiGreeter? aiGreeter,
  }) : _settings = settings,
       _funnel = funnel,
       _aiGreeter = aiGreeter ?? AiGreeter();

  final SettingsController _settings;
  final AiFunnel _funnel;
  final AiGreeter _aiGreeter;

  String _greeting = '';
  bool _busy = false;
  String? _error;
  bool _lastWasAi = false;

  /// The greeting currently on screen (local or AI-crafted).
  String get greeting => _greeting;

  /// True while the AI call is in flight.
  bool get busy => _busy;

  /// The last error message, or null.
  String? get error => _error;

  /// True when the on-screen greeting came from the model.
  bool get lastWasAi => _lastWasAi;

  /// The default name stored in settings, if any.
  String get defaultName =>
      _settings.value(SettingKeys.greeterDefaultName) ?? '';

  /// Produces the local greeting — no network, no key, instant.
  String greetLocally(String? name) {
    final effective = (name == null || name.trim().isEmpty)
        ? defaultName
        : name;
    _error = null;
    _lastWasAi = false;
    _greeting = Greeter.getGreeting(effective);
    notifyListeners();
    return _greeting;
  }

  /// Asks Soroush for a time-aware greeting.
  ///
  /// Needs a usable key (or a loopback endpoint); otherwise the error explains exactly
  /// what to do, instead of failing with a raw HTTP status.
  Future<String> greetWithAi(String? name) async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      if (!await _funnel.hasUsableKey()) {
        throw const SoroushException(
          'The AI greeting needs an API key — add one in Soroush AI.',
        );
      }

      final effective = (name == null || name.trim().isEmpty)
          ? defaultName
          : name;
      final prompt = _aiGreeter.buildPrompt(effective, DateTime.now());
      final response = await _funnel.completeText(prompt);

      _lastWasAi = true;
      return _greeting = _aiGreeter.parseGreeting(response);
    } on SoroushException catch (error) {
      _error = error.message;
    } on ArgumentError catch (error) {
      _error = error.message?.toString() ?? 'The AI reply was unusable.';
    } catch (error) {
      _error = '$error';
    } finally {
      _busy = false;
      notifyListeners();
    }

    return _greeting;
  }

  /// Saves the default name used when the field is left empty.
  Future<String?> saveDefaultName(String name) =>
      _settings.set(SettingKeys.greeterDefaultName, name.trim());
}
