/// anahita — see doc/anahita.md and AGENTS.md
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/date_only.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/section_card.dart';
import 'anahita_format.dart';
import 'models.dart';
import 'unit_math.dart';
import 'weather_code.dart';
import 'weather_controller.dart';

const Key anahitaLocationFieldKey = Key('anahita.location');
const Key anahitaSaveLocationButtonKey = Key('anahita.location.save');
const Key anahitaRefreshButtonKey = Key('anahita.refresh');
const Key anahitaUnitsButtonKey = Key('anahita.units');
const Key anahitaExplainButtonKey = Key('anahita.ai.explain');
const Key anahitaAskFieldKey = Key('anahita.ai.question');
const Key anahitaAskButtonKey = Key('anahita.ai.ask');
const Key anahitaAiPlanButtonKey = Key('anahita.ai.plan');
const Key anahitaCopyButtonKey = Key('anahita.copy');

class AnahitaPage extends StatefulWidget {
  /// Creates the screen; the controller comes from the provider graph.
  const AnahitaPage({super.key});

  @override
  State<AnahitaPage> createState() => _AnahitaPageState();
}

class _AnahitaPageState extends State<AnahitaPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<WeatherController>().initialise());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<WeatherController>();

    // Chrome above a scrolling body: on a phone (or at a large text scale) the toolbar alone
    // can be taller than the window, which is exactly what `AdaptivePageBody` handles.
    return AdaptivePageBody(
      chrome: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _Toolbar(controller: controller, l10n: l10n),
        ),
        if (controller.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _ErrorBanner(message: controller.error!),
          ),
      ],
      body: switch (controller.tab) {
        WeatherTab.now => _NowView(controller: controller, l10n: l10n),
        WeatherTab.forecast => _ForecastView(
          controller: controller,
          l10n: l10n,
        ),
        WeatherTab.hourly => _HourlyView(controller: controller, l10n: l10n),
        WeatherTab.alerts => _AlertsView(controller: controller, l10n: l10n),
        WeatherTab.best => _BestView(controller: controller, l10n: l10n),
        WeatherTab.plan => _PlanView(controller: controller, l10n: l10n),
      },
    );
  }
}

class _Toolbar extends StatefulWidget {
  const _Toolbar({required this.controller, required this.l10n});

