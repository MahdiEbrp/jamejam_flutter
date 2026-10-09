/// anahita — see doc/anahita.md and AGENTS.md
library;

import 'package:flutter/foundation.dart';

import '../haftkhan/models.dart' as haftkhan;
import '../haftkhan/task_repository.dart';
import '../settings/settings_controller.dart';
import '../soroush/ai_funnel.dart';
import 'anahita_defaults.dart';
import 'anahita_format.dart';
import 'anahita_insights.dart';
import 'anahita_service.dart';
import 'models.dart';
import 'weather_assistant.dart';

enum WeatherTab {
  /// Conditions right now (the CLI's default command).
  now,

  /// Day-by-day outlook.
  forecast,

  /// Hour-by-hour detail.
  hourly,

  /// Heat, frost, wind, rain, storm, UV warnings.
  alerts,

  /// Ranked upcoming days for outdoor plans.
  best,

  /// Open tasks matched to the forecast by their due day.
  plan,
}

class WeatherController extends ChangeNotifier {
  /// Wires the service, the settings (units + saved location), the AI funnel, and the tasks.
  WeatherController({
    required AnahitaService service,
    required SettingsController settings,
    required AiFunnel funnel,
    required TaskRepository taskRepository,
    WeatherAssistant? assistant,
    DateTime Function()? clock,
  }) : _service = service,
       _settings = settings,
       _funnel = funnel,
       _tasks = taskRepository,
       _assistant = assistant ?? WeatherAssistant(service.options),
       _clock = clock ?? DateTime.now;

  final AnahitaService _service;
  final SettingsController _settings;
  final AiFunnel _funnel;
  final TaskRepository _tasks;
  final WeatherAssistant _assistant;
  final DateTime Function() _clock;

  WeatherTab _tab = WeatherTab.now;
  WeatherUnits _units = WeatherUnits.metric;
  String? _reportLocation;
  WeatherReport? _report;
  bool _busy = false;
  bool _loaded = false;
  String? _error;

  /// The view currently selected.
  WeatherTab get tab => _tab;

  /// Metric or imperial — the setting the CLI's `--units` flag overrode.
  WeatherUnits get units => _units;

  /// What the user typed into the location box (or the saved location when untouched).
  ///
  /// Mutable on purpose: the text field writes it while the user types, and nothing else in
  /// the controller needs to observe that.
  String locationInput = '';

  /// The location the current report belongs to.
  String? get reportLocation => _reportLocation;

  /// The last downloaded report, or null before the first successful fetch.
  WeatherReport? get report => _report;

  /// True while a fetch is in flight.
  bool get busy => _busy;

  /// True once a fetch has been attempted (so the screen can show its empty state).
  bool get loaded => _loaded;

  /// The last failure, already redacted by the transport.
  String? get error => _error;

  /// Alerts derived from the current report (empty when there is nothing to warn about).
  List<WeatherAlert> get alerts =>
      _report == null ? const [] : AnahitaInsights.findAlerts(_report!, _units);

  /// The best upcoming days for outdoor plans.
  List<DayAdvice> get bestDays => _report == null
      ? const []
      : AnahitaInsights.rankDays(
          _report!,
          _units,
          AnahitaDefaults.bestDayCount,
        );

  /// The hourly slice the hourly view shows.
  List<HourlyPoint> get hours => _report == null
      ? const []
      : _report!.hourly.take(_service.options.hourlyWindow).toList();

  /// The service underneath — exposed so the screen can read its options in diagnostics.
  AnahitaService get service => _service;

  /// The prompt builder the AI buttons use.
  WeatherAssistant get assistant => _assistant;

  /// Loads the saved location and units, then fetches the first report.
  Future<void> initialise() async {
    _units = WeatherUnits.parse(
      await _settings.read(AnahitaDefaults.unitsSettingKey),
    );
    final saved = await _settings.read(AnahitaDefaults.locationSettingKey);
    if (saved != null && saved.trim().isNotEmpty && locationInput.isEmpty) {
      locationInput = saved.trim();
    }
    await refresh();
  }

