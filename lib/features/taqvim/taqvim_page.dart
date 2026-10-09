/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/date_only.dart';
import '../../core/fa_format.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import 'models.dart';
import 'taqvim_controller.dart';
import 'taqvim_defaults.dart';

const Key taqvimCaptureFieldKey = Key('taqvim.capture.field');

const Key taqvimCaptureKey = Key('taqvim.capture.parse');

const Key taqvimTitleKey = Key('taqvim.title');

const Key taqvimStartKey = Key('taqvim.start');

const Key taqvimEndKey = Key('taqvim.end');

const Key taqvimAllDayKey = Key('taqvim.allday');

const Key taqvimCalendarKey = Key('taqvim.calendar');

const Key taqvimLocationKey = Key('taqvim.location');

const Key taqvimTagsKey = Key('taqvim.tags');

const Key taqvimNotesKey = Key('taqvim.notes');

const Key taqvimRepeatKey = Key('taqvim.repeat');

const Key taqvimRepeatIntervalKey = Key('taqvim.repeat.interval');

const Key taqvimRemindersKey = Key('taqvim.reminders');

const Key taqvimSaveKey = Key('taqvim.save');

const Key taqvimNewKey = Key('taqvim.new');

const Key taqvimDeleteKey = Key('taqvim.delete');

const Key taqvimUndoKey = Key('taqvim.undo');

const Key taqvimRefreshKey = Key('taqvim.refresh');

const Key taqvimPrevDayKey = Key('taqvim.day.prev');

const Key taqvimNextDayKey = Key('taqvim.day.next');

const Key taqvimSearchFieldKey = Key('taqvim.search.field');

const Key taqvimSearchKey = Key('taqvim.search.run');

const Key taqvimCalendarFilterKey = Key('taqvim.filter.calendar');

const Key taqvimTagFilterKey = Key('taqvim.filter.tag');

const Key taqvimFreeDayKey = Key('taqvim.free.day');

const Key taqvimFreeFromKey = Key('taqvim.free.from');

const Key taqvimFreeToKey = Key('taqvim.free.to');

const Key taqvimFreeMinutesKey = Key('taqvim.free.minutes');

const Key taqvimFreeKey = Key('taqvim.free.run');

const Key taqvimTransferKey = Key('taqvim.transfer');

const Key taqvimTransferTextKey = Key('taqvim.transfer.text');

const Key taqvimImportKey = Key('taqvim.transfer.import');

const Key taqvimExportKey = Key('taqvim.transfer.export');

const Key taqvimCopyKey = Key('taqvim.transfer.copy');

const Key taqvimAiAskFieldKey = Key('taqvim.ai.ask.field');

const Key taqvimAiAskKey = Key('taqvim.ai.ask');

const Key taqvimAiBriefKey = Key('taqvim.ai.brief');

const Key taqvimAiPlanKey = Key('taqvim.ai.plan');

const Key taqvimAiCaptureKey = Key('taqvim.ai.capture');

Key taqvimScopeKey(TaqvimScope scope) => Key('taqvim.scope.${scope.key}');

Key taqvimOccurrenceKey(Occurrence occurrence) => Key(
  'taqvim.event.${occurrence.event.id}@'
  '${occurrence.start.toUtc().toIso8601String()}',
);

class TaqvimPage extends StatefulWidget {
  /// Creates the screen; the controller comes from the provider graph.
  const TaqvimPage({super.key});

  @override
  State<TaqvimPage> createState() => _TaqvimPageState();
}

class _TaqvimPageState extends State<TaqvimPage> {
  final TextEditingController _capture = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _start = TextEditingController();
  final TextEditingController _end = TextEditingController();
  final TextEditingController _calendar = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _repeatInterval = TextEditingController();
  final TextEditingController _reminders = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _calendarFilter = TextEditingController();
  final TextEditingController _tagFilter = TextEditingController();
  final TextEditingController _freeDay = TextEditingController();
  final TextEditingController _freeFrom = TextEditingController();
  final TextEditingController _freeTo = TextEditingController();
  final TextEditingController _freeMinutes = TextEditingController();
  final TextEditingController _transfer = TextEditingController();
  final TextEditingController _ask = TextEditingController();

  TaqvimController? _calendar2;

