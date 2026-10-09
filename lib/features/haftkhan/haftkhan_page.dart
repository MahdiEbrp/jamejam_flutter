/// haftkhan — see doc/haftkhan.md and AGENTS.md
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/fa_format.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/section_card.dart';
import 'backup.dart';
import 'haftkhan_controller.dart';
import 'models.dart';

class HaftKhanPage extends StatefulWidget {
  const HaftKhanPage({super.key});

  @override
  State<HaftKhanPage> createState() => _HaftKhanPageState();
}

class _HaftKhanPageState extends State<HaftKhanPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<HaftKhanController>().refresh());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<HaftKhanController>();

    return AdaptivePageBody(
      chrome: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _Toolbar(
            controller: controller,
            searchController: _searchController,
            l10n: l10n,
          ),
        ),
        if (controller.tab == HaftKhanTab.list)
          _ViewSelector(controller: controller, l10n: l10n),
      ],
      body: switch (controller.tab) {
        HaftKhanTab.list => _TaskList(controller: controller, l10n: l10n),
        HaftKhanTab.board => _BoardView(controller: controller, l10n: l10n),
        HaftKhanTab.matrix => _MatrixView(controller: controller, l10n: l10n),
        HaftKhanTab.report => _ReportView(controller: controller, l10n: l10n),
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.searchController,
    required this.l10n,
  });

  final HaftKhanController controller;
  final TextEditingController searchController;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = controller.report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.haftKhanTitle, style: theme.textTheme.titleLarge),
            if (report != null)
              Chip(
                avatar: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(
                  FaFormat.at(
                    l10n.localeName,
                    l10n.haftKhanStatsLine(
                      report.todo,
                      report.doing,
                      report.done,
                      report.overdue,
                    ),
                  ),
                ),
              ),
            if (report != null &&
                (report.currentStreak > 0 || report.bestStreak > 0))
              Chip(
                avatar: const Icon(
                  Icons.local_fire_department_outlined,
                  size: 16,
                ),
                label: Text(
                  l10n.haftKhanStreak(report.currentStreak, report.bestStreak),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<HaftKhanTab>(
              segments: [
                ButtonSegment(
                  value: HaftKhanTab.list,
                  icon: const Icon(Icons.list_alt),
                  label: Text(l10n.haftKhanTabList),
                ),
                ButtonSegment(
                  value: HaftKhanTab.board,
                  icon: const Icon(Icons.view_kanban_outlined),
                  label: Text(l10n.haftKhanTabBoard),
                ),
                ButtonSegment(
                  value: HaftKhanTab.matrix,
                  icon: const Icon(Icons.grid_on),
                  label: Text(l10n.haftKhanTabMatrix),
                ),
                ButtonSegment(
                  value: HaftKhanTab.report,
                  icon: const Icon(Icons.insights),
                  label: Text(l10n.haftKhanTabReport),
                ),
              ],
              selected: {controller.tab},
              onSelectionChanged: (selection) =>
                  controller.showTab(selection.first),
            ),
            TextButton.icon(
              onPressed: controller.busy ? null : () => controller.refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRefresh),
            ),
            TextButton.icon(
              key: haftKhanUndoButtonKey,
              onPressed: controller.busy
                  ? null
                  : () => runHaftKhanAction(context, () async {
                      final result = await controller.undo();
                      return l10n.haftKhanUndoDone(
                        result.operation,
                        result.restoredTasks,
                      );
                    }),
              icon: const Icon(Icons.undo),
              label: Text(l10n.commonUndo),
            ),
            TextButton.icon(
              onPressed: controller.busy
                  ? null
                  : () async {
                      final done = controller.report?.done ?? 0;
                      if (done == 0) {
                        await runHaftKhanAction(
                          context,
                          () async => l10n.haftKhanClearedDone(0),
                        );
                        return;
                      }
                      final confirmed = await confirmHaftKhanAction(
                        context,
                        title: l10n.haftKhanClearDone,
                        message: l10n.haftKhanConfirmClearDone(done),
                      );
                      if (!confirmed || !context.mounted) return;
                      await runHaftKhanAction(context, () async {
                        final removed = await controller.clearCompleted();
                        return l10n.haftKhanClearedDone(removed);
                      });
                    },
              icon: const Icon(Icons.cleaning_services_outlined),
              label: Text(l10n.haftKhanClearDone),
            ),
            TextButton.icon(
              onPressed: controller.busy ? null : () => _showAiSummary(context),
              icon: const Icon(Icons.auto_awesome),
              label: Text(l10n.haftKhanAiSummary),
            ),
            TextButton.icon(
              onPressed: controller.busy ? null : () => _showTransfer(context),
              icon: const Icon(Icons.import_export),
              label: Text(l10n.haftKhanTransfer),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: haftKhanSearchFieldKey,
          controller: searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: l10n.commonSearch,
            hintText: l10n.haftKhanSearchHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => controller.setSearch(value),
        ),
        if (controller.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              controller.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showAiSummary(BuildContext context) async {
    await runHaftKhanAction(context, () async {
      final summary = await controller.summarise();
      return summary;
    });
  }

  Future<void> _showTransfer(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TransferDialog(controller: controller, l10n: l10n),
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.controller, required this.l10n});

  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<TaskView>(
            segments: [
              ButtonSegment(
                value: TaskView.open,
                label: Text(l10n.haftKhanViewOpen),
              ),
              ButtonSegment(
                value: TaskView.all,
                label: Text(l10n.haftKhanViewAll),
              ),
              ButtonSegment(
                value: TaskView.done,
                label: Text(l10n.haftKhanViewDone),
              ),
              ButtonSegment(
                value: TaskView.today,
                label: Text(l10n.haftKhanViewToday),
              ),
              ButtonSegment(
                value: TaskView.overdue,
                label: Text(l10n.haftKhanViewOverdue),
              ),
            ],
            selected: {controller.view},
            onSelectionChanged: (selection) =>
                controller.showView(selection.first),
          ),
          _FilterChip<TaskPriority>(
            key: haftKhanPriorityFilterKey,
            label: l10n.haftKhanFilterPriority,
            value: _priorityOf(controller.priorityFilter),
            options: TaskPriority.values,
            render: (value) => value.name,
            onChanged: (value) => controller.setPriorityFilter(value?.name),
          ),
          _FilterChip<String>(
            key: haftKhanTagFilterKey,
            label: l10n.haftKhanFilterTag,
            value: controller.tagFilter,
            options: controller.availableTags,
            render: (value) => '#$value',
            onChanged: controller.setTagFilter,
          ),
          _FilterChip<String>(
            key: haftKhanProjectFilterKey,
            label: l10n.haftKhanFilterProject,
            value: controller.projectFilter,
            options: controller.availableProjects,
            render: (value) => '@$value',
            onChanged: controller.setProjectFilter,
          ),
          if (controller.priorityFilter != null ||
              controller.tagFilter != null ||
              controller.projectFilter != null)
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off, size: 16),
              label: Text(l10n.haftKhanClearFilters),
              onPressed: () => controller.clearFilters(),
            ),
        ],
      ),
    );
  }

  static TaskPriority? _priorityOf(String? name) {
    for (final priority in TaskPriority.values) {
      if (priority.name == name) return priority;
    }
    return null;
  }
}