  /// Switches views without refetching.
  void showTab(WeatherTab value) {
    if (_tab == value) return;
    _tab = value;
    notifyListeners();
  }

  /// Switches units and re-renders (the report itself is unit-agnostic).
  Future<void> setUnits(WeatherUnits value) async {
    if (_units == value) return;
    _units = value;
    await _settings.set(AnahitaDefaults.unitsSettingKey, value.name);
    notifyListeners();
  }

  /// Saves the current location box as the default location.
  Future<void> saveLocation(String location) async {
    final trimmed = location.trim();
    if (trimmed.isEmpty) {
      throw const AnahitaException(AnahitaDefaults.noLocationMessage);
    }
    await _settings.set(AnahitaDefaults.locationSettingKey, trimmed);
    locationInput = trimmed;
    notifyListeners();
  }

  /// Resolves the location (argument → saved setting → environment) and fetches the forecast.
  Future<WeatherReport?> refresh({String? placeArg}) async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final report = await _service.current(placeArg: placeArg);
      _report = report;
      _reportLocation = report.place.displayName;
      _loaded = true;
      return report;
    } catch (error) {
      _error = error is AnahitaException ? error.message : error.toString();
      _loaded = true;
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// The open tasks that carry a due date, in the order the plan view shows them.
  Future<List<haftkhan.HaftKhanTask>> plannedTasks() async {
    final open = await _tasks.listOpen();
    final withDue = open.where((task) => task.dueDate != null).toList()
      ..sort((a, b) => a.dueDate!.differenceInDays(b.dueDate!));
    return List.unmodifiable(withDue);
  }

  /// The text form of the current view — what "copy" puts on the clipboard.
  String? textView() {
    final report = _report;
    if (report == null) return null;

    return switch (_tab) {
      WeatherTab.now => AnahitaFormat.formatNow(report, _units),
      WeatherTab.forecast => AnahitaFormat.formatDaily(report, _units),
      WeatherTab.hourly => AnahitaFormat.formatHourly(
        report,
        _units,
        hours.length,
      ),
      WeatherTab.alerts => AnahitaFormat.formatAlerts(alerts),
      WeatherTab.best => AnahitaFormat.formatBest(bestDays),
      WeatherTab.plan => null,
    };
  }

  /// Builds the "weather for your plans" text locally (the plan view needs the task list).
  Future<String> planText() async {
    final report = _report;
    if (report == null) {
      throw const AnahitaException('Fetch a forecast before planning.');
    }
    final tasks = await plannedTasks();
    return AnahitaFormat.formatPlan(report, _units, [
      for (final task in tasks) (due: task.dueDate!, title: task.title),
    ]);
  }

  /// Asks the model to narrate the forecast.
  Future<String> explain() async {
    final report = _requireReport();
    await _requireKey(
      'The AI explanation needs an API key — add one in Soroush AI.',
    );
    return _funnel.completeText(_assistant.buildExplainPrompt(report));
  }

  /// Asks the model a free-form question about the current forecast.
  Future<String> ask(String question) async {
    final report = _requireReport();
    if (question.trim().isEmpty) {
      throw const AnahitaException('Type a question first.');
    }
    await _requireKey(
      'The AI answer needs an API key — add one in Soroush AI.',
    );
    return _funnel.completeText(_assistant.buildAskPrompt(question, report));
  }

  /// Asks the model to match open tasks to the best forecast days.
  Future<String> aiPlan() async {
    final report = _requireReport();
    final open = await _tasks.listOpen();
    if (open.isEmpty) {
      throw const AnahitaException('Nothing open — enjoy the peace.');
    }
    await _requireKey('The AI plan needs an API key — add one in Soroush AI.');
    return _funnel.completeText(_assistant.buildPlanPrompt(open, report));
  }

  WeatherReport _requireReport() {
    final report = _report;
    if (report == null) {
      throw const AnahitaException('Fetch a forecast first.');
    }
    return report;
  }

  Future<void> _requireKey(String message) async {
    if (!await _funnel.hasUsableKey()) {
      throw AnahitaException(message);
    }
  }

  /// The clock the "as of" line uses.
  DateTime now() => _clock();
}