  /// The editing draft: the selected event, or null for a new one.
  int? _editingId;
  bool _allDay = false;
  RecurrenceKind _repeat = RecurrenceKind.once;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<TaqvimController>();
      _calendar2 = controller;
      controller.addListener(_onControllerChanged);
      _seedForm(controller);
      await controller.load();
      if (mounted) setState(_onControllerChanged);
    });
  }

  @override
  void dispose() {
    _calendar2?.removeListener(_onControllerChanged);
    for (final field in [
      _capture,
      _title,
      _start,
      _end,
      _calendar,
      _location,
      _tags,
      _notes,
      _repeatInterval,
      _reminders,
      _search,
      _calendarFilter,
      _tagFilter,
      _freeDay,
      _freeFrom,
      _freeTo,
      _freeMinutes,
      _transfer,
      _ask,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  TaqvimController? get _tx => _calendar2;

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Fills the form's defaults from the controller's own rails and clock.
  void _seedForm(TaqvimController controller) {
    _freeDay.text = _dayIso(controller.anchor);
    _freeFrom.text = TaqvimDefaults.workingDayStart;
    _freeTo.text = TaqvimDefaults.workingDayEnd;
    _freeMinutes.text = '${TaqvimDefaults.defaultFreeSlotMinutes}';
    _start.text = _defaultStartText(controller);
    _end.text = _defaultEndText(controller);
  }

  String _defaultStartText(TaqvimController controller) =>
      '${_dayIso(controller.anchor)} 09:00';

  String _defaultEndText(TaqvimController controller) =>
      '${_dayIso(controller.anchor)} 10:00';

  static String _dayIso(DateOnly day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  void _flash(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.inverseSurface,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Actions ──

  /// The `capture` verb: parse the sentence into the editor.
  void _runCapture() {
    final controller = _tx;
    if (controller == null) return;
    final sentence = _capture.text.trim();
    if (sentence.isEmpty) {
      _flash('Give me a sentence to capture.', error: true);
      return;
    }

    final parsed = controller.capture(sentence);
    if (parsed == null) {
      _flash(
        'That sentence has no date or time in it — nothing was invented.',
        error: true,
      );
      return;
    }

    setState(() {
      _editingId = null;
      _title.text = parsed.title;
      _allDay = parsed.isAllDay;
      _start.text = _stampText(parsed.start);
      _end.text = _stampText(parsed.end);
      _tags.text = parsed.tags;
      _location.text = parsed.location ?? '';
    });
  }

  /// The `add` / `edit` verbs behind one button.
  Future<void> _save() async {
    final controller = _tx;
    if (controller == null) return;

    final start = _parseWhen(controller, _start.text, 'start');
    if (start == null) return;
    final end = _parseWhen(controller, _end.text, 'end');
    if (end == null) return;

    final rule = _repeat == RecurrenceKind.once
        ? null
        : Recurrence(
            _repeat,
            interval: int.tryParse(_repeatInterval.text.trim()) ?? 1,
          );
    final reminders = TaqvimText.cleanReminders(
      _reminders.text,
      controller.options.maxRemindersPerEvent,
      TaqvimDefaults.maxReminderMinutes,
    );

    final editing = _editingId;
    if (editing == null) {
      final created = await controller.addEvent(
        title: _title.text,
        start: start,
        end: end,
        allDay: _allDay,
        calendar: _calendar.text,
        location: _location.text,
        notes: _notes.text,
        tags: _tags.text,
        rule: rule,
        reminders: reminders,
      );
      if (!mounted) return;
      _settle(controller, created?.id, controller.error, controller.message);
      return;
    }

    final updated = await controller.editEvent(
      editing,
      title: _title.text,
      start: start,
      end: end,
      allDay: _allDay,
      calendar: _calendar.text,
      location: _location.text,
      notes: _notes.text,
      tags: _tags.text,
      rule: rule,
      clearRule: _repeat == RecurrenceKind.once,
      reminders: reminders,
    );
    if (!mounted) return;
    _settle(controller, updated?.id, controller.error, controller.message);
  }

  void _settle(
    TaqvimController controller,
    int? id,
    String? error,
    String? message,
  ) {
    if (error != null) {
      _flash(error, error: true);
      setState(() {});
      return;
    }
    if (id != null) {
      setState(() {
        _editingId = id;
        final selected = controller.selected;
        if (selected != null) _fillFrom(selected);
      });
    }
    if (message != null) _flash(message);
    setState(() {});
  }

  DateTime? _parseWhen(TaqvimController controller, String text, String label) {
    try {
      return TaqvimText.parseWhen(text, controller.today.toUtcDateTime());
    } on TaqvimException catch (failure) {
      _flash(failure.message, error: true);
      return null;
    }
  }

  void _fillFrom(TaqvimEvent event) {
    _editingId = event.id;
    _title.text = event.title;
    _calendar.text = event.calendar;
    _location.text = event.location;
    _tags.text = event.tags;
    _notes.text = event.notes;
    _allDay = event.isAllDay;
    _start.text = _stampText(event.start);
    _end.text = _stampText(event.end);
    _reminders.text = TaqvimText.remindersToCsv(event.reminders);
    _repeat = event.rule?.kind ?? RecurrenceKind.once;
    _repeatInterval.text = '${event.rule?.interval ?? 1}';
  }

  void _newDraft() {
    final controller = _tx;
    if (controller == null) return;
    setState(() {
      _editingId = null;
      _title.clear();
      _calendar.clear();
      _location.clear();
      _tags.clear();
      _notes.clear();
      _reminders.clear();
      _repeatInterval.clear();
      _repeat = RecurrenceKind.once;
      _allDay = false;
      _start.text = _defaultStartText(controller);
      _end.text = _defaultEndText(controller);
    });
  }

  static String _stampText(DateTime instant) {
    final local = instant.toLocal();
    return '${_dayIso(DateOnly(local.year, local.month, local.day))} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<TaqvimController>();

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('taqvim.scroll'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _agendaCard(l10n, controller),
              const SizedBox(height: 12),
              _captureCard(l10n, controller),
              const SizedBox(height: 12),
              _editorCard(l10n, controller),
              const SizedBox(height: 12),
              _searchCard(l10n, controller),
              const SizedBox(height: 12),
              _windowsCard(l10n, controller),
              const SizedBox(height: 12),
              _transferCard(l10n, controller),
              const SizedBox(height: 12),
              _aiCard(l10n, controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _agendaCard(AppLocalizations l10n, TaqvimController controller) {
    final stats = controller.stats;
    return SectionCard(
      title: l10n.taqvimAgendaTitle,
      subtitle: l10n.taqvimAgendaSubtitle,
      icon: Icons.event_note_outlined,
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton(
            key: taqvimPrevDayKey,
            tooltip: l10n.taqvimPreviousDay,
            onPressed: () => controller.shiftDays(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            key: taqvimNextDayKey,
            tooltip: l10n.taqvimNextDay,
            onPressed: () => controller.shiftDays(1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            key: taqvimRefreshKey,
            tooltip: l10n.taqvimRefresh,
            onPressed: controller.load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: taqvimUndoKey,
            tooltip: l10n.taqvimUndo,
            onPressed: controller.undoAvailable ? controller.undo : null,
            icon: const Icon(Icons.undo),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final scope in TaqvimScope.values)
                ChoiceChip(
                  key: taqvimScopeKey(scope),
                  label: Text(_scopeLabel(l10n, scope)),
                  selected: controller.scope == scope,
                  onSelected: (_) => controller.setScope(scope),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            FaFormat.at(
              l10n.localeName,
              FaFormat.date(controller.anchor, l10n.localeName),
            ),
          ),
          if (stats != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  label: FaFormat.at(
                    l10n.localeName,
                    l10n.taqvimStatEvents(stats.events),
                  ),
                  icon: Icons.event_outlined,
                ),
                StatusChip(
                  label: FaFormat.at(
                    l10n.localeName,
                    l10n.taqvimStatRecurring(stats.recurring),
                  ),
                  icon: Icons.repeat,
                ),
                StatusChip(
                  label: FaFormat.at(
                    l10n.localeName,
                    l10n.taqvimStatAllDay(stats.allDay),
                  ),
                  icon: Icons.wb_sunny_outlined,
                ),
                StatusChip(
                  label: FaFormat.at(
                    l10n.localeName,
                    l10n.taqvimStatTagged(stats.tagged),
                  ),
                  icon: Icons.label_outline,
                ),
                StatusChip(
                  label: FaFormat.at(
                    l10n.localeName,
                    l10n.taqvimStatReminders(stats.reminders),
                  ),
                  icon: Icons.alarm,
                ),
                StatusChip(
                  label: FaFormat.at(
                    l10n.localeName,
                    l10n.taqvimStatNextSevenDays(stats.nextSevenDays),
                  ),
                  icon: Icons.date_range_outlined,
                ),
                StatusChip(
                  label: FaFormat.at(
                    l10n.localeName,
                    l10n.taqvimStatBusyMinutes(stats.busyMinutesNextSevenDays),
                  ),
                  icon: Icons.timer_outlined,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: taqvimCalendarFilterKey,
                  controller: _calendarFilter,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFilterCalendar,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: taqvimTagFilterKey,
                  controller: _tagFilter,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFilterTag,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => controller.setFilters(
                  calendar: _calendarFilter.text,
                  tag: _tagFilter.text,
                ),
                child: Text(l10n.taqvimFilterApply),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.agenda.isEmpty)
            EmptyState(
              message: l10n.taqvimAgendaEmpty,
              icon: Icons.event_available_outlined,
            )
          else
            // A labelled region, so a screen reader announces the list before reading the
            // rows; the rows keep their own nodes through `explicitChildNodes`.
            Semantics(
              label: l10n.a11yCalendarAgenda,
              container: true,
              explicitChildNodes: true,
              child: Column(
                children: [
                  for (final occurrence in controller.agenda)
                    _occurrenceTile(l10n, controller, occurrence),
                ],
              ),
            ),
          if (controller.conflicts.isNotEmpty) ...[
            const SizedBox(height: 8),
            StatusChip(
              label: l10n.taqvimConflictCount(controller.conflicts.length),
              icon: Icons.warning_amber_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _occurrenceTile(
    AppLocalizations l10n,
    TaqvimController controller,
    Occurrence occurrence,
  ) {
    final event = occurrence.event;
    final tags = TaqvimText.tagsOf(event);
    return ListTile(
      key: taqvimOccurrenceKey(occurrence),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        event.isAllDay ? Icons.wb_sunny_outlined : Icons.schedule_outlined,
      ),
      title: Text(event.title),
      subtitle: Text(
        [
          TaqvimText.whenLine(occurrence, locale: l10n.localeName),
          event.calendar,
          if (event.location.isNotEmpty) event.location,
          if (tags.isNotEmpty) tags.map((tag) => '#$tag').join(' '),
        ].join(' · '),
      ),
      trailing: Icon(
        _editingId == event.id
            ? Icons.check_circle_outline
            : Icons.chevron_right,
      ),
      onTap: () {
        setState(() => _fillFrom(event));
        unawaited(controller.select(event.id));
      },
    );
  }

  Widget _captureCard(AppLocalizations l10n, TaqvimController controller) {
    return SectionCard(
      title: l10n.taqvimCaptureTitle,
      subtitle: l10n.taqvimCaptureSubtitle,
      icon: Icons.auto_awesome_outlined,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: taqvimCaptureFieldKey,
              controller: _capture,
              decoration: InputDecoration(
                hintText: l10n.taqvimCaptureHint,
                isDense: true,
              ),
              onSubmitted: (_) => _runCapture(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: taqvimCaptureKey,
            onPressed: _runCapture,
            child: Text(l10n.taqvimCaptureAction),
          ),
        ],
      ),
    );
  }

  Widget _editorCard(AppLocalizations l10n, TaqvimController controller) {
    return SectionCard(
      title: _editingId == null
          ? l10n.taqvimEditorNewTitle
          : l10n.taqvimEditorEditTitle(_editingId!),
      subtitle: l10n.taqvimEditorSubtitle,
      icon: Icons.edit_calendar_outlined,
      trailing: TextButton.icon(
        key: taqvimNewKey,
        onPressed: _newDraft,
        icon: const Icon(Icons.add),
        label: Text(l10n.taqvimEditorNewAction),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: taqvimTitleKey,
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.taqvimFieldTitle,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: taqvimStartKey,
                  controller: _start,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldStart,
                    hintText: l10n.taqvimWhenHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: taqvimEndKey,
                  controller: _end,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldEnd,
                    hintText: l10n.taqvimWhenHint,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            key: taqvimAllDayKey,
            value: _allDay,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.taqvimFieldAllDay),
            onChanged: (value) => setState(() => _allDay = value),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: taqvimCalendarKey,
                  controller: _calendar,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldCalendar,
                    hintText: TaqvimDefaults.defaultCalendar,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: taqvimLocationKey,
                  controller: _location,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldLocation,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: taqvimTagsKey,
            controller: _tags,
            decoration: InputDecoration(
              labelText: l10n.taqvimFieldTags,
              hintText: l10n.taqvimTagsHint,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: taqvimNotesKey,
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.taqvimFieldNotes,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<RecurrenceKind>(
                  key: taqvimRepeatKey,
                  initialValue: _repeat,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldRepeat,
                    isDense: true,
                  ),
                  items: [
                    for (final kind in RecurrenceKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(_repeatLabel(l10n, kind)),
                      ),
                  ],
                  onChanged: (kind) =>
                      setState(() => _repeat = kind ?? RecurrenceKind.once),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: taqvimRepeatIntervalKey,
                  controller: _repeatInterval,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldRepeatInterval,
                    hintText: '1',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: taqvimRemindersKey,
            controller: _reminders,
            decoration: InputDecoration(
              labelText: l10n.taqvimFieldReminders,
              hintText: l10n.taqvimRemindersHint,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                key: taqvimSaveKey,
                onPressed: controller.busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _editingId == null ? l10n.taqvimSaveAdd : l10n.taqvimSaveEdit,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: taqvimDeleteKey,
                onPressed: _editingId == null
                    ? null
                    : () => _delete(_editingId!),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.taqvimDeleteAction),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(int id) async {
    final controller = _tx;
    if (controller == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).taqvimDeleteConfirmTitle),
        content: Text(AppLocalizations.of(context).taqvimDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            key: const Key('taqvim.delete.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).taqvimDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.delete(id);
    if (!mounted) return;
    _newDraft();
    _flash(
      controller.message ?? controller.error ?? '',
      error: controller.error != null,
    );
  }

  Widget _searchCard(AppLocalizations l10n, TaqvimController controller) {
    return SectionCard(
      title: l10n.taqvimSearchTitle,
      subtitle: l10n.taqvimSearchSubtitle,
      icon: Icons.search,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: taqvimSearchFieldKey,
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: l10n.taqvimSearchHint,
                    isDense: true,
                  ),
                  onSubmitted: controller.search,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                key: taqvimSearchKey,
                onPressed: () => controller.search(_search.text),
                child: Text(l10n.taqvimSearchAction),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (controller.searchResults.isEmpty)
            Text(l10n.taqvimSearchEmpty)
          else
            for (final event in controller.searchResults)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(event.title),
                subtitle: Text(
                  [
                    TaqvimText.whenLine(
                      Occurrence(
                        event: event,
                        start: event.start,
                        end: event.end,
                      ),
                      locale: l10n.localeName,
                    ),
                    event.calendar,
                    if (event.notes.isNotEmpty)
                      TaqvimText.clip(event.notes, 60),
                  ].join(' · '),
                ),
                onTap: () {
                  setState(() => _fillFrom(event));
                  unawaited(controller.select(event.id));
                },
              ),
        ],
      ),
    );
  }

  Widget _windowsCard(AppLocalizations l10n, TaqvimController controller) {
    return SectionCard(
      title: l10n.taqvimWindowsTitle,
      subtitle: l10n.taqvimWindowsSubtitle,
      icon: Icons.timelapse_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: taqvimFreeDayKey,
                  controller: _freeDay,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldDay,
                    hintText: l10n.taqvimDayHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: taqvimFreeFromKey,
                  controller: _freeFrom,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldFrom,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: taqvimFreeToKey,
                  controller: _freeTo,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldTo,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: taqvimFreeMinutesKey,
                  controller: _freeMinutes,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.taqvimFieldMinutes,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: taqvimFreeKey,
            onPressed: () => _computeFree(controller),
            child: Text(l10n.taqvimFreeAction),
          ),
          const SizedBox(height: 8),
          if (controller.freeSlots.isEmpty)
            Text(l10n.taqvimFreeEmpty)
          else
            for (final slot in controller.freeSlots)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hourglass_empty),
                title: Text(
                  FaFormat.at(
                    l10n.localeName,
                    '${TaqvimText.clip(slot.start.toIso8601String(), 16)} → '
                    '${TaqvimText.clip(slot.end.toIso8601String(), 16)}',
                  ),
                ),
                subtitle: Text(
                  l10n.taqvimFreeMinutesLabel(
                    slot.end.difference(slot.start).inMinutes,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _computeFree(TaqvimController controller) async {
    try {
      final day = TaqvimText.parseDay(_freeDay.text, 'day');
      final from = TaqvimText.parseClock(_freeFrom.text, 'window start');
      final to = TaqvimText.parseClock(_freeTo.text, 'window end');
      final minutes = int.tryParse(_freeMinutes.text.trim()) ?? 0;
      await controller.computeFreeSlots(day, from, to, minutes);
      if (!mounted) return;
      _flash(
        controller.message ?? controller.error ?? '',
        error: controller.error != null,
      );
    } on TaqvimException catch (failure) {
      _flash(failure.message, error: true);
    }
  }

  Widget _transferCard(AppLocalizations l10n, TaqvimController controller) {
    return SectionCard(
      title: l10n.taqvimTransferTitle,
      subtitle: l10n.taqvimTransferSubtitle,
      icon: Icons.swap_vert,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: taqvimTransferKey,
              onPressed: () => _openTransfer(controller),
              icon: const Icon(Icons.import_export),
              label: Text(l10n.taqvimTransferAction),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTransfer(TaqvimController controller) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.taqvimTransferTitle),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.taqvimTransferBody),
                const SizedBox(height: 8),
                TextField(
                  key: taqvimTransferTextKey,
                  controller: _transfer,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: 'BEGIN:VCALENDAR',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: taqvimExportKey,
              onPressed: () async {
                final text = await controller.exportIcs();
                if (!context.mounted) return;
                setState(() => _transfer.text = text);
              },
              child: Text(l10n.taqvimExportAction),
            ),
            TextButton(
              key: taqvimCopyKey,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _transfer.text));
              },
              child: Text(l10n.taqvimCopyAction),
            ),
            FilledButton(
              key: taqvimImportKey,
              onPressed: () async {
                await controller.importIcs(_transfer.text);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text(l10n.taqvimImportAction),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    _flash(
      controller.message ?? controller.error ?? '',
      error: controller.error != null,
    );
  }

  Widget _aiCard(AppLocalizations l10n, TaqvimController controller) {
    return SectionCard(
      title: l10n.taqvimAiTitle,
      subtitle: l10n.taqvimAiSubtitle,
      icon: Icons.smart_toy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: taqvimAiBriefKey,
                onPressed: controller.aiBusy ? null : controller.aiBrief,
                child: Text(l10n.taqvimAiBrief),
              ),
              FilledButton.tonal(
                key: taqvimAiPlanKey,
                onPressed: controller.aiBusy ? null : controller.aiPlan,
                child: Text(l10n.taqvimAiPlan),
              ),
              FilledButton.tonal(
                key: taqvimAiCaptureKey,
                onPressed: controller.aiBusy
                    ? null
                    : () => controller.aiCapture(_capture.text),
                child: Text(l10n.taqvimAiCapture),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: taqvimAiAskFieldKey,
                  controller: _ask,
                  decoration: InputDecoration(
                    hintText: l10n.taqvimAiAskHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: taqvimAiAskKey,
                onPressed: controller.aiBusy
                    ? null
                    : () => controller.aiAsk(_ask.text),
                child: Text(l10n.taqvimAiAsk),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (controller.aiBusy)
            const LinearProgressIndicator()
          else if (controller.aiAnswer != null) ...[
            SelectableText(controller.aiAnswer!),
            if (controller.aiSuggestion != null) ...[
              const SizedBox(height: 8),
              Text(l10n.taqvimAiSuggestion(controller.aiSuggestion!)),
            ],
          ] else
            Text(l10n.taqvimAiEmpty),
        ],
      ),
    );
  }

  static String _scopeLabel(AppLocalizations l10n, TaqvimScope scope) =>
      switch (scope) {
        TaqvimScope.today => l10n.taqvimScopeToday,
        TaqvimScope.tomorrow => l10n.taqvimScopeTomorrow,
        TaqvimScope.week => l10n.taqvimScopeWeek,
        TaqvimScope.month => l10n.taqvimScopeMonth,
        TaqvimScope.upcoming => l10n.taqvimScopeUpcoming,
      };

  static String _repeatLabel(AppLocalizations l10n, RecurrenceKind kind) =>
      switch (kind) {
        RecurrenceKind.once => l10n.taqvimRepeatOnce,
        RecurrenceKind.daily => l10n.taqvimRepeatDaily,
        RecurrenceKind.weekly => l10n.taqvimRepeatWeekly,
        RecurrenceKind.monthly => l10n.taqvimRepeatMonthly,
        RecurrenceKind.yearly => l10n.taqvimRepeatYearly,
      };
}