class _FilterChip<T> extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.render,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T value) render;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T?>(
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<T?>(value: null, child: Text('$label: ${'—'}')),
        for (final option in options)
          PopupMenuItem<T?>(value: option, child: Text(render(option))),
      ],
      child: Chip(
        avatar: const Icon(Icons.filter_list, size: 16),
        label: Text(value == null ? label : '$label: ${render(value as T)}'),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.controller, required this.l10n});

  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = controller.tasks;

    return Stack(
      children: [
        if (tasks.isEmpty)
          Center(
            child: Text(
              controller.search.isEmpty
                  ? l10n.haftKhanEmptyView
                  : l10n.haftKhanNoMatches,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: tasks.length,
            itemBuilder: (context, index) => _TaskTile(
              task: tasks[index],
              controller: controller,
              l10n: l10n,
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            key: haftKhanAddButtonKey,
            onPressed: () => _showAddDialog(context, controller, l10n),
            icon: const Icon(Icons.add),
            label: Text(l10n.haftKhanAddTask),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    HaftKhanController controller,
    AppLocalizations l10n,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TaskFormDialog(controller: controller, l10n: l10n),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.controller,
    required this.l10n,
  });

  final HaftKhanTask task;
  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocked = controller.isBlocked(task.id);
    final overdue =
        task.isOpen &&
        task.dueDate != null &&
        task.dueDate! < controller.service.today();
    final due = task.dueDate;

    final meta = <String>[
      if (task.project.isNotEmpty) '@${task.project}',
      ...task.tags.map((tag) => '#$tag'),
      if (task.priority != TaskPriority.normal) task.priority.name,
      if (task.effort != TaskEffort.none) task.effort.name,
      if (task.recurrence != RecurrenceKind.none)
        l10n.haftKhanEvery(task.recurrenceInterval, task.recurrence.canonical),
    ];

    return Card(
      key: ValueKey('haftkhan-task-${task.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StateButton(task: task, controller: controller, l10n: l10n),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        FaFormat.at(l10n.localeName, '#${task.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            decoration: task.state == TaskState.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        task.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (meta.isNotEmpty || due != null || blocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (due != null)
                            _MetaChip(
                              icon: Icons.event,
                              label: due.format(locale: l10n.localeName),
                              tone: overdue ? _Tone.danger : _Tone.normal,
                            ),
                          if (overdue)
                            _MetaChip(
                              icon: Icons.warning_amber_outlined,
                              label: l10n.haftKhanOverdueLabel,
                              tone: _Tone.danger,
                            ),
                          if (blocked)
                            _MetaChip(
                              icon: Icons.block,
                              label: l10n.haftKhanBlockedBy(
                                controller.openBlockers[task.id]!.join(', '),
                              ),
                              tone: _Tone.warning,
                            ),
                          for (final label in meta)
                            _MetaChip(icon: Icons.label_outline, label: label),
                        ],
                      ),
                    ),
                  if (task.state == TaskState.done && task.completedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.haftKhanConqueredOn(
                          l10n.formatDate(task.completedAt!.toLocal()),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<_TaskAction>(
              key: ValueKey('haftkhan-menu-${task.id}'),
              onSelected: (action) => _run(context, action),
              itemBuilder: (context) => [
                if (task.state != TaskState.done)
                  PopupMenuItem(
                    value: _TaskAction.start,
                    child: Text(l10n.haftKhanStart),
                  ),
                if (task.state != TaskState.done)
                  PopupMenuItem(
                    value: _TaskAction.complete,
                    child: Text(l10n.haftKhanComplete),
                  ),
                if (task.state != TaskState.done && blocked)
                  PopupMenuItem(
                    value: _TaskAction.completeForce,
                    child: Text(l10n.haftKhanCompleteAnyway),
                  ),
                PopupMenuItem(
                  value: _TaskAction.breakdown,
                  child: Text(l10n.haftKhanAiBreakdown),
                ),
                PopupMenuItem(
                  value: _TaskAction.remove,
                  child: Text(l10n.commonRemove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, _TaskAction action) async {
    if (action == _TaskAction.remove) {
      final confirmed = await confirmHaftKhanAction(
        context,
        title: l10n.commonRemove,
        message: l10n.haftKhanConfirmRemove(task.id, task.title),
      );
      if (!confirmed) return;
    }

    if (!context.mounted) return;
    await runHaftKhanAction(context, () async {
      switch (action) {
        case _TaskAction.start:
          final started = await controller.start(task.id);
          return l10n.haftKhanStarted(started.id, started.title);
        case _TaskAction.complete:
          return _completeText(await controller.complete(task.id));
        case _TaskAction.completeForce:
          return _completeText(await controller.complete(task.id, force: true));
        case _TaskAction.remove:
          await controller.remove(task.id);
          return l10n.haftKhanRemoved(task.id);
        case _TaskAction.breakdown:
          final plan = await controller.breakdown(task.id);
          final steps = plan.steps.isEmpty
              ? plan.rawResponse
              : plan.steps.join('\n');
          return l10n.haftKhanPlanHeader(task.id, task.title, steps);
      }
    });
  }

  String _completeText(CompleteResult result) {
    final next = result.next;
    if (next == null) {
      return l10n.haftKhanConquered(
        result.completed.id,
        result.completed.title,
      );
    }

    return '${l10n.haftKhanConquered(result.completed.id, result.completed.title)}\n'
        '${l10n.haftKhanRespawned(next.id, next.title, next.dueDate?.toIso() ?? '—')}';
  }
}

enum _TaskAction { start, complete, completeForce, remove, breakdown }

enum _Tone { normal, warning, danger }

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.tone = _Tone.normal,
  });

  final IconData icon;
  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      _Tone.normal => theme.colorScheme.onSurfaceVariant,
      _Tone.warning => theme.colorScheme.tertiary,
      _Tone.danger => theme.colorScheme.error,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _StateButton extends StatelessWidget {
  const _StateButton({
    required this.task,
    required this.controller,
    required this.l10n,
  });

  final HaftKhanTask task;
  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (task.state == TaskState.done) {
      return const Icon(Icons.verified_outlined, color: Colors.green);
    }

    final blocked = controller.isBlocked(task.id);
    return Tooltip(
      message: task.state == TaskState.todo
          ? l10n.haftKhanStart
          : l10n.haftKhanComplete,
      child: IconButton(
        key: ValueKey('haftkhan-state-${task.id}'),
        onPressed: () => runHaftKhanAction(context, () async {
          if (task.state == TaskState.todo) {
            final started = await controller.start(task.id);
            return l10n.haftKhanStarted(started.id, started.title);
          }

          final result = await controller.complete(task.id, force: blocked);
          final next = result.next;
          if (next == null) {
            return l10n.haftKhanConquered(
              result.completed.id,
              result.completed.title,
            );
          }
          return l10n.haftKhanRespawned(
            next.id,
            next.title,
            next.dueDate?.toIso() ?? '—',
          );
        }),
        icon: Icon(
          task.state == TaskState.todo
              ? Icons.play_circle_outline
              : Icons.check_circle_outline,
        ),
      ),
    );
  }
}

class _BoardView extends StatelessWidget {
  const _BoardView({required this.controller, required this.l10n});

  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String titleOf(String raw) => switch (raw) {
      'TODO' => l10n.haftKhanColumnTodo,
      'DOING' => l10n.haftKhanColumnDoing,
      _ => l10n.haftKhanColumnDone,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.vertical,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final column in controller.board)
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 12),
                  child: SizedBox(
                    width: 300,
                    child: SectionCard(
                      title: titleOf(column.title),
                      subtitle: l10n.haftKhanColumnCount(column.tasks.length),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (column.tasks.isEmpty)
                            Text(
                              l10n.commonEmpty,
                              style: theme.textTheme.bodySmall,
                            ),
                          for (final task in column.tasks)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Text(
                                FaFormat.at(l10n.localeName, '#${task.id}'),
                              ),
                              title: Text(task.title),
                              subtitle: task.dueDate == null
                                  ? null
                                  : Text(
                                      task.dueDate!.format(
                                        locale: l10n.localeName,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatrixView extends StatelessWidget {
  const _MatrixView({required this.controller, required this.l10n});

  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A fixed cell height (rather than an aspect ratio) keeps the four quadrants readable on
    // a short window: the quadrant list scrolls inside its own card instead of overflowing.
    return GridView(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 280,
      ),
      children: [
        for (final quadrant in controller.matrix)
          // Laid out here rather than with [SectionCard]: a quadrant's list has to take the
          // leftover height of a fixed-size grid cell and scroll inside it.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    quadrant.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: quadrant.tasks.isEmpty
                        ? Text(
                            l10n.commonEmpty,
                            style: theme.textTheme.bodySmall,
                          )
                        : ListView(
                            children: [
                              for (final task in quadrant.tasks)
                                Text(
                                  '#${task.id} ${task.title}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.controller, required this.l10n});

  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final report = controller.report;
    final theme = Theme.of(context);
    if (report == null) {
      return Center(child: Text(l10n.commonLoading));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: l10n.haftKhanTabReport,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                FaFormat.at(
                  l10n.localeName,
                  l10n.haftKhanStatsLine(
                    report.todo,
                    report.doing,
                    report.done,
                    report.overdue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.haftKhanStreak(report.currentStreak, report.bestStreak),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.haftKhanDoneWindow(report.doneToday, report.doneLast7Days),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.haftKhanFocusTitle,
          subtitle: l10n.haftKhanFocusSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.focus.isEmpty)
                Text(l10n.commonEmpty, style: theme.textTheme.bodyMedium),
              for (final task in report.focus)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text(FaFormat.at(l10n.localeName, '#${task.id}')),
                  title: Text(task.title),
                  subtitle: Text(
                    [
                      task.priority.name,
                      if (task.dueDate != null)
                        task.dueDate!.format(locale: l10n.localeName),
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskFormDialog extends StatefulWidget {
  const _TaskFormDialog({required this.controller, required this.l10n});

  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _due = TextEditingController();
  final _project = TextEditingController();
  final _tags = TextEditingController();
  final _interval = TextEditingController();
  final _blockedBy = TextEditingController();

  String _priority = 'normal';
  String _effort = 'none';
  String _recurrence = 'none';
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _due.dispose();
    _project.dispose();
    _tags.dispose();
    _interval.dispose();
    _blockedBy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog(
      title: Text(l10n.haftKhanAddTask),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: haftKhanTitleFieldKey,
                controller: _title,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.haftKhanFieldTitle),
              ),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.haftKhanFieldNotes),
              ),
              TextField(
                key: haftKhanDueFieldKey,
                controller: _due,
                decoration: InputDecoration(
                  labelText: l10n.haftKhanFieldDue,
                  hintText: l10n.haftKhanFieldDueHint,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: InputDecoration(
                        labelText: l10n.haftKhanFieldPriority,
                      ),
                      items: [
                        for (final priority in TaskPriority.values)
                          DropdownMenuItem(
                            value: priority.name,
                            child: Text(priority.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _priority = value ?? 'normal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _effort,
                      decoration: InputDecoration(
                        labelText: l10n.haftKhanFieldEffort,
                      ),
                      items: [
                        for (final effort in TaskEffort.values)
                          DropdownMenuItem(
                            value: effort.name,
                            child: Text(effort.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _effort = value ?? 'none'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _recurrence,
                      decoration: InputDecoration(
                        labelText: l10n.haftKhanFieldRecurrence,
                      ),
                      items: [
                        for (final kind in RecurrenceKind.values)
                          DropdownMenuItem(
                            value: kind.name,
                            child: Text(kind.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _recurrence = value ?? 'none'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _interval,
                      decoration: InputDecoration(
                        labelText: l10n.haftKhanFieldInterval,
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _project,
                decoration: InputDecoration(
                  labelText: l10n.haftKhanFieldProject,
                ),
              ),
              TextField(
                controller: _tags,
                decoration: InputDecoration(
                  labelText: l10n.haftKhanFieldTags,
                  hintText: l10n.haftKhanFieldTagsHint,
                ),
              ),
              TextField(
                controller: _blockedBy,
                decoration: InputDecoration(
                  labelText: l10n.haftKhanFieldBlockedBy,
                  hintText: l10n.haftKhanFieldBlockedByHint,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: haftKhanSubmitButtonKey,
          onPressed: _submit,
          child: Text(l10n.commonAdd),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    try {
      final blockedBy = _blockedBy.text.trim().isEmpty
          ? null
          : _blockedBy.text
                .split(',')
                .map((part) => int.parse(part.trim()))
                .toList();

      final task = await widget.controller.addTask(
        title: _title.text,
        notes: _notes.text,
        priorityName: _priority,
        dueDateText: _due.text,
        project: _project.text,
        tagsCsv: _tags.text,
        effortName: _effort,
        recurrenceName: _recurrence,
        intervalText: _interval.text,
        blockedBy: blockedBy,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.haftKhanAdded(task.id, task.title))),
      );
    } catch (error) {
      setState(() => _error = haftKhanErrorText(widget.l10n, error));
    }
  }
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.controller, required this.l10n});

  final HaftKhanController controller;
  final AppLocalizations l10n;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _text = TextEditingController();
  bool _replace = false;
  String? _status;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog(
      title: Text(l10n.haftKhanTransfer),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: haftKhanExportButtonKey,
                  onPressed: _export,
                  icon: const Icon(Icons.copy_all),
                  label: Text(l10n.haftKhanExportJson),
                ),
                OutlinedButton.icon(
                  onPressed: _exportMarkdown,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l10n.haftKhanExportMarkdown),
                ),
                OutlinedButton.icon(
                  key: haftKhanImportButtonKey,
                  onPressed: _import,
                  icon: const Icon(Icons.download),
                  label: Text(l10n.haftKhanImport),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _replace,
              onChanged: (value) => setState(() => _replace = value ?? false),
              title: Text(l10n.haftKhanImportReplace),
            ),
            TextField(
              key: haftKhanTransferFieldKey,
              controller: _text,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: l10n.haftKhanTransferHint,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_status!),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  Future<void> _export() async {
    try {
      final backup = await widget.controller.exportBackup();
      final json = Backup.toJson(backup);
      // Put the payload in the paste box as well as the clipboard: on a desktop without a
      // clipboard service the dialog is still the whole round trip.
      _text.text = json;
      await Clipboard.setData(ClipboardData(text: json));
      setState(
        () => _status = widget.l10n.haftKhanExported(backup.tasks.length),
      );
    } catch (error) {
      setState(() => _status = haftKhanErrorText(widget.l10n, error));
    }
  }

  Future<void> _exportMarkdown() async {
    try {
      final markdown = await widget.controller.exportMarkdown();
      await Clipboard.setData(ClipboardData(text: markdown));
      setState(() => _status = widget.l10n.haftKhanExportedMarkdown);
    } catch (error) {
      setState(() => _status = haftKhanErrorText(widget.l10n, error));
    }
  }

  Future<void> _import() async {
    try {
      final backup = Backup.fromJson(_text.text);
      if (_replace) {
        final confirmed = await confirmHaftKhanAction(
          context,
          title: widget.l10n.haftKhanImportReplace,
          message: widget.l10n.haftKhanConfirmImportReplace,
        );
        if (!confirmed) return;
      }
      final result = await widget.controller.importBackup(
        backup,
        replace: _replace,
      );
      setState(
        () =>
            _status = widget.l10n.haftKhanImported(result.tasks, result.links),
      );
    } catch (error) {
      setState(() => _status = haftKhanErrorText(widget.l10n, error));
    }
  }
}

Future<bool> confirmHaftKhanAction(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: haftKhanConfirmButtonKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.commonConfirm),
        ),
      ],
    ),
  );
  return answer ?? false;
}

Future<void> runHaftKhanAction(
  BuildContext context,
  Future<String> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    final message = await action();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(haftKhanErrorText(l10n, error))),
    );
  }
}

String haftKhanErrorText(AppLocalizations l10n, Object error) {
  if (error is TaskNotFoundException) {
    return error.toString();
  }
  if (error is ArgumentError) {
    final message = error.message?.toString();
    return message == null || message.isEmpty ? error.toString() : message;
  }
  if (error is RangeError) {
    // "Invalid value(s) ..." is noise; the guard's own message is the useful part.
    final Object? invalid = error.invalidValue;
    if (invalid is String && invalid.isNotEmpty) {
      return invalid;
    }
    return error.toString();
  }
  if (error is FormatException) {
    final detail = error.message;
    return detail.isEmpty
        ? l10n.haftKhanBadPayload
        : '${l10n.haftKhanBadPayload} ($detail)';
  }
  if (error is StateError) {
    return error.message;
  }
  return error.toString();
}

const Key haftKhanSearchFieldKey = Key('haftkhan.search');
const Key haftKhanUndoButtonKey = Key('haftkhan.undo');
const Key haftKhanAddButtonKey = Key('haftkhan.add');
const Key haftKhanTitleFieldKey = Key('haftkhan.field.title');
const Key haftKhanDueFieldKey = Key('haftkhan.field.due');
const Key haftKhanSubmitButtonKey = Key('haftkhan.submit');
const Key haftKhanTransferFieldKey = Key('haftkhan.transfer.payload');
const Key haftKhanExportButtonKey = Key('haftkhan.transfer.export');
const Key haftKhanImportButtonKey = Key('haftkhan.transfer.import');
const Key haftKhanPriorityFilterKey = Key('haftkhan.filter.priority');
const Key haftKhanTagFilterKey = Key('haftkhan.filter.tag');
const Key haftKhanProjectFilterKey = Key('haftkhan.filter.project');
const Key haftKhanConfirmButtonKey = Key('haftkhan.confirm');