  final WeatherController controller;
  final AppLocalizations l10n;

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  late final TextEditingController _location = TextEditingController(
    text: widget.controller.locationInput,
  );

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = widget.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<WeatherTab>(
              segments: [
                ButtonSegment(
                  value: WeatherTab.now,
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text(l10n.anahitaTabNow),
                ),
                ButtonSegment(
                  value: WeatherTab.forecast,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(l10n.anahitaTabForecast),
                ),
                ButtonSegment(
                  value: WeatherTab.hourly,
                  icon: const Icon(Icons.schedule),
                  label: Text(l10n.anahitaTabHourly),
                ),
                ButtonSegment(
                  value: WeatherTab.alerts,
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: Text(l10n.anahitaTabAlerts),
                ),
                ButtonSegment(
                  value: WeatherTab.best,
                  icon: const Icon(Icons.thumb_up_outlined),
                  label: Text(l10n.anahitaTabBest),
                ),
                ButtonSegment(
                  value: WeatherTab.plan,
                  icon: const Icon(Icons.event_note_outlined),
                  label: Text(l10n.anahitaTabPlan),
                ),
              ],
              selected: {controller.tab},
              onSelectionChanged: (selection) =>
                  controller.showTab(selection.first),
            ),
            SegmentedButton<WeatherUnits>(
              key: anahitaUnitsButtonKey,
              segments: [
                ButtonSegment(
                  value: WeatherUnits.metric,
                  label: Text(l10n.anahitaUnitsMetric),
                ),
                ButtonSegment(
                  value: WeatherUnits.imperial,
                  label: Text(l10n.anahitaUnitsImperial),
                ),
              ],
              selected: {controller.units},
              onSelectionChanged: (selection) =>
                  controller.setUnits(selection.first),
            ),
            TextButton.icon(
              key: anahitaCopyButtonKey,
              onPressed: controller.busy
                  ? null
                  : () => runAnahitaAction(context, () async {
                      final text = controller.tab == WeatherTab.plan
                          ? await controller.planText()
                          : controller.textView();
                      if (text == null || text.isEmpty) {
                        return l10n.anahitaNothingToCopy;
                      }
                      await Clipboard.setData(ClipboardData(text: text));
                      return l10n.commonCopied;
                    }),
              icon: const Icon(Icons.copy_all),
              label: Text(l10n.commonCopy),
            ),
            TextButton.icon(
              onPressed: controller.busy
                  ? null
                  : () => runAnahitaAction(context, () async {
                      await controller.explain();
                      return l10n.anahitaExplanationRequested;
                    }),
              key: anahitaExplainButtonKey,
              icon: const Icon(Icons.auto_awesome),
              label: Text(l10n.anahitaExplain),
            ),
            TextButton.icon(
              key: anahitaAiPlanButtonKey,
              onPressed: controller.busy
                  ? null
                  : () => runAnahitaAction(context, () async {
                      final answer = await controller.aiPlan();
                      return answer;
                    }),
              icon: const Icon(Icons.auto_fix_high),
              label: Text(l10n.anahitaAiPlan),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FieldActionFlow(
            field: TextFormField(
              key: anahitaLocationFieldKey,
              controller: _location,
              onChanged: (value) => controller.locationInput = value,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.place_outlined),
                labelText: l10n.anahitaLocation,
                hintText: l10n.anahitaLocationHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onFieldSubmitted: (value) =>
                  _go(context, controller, value.trim()),
            ),
            actions: [
              FilledButton.icon(
                key: anahitaRefreshButtonKey,
                onPressed: controller.busy
                    ? null
                    : () => _go(context, controller, _location.text.trim()),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRefresh),
              ),
              OutlinedButton.icon(
                key: anahitaSaveLocationButtonKey,
                onPressed: controller.busy
                    ? null
                    : () => runAnahitaAction(context, () async {
                        final place = _location.text.trim();
                        await controller.saveLocation(place);
                        await controller.refresh(placeArg: place);
                        return l10n.anahitaLocationSaved(place);
                      }),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.anahitaSaveLocation),
              ),
            ],
          ),
        ),
        if (controller.report != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.anahitaAsOf(
                controller.report!.place.displayName,
                controller.report!.place.timezone,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _go(
    BuildContext context,
    WeatherController controller,
    String location,
  ) async {
    controller.locationInput = location;
    await controller.refresh(placeArg: location.isEmpty ? null : location);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.error_outline,
      title: AppLocalizations.of(context).anahitaFetchFailed,
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

class _NowView extends StatelessWidget {
  const _NowView({required this.controller, required this.l10n});

  final WeatherController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final report = controller.report;
    if (report == null) {
      return _Waiting(busy: controller.busy, l10n: l10n);
    }

    final theme = Theme.of(context);
    final current = report.current;
    final today = report.daily.isEmpty ? null : report.daily.first;
    final units = controller.units;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: report.place.displayName,
          subtitle:
              '${report.place.timezone} · '
              '${AnahitaFormat.clock(controller.now().toLocal())}',
          icon: Icons.place_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    WeatherCode.icon(current.code),
                    style: theme.textTheme.displayMedium,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          UnitMath.temperature(current.temperatureC, units),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${WeatherCode.describe(current.code)} · '
                          '${l10n.anahitaFeelsLike(UnitMath.temperature(current.apparentC, units))}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Fact(
                    icon: Icons.water_drop_outlined,
                    label: l10n.anahitaHumidity,
                    value: '${current.humidityPercent}%',
                  ),
                  _Fact(
                    icon: Icons.air,
                    label: l10n.anahitaWind,
                    value:
                        '${UnitMath.speed(current.windKmh, units)} '
                        '${l10n.anahitaWindDirection(_compass(current.windDirectionDeg))}',
                  ),
                  _Fact(
                    icon: Icons.umbrella_outlined,
                    label: l10n.anahitaPrecipitation,
                    value: _millimetres(current.precipMm, units),
                  ),
                  if (today?.sunrise != null && today?.sunset != null)
                    _Fact(
                      icon: Icons.wb_twilight,
                      label: l10n.anahitaSun,
                      value:
                          '${today!.sunrise!.format()} → ${today.sunset!.format()}',
                    ),
                  if (today?.uvMax != null)
                    _Fact(
                      icon: Icons.brightness_7_outlined,
                      label: l10n.anahitaUvMax,
                      value: UnitMath.format(today!.uvMax!),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (controller.alerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SectionCard(
              title: l10n.anahitaTabAlerts,
              icon: Icons.warning_amber_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final alert in controller.alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${alert.severity == AlertSeverity.warning ? '⚠' : '☑'} '
                        '${alert.title} — ${alert.message}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _AskCard(controller: controller, l10n: l10n),
        ),
      ],
    );
  }

  static String _compass(int degrees) => AnahitaFormat.compass(degrees);

  static String _millimetres(double mm, WeatherUnits units) =>
      AnahitaFormat.precipitation(mm, units);
}

class _ForecastView extends StatelessWidget {
  const _ForecastView({required this.controller, required this.l10n});

  final WeatherController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final report = controller.report;
    if (report == null) return _Waiting(busy: controller.busy, l10n: l10n);

    final theme = Theme.of(context);
    final units = controller.units;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: l10n.anahitaForecastTitle(report.daily.length),
          icon: Icons.calendar_month_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final day in report.daily)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          anahitaDayLabel(day.date),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          '${UnitMath.temperature(day.minC, units)} – '
                          '${UnitMath.temperature(day.maxC, units)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(WeatherCode.icon(day.code)),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          anahitaRainChance(day.precipProbabilityPercent),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          WeatherCode.describe(day.code),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourlyView extends StatelessWidget {
  const _HourlyView({required this.controller, required this.l10n});

  final WeatherController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final report = controller.report;
    if (report == null) return _Waiting(busy: controller.busy, l10n: l10n);

    final theme = Theme.of(context);
    final units = controller.units;
    final hours = controller.hours;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: l10n.anahitaHourlyTitle(hours.length),
          icon: Icons.schedule,
          child: hours.isEmpty
              ? Text(l10n.commonEmpty, style: theme.textTheme.bodySmall)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final point in hours)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(anahitaClock(point.localTime)),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                UnitMath.temperature(point.temperatureC, units),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(WeatherCode.icon(point.code)),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text(
                                anahitaRainChance(
                                  point.precipProbabilityPercent,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${WeatherCode.describe(point.code)} · '
                                '${UnitMath.speed(point.windKmh, units)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AlertsView extends StatelessWidget {
  const _AlertsView({required this.controller, required this.l10n});

  final WeatherController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alerts = controller.alerts;
    if (controller.report == null) {
      return _Waiting(busy: controller.busy, l10n: l10n);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: l10n.anahitaTabAlerts,
          icon: Icons.warning_amber_outlined,
          child: alerts.isEmpty
              ? Text(l10n.anahitaNoAlerts, style: theme.textTheme.bodyMedium)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final alert in alerts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              alert.severity == AlertSeverity.warning
                                  ? Icons.warning_amber_outlined
                                  : Icons.info_outline,
                              color: alert.severity == AlertSeverity.warning
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.title,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    alert.message,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BestView extends StatelessWidget {
  const _BestView({required this.controller, required this.l10n});

  final WeatherController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.report == null) {
      return _Waiting(busy: controller.busy, l10n: l10n);
    }
    final days = controller.bestDays;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: l10n.anahitaBestTitle,
          subtitle: l10n.anahitaBestSubtitle,
          icon: Icons.thumb_up_outlined,
          child: days.isEmpty
              ? Text(l10n.commonEmpty, style: theme.textTheme.bodySmall)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}.',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${anahitaDayLabel(days[i].date)} '
                                    '(${l10n.anahitaScore(days[i].score)})',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    days[i].summary,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PlanView extends StatefulWidget {
  const _PlanView({required this.controller, required this.l10n});

  final WeatherController controller;
  final AppLocalizations l10n;

  @override
  State<_PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<_PlanView> {
  String? _text;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final text = await widget.controller.planText();
    if (mounted) setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.controller.report == null) {
      return _Waiting(busy: widget.controller.busy, l10n: widget.l10n);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: widget.l10n.anahitaPlanTitle,
          subtitle: widget.l10n.anahitaPlanSubtitle,
          icon: Icons.event_note_outlined,
          trailing: IconButton(
            tooltip: widget.l10n.commonRefresh,
            onPressed: () => unawaited(_load()),
            icon: const Icon(Icons.refresh),
          ),
          child: Text(
            _text ?? widget.l10n.commonLoading,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _AskCard extends StatefulWidget {
  const _AskCard({required this.controller, required this.l10n});

  final WeatherController controller;
  final AppLocalizations l10n;

  @override
  State<_AskCard> createState() => _AskCardState();
}

class _AskCardState extends State<_AskCard> {
  final TextEditingController _question = TextEditingController();
  String? _answer;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      title: widget.l10n.anahitaAskTitle,
      subtitle: widget.l10n.anahitaAskSubtitle,
      icon: Icons.question_answer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: anahitaAskFieldKey,
            controller: _question,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: widget.l10n.anahitaAskLabel,
              hintText: widget.l10n.anahitaAskHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: anahitaAskButtonKey,
              onPressed: () => runAnahitaAction(context, () async {
                final answer = await widget.controller.ask(_question.text);
                setState(() => _answer = answer);
                return widget.l10n.anahitaAnswered;
              }),
              icon: const Icon(Icons.send),
              label: Text(widget.l10n.anahitaAsk),
            ),
          ),
          if (_answer != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_answer!, style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.busy, required this.l10n});

  final bool busy;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            busy ? l10n.commonLoading : l10n.anahitaNothingYet,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

Future<void> runAnahitaAction(
  BuildContext context,
  Future<String> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final message = await action();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(anahitaErrorText(error))));
  }
}

String anahitaErrorText(Object error) =>
    error is AnahitaException ? error.message : error.toString();

String anahitaDayLabel(DateOnly date) => AnahitaFormat.dayLabel(date);

String anahitaClock(DateTime value) => AnahitaFormat.clock(value);

String anahitaRainChance(double? percent) => AnahitaFormat.rainChance(percent);
