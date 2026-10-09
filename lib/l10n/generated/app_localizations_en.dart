// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'JameJam';

  @override
  String get appTagline => 'A private, local-first toolbox';

  @override
  String get navDashboard => 'Home';

  @override
  String get navGreeter => 'Greeter';

  @override
  String get navHaftKhan => 'Haft Khan';

  @override
  String get navAnahita => 'Anahita';

  @override
  String get navGanjoor => 'Ganjoor';

  @override
  String get navRaz => 'Raz';

  @override
  String get navDivan => 'Divan';

  @override
  String get navTaqvim => 'Taqvim';

  @override
  String get navSoroush => 'Soroush AI';

  @override
  String get navSettings => 'Settings';

  @override
  String haftKhanConfirmRemove(int id, String title) {
    return 'Remove #$id “$title”? This cannot be undone except with Undo.';
  }

  @override
  String haftKhanConfirmClearDone(int count) {
    return 'Remove all $count conquered task(s)?';
  }

  @override
  String get haftKhanConfirmImportReplace =>
      'Importing with “replace” wipes the current store first. Continue?';

  @override
  String get anahitaTabNow => 'Now';

  @override
  String get anahitaTabForecast => 'Forecast';

  @override
  String get anahitaTabHourly => 'Hourly';

  @override
  String get anahitaTabAlerts => 'Alerts';

  @override
  String get anahitaTabBest => 'Best days';

  @override
  String get anahitaTabPlan => 'Plan';

  @override
  String get anahitaUnitsMetric => '°C';

  @override
  String get anahitaUnitsImperial => '°F';

  @override
  String get anahitaLocation => 'Location';

  @override
  String get anahitaLocationHint => 'Berlin, or 52.52,13.41';

  @override
  String get anahitaSaveLocation => 'Save place';

  @override
  String anahitaLocationSaved(String place) {
    return 'Location saved: $place — the app uses it from now on.';
  }

  @override
  String anahitaAsOf(String place, String timezone) {
    return '$place · timezone $timezone';
  }

  @override
  String get anahitaFetchFailed => 'The weather could not be fetched';

  @override
  String get anahitaNothingYet => 'Name a place and fetch the forecast.';

  @override
  String anahitaFeelsLike(String value) {
    return 'feels like $value';
  }

  @override
  String get anahitaHumidity => 'Humidity';

  @override
  String get anahitaWind => 'Wind';

  @override
  String anahitaWindDirection(String direction) {
    return '$direction';
  }

  @override
  String get anahitaPrecipitation => 'Precipitation';

  @override
  String get anahitaSun => 'Sun';

  @override
  String get anahitaUvMax => 'UV max';

  @override
  String anahitaForecastTitle(int days) {
    return '$days-day forecast';
  }

  @override
  String anahitaHourlyTitle(int hours) {
    return 'Next $hours hour(s)';
  }

  @override
  String get anahitaNoAlerts => 'Nothing to warn about in the next days.';

  @override
  String get anahitaBestTitle => 'Best days outdoors';

  @override
  String get anahitaBestSubtitle =>
      'Ranked by rain chance, temperature, wind, and storms';

  @override
  String anahitaScore(int score) {
    return 'score $score';
  }

  @override
  String get anahitaPlanTitle => 'Weather for your plans';

  @override
  String get anahitaPlanSubtitle =>
      'Open tasks grouped under their due day\'s forecast';

  @override
  String get anahitaNothingToCopy => 'Nothing to copy yet.';

  @override
  String get anahitaExplain => 'Explain';

  @override
  String get anahitaExplanationRequested =>
      'Explanation ready — check the AI screen for the full history.';

  @override
  String get anahitaAiPlan => 'AI plan';

  @override
  String get anahitaAskTitle => 'Ask about this forecast';

  @override
  String get anahitaAskSubtitle => 'The answer uses only the data above';

  @override
  String get anahitaAskLabel => 'Question';

  @override
  String get anahitaAskHint => 'Should I cycle at 6pm?';

  @override
  String get anahitaAsk => 'Ask';

  @override
  String get anahitaAnswered => 'Answer ready.';

  @override
  String get razTitle => 'Raz — encrypted vault';

  @override
  String get razSubtitle =>
      'Secrets live here in ciphertext: AES-256-GCM with a PBKDF2-HMAC-SHA512 key. Nothing leaves this device.';

  @override
  String get razCreateTitle => 'Create your vault';

  @override
  String get razUnlockTitle => 'Unlock the vault';

  @override
  String get razPassphraseHint =>
      'The passphrase is never stored in the vault — it derives the key that decrypts it.';

  @override
  String get razPassphrase => 'Passphrase';

  @override
  String get razRememberPassphrase => 'Remember in the keychain';

  @override
  String get razCreate => 'Create vault';

  @override
  String get razUnlock => 'Unlock';

  @override
  String get razVaultCreated => 'Vault created and unlocked.';

  @override
  String get razUnlocked => 'Vault unlocked.';

  @override
  String get razUseStoredPassphrase => 'Use remembered passphrase';

  @override
  String get razNoStoredPassphrase => 'No remembered passphrase — type one.';

  @override
  String get razForgetPassphrase => 'Forget';

  @override
  String get razPassphraseForgotten => 'Remembered passphrase removed.';

  @override
  String get razLocalOnly =>
      'There is no sync adapter for Raz, by design: secrets have no code path to a network transport.';

  @override
  String get razSearch => 'Search';

  @override
  String get razFilterFavorites => 'Favorites';

  @override
  String get razFilterWeak => 'Weak';

  @override
  String get razFilterExpired => 'Expired';

  @override
  String razTagFilter(Object tag) {
    return 'Tag: $tag';
  }

  @override
  String get razAddEntry => 'New entry';

  @override
  String get razEditEntry => 'Edit entry';

  @override
  String get razEntryAdded => 'Entry added.';

  @override
  String get razEntrySaved => 'Entry saved.';

  @override
  String get razEntryDeleted => 'Entry deleted — undo brings it back.';

  @override
  String get razInvalidDate => 'Dates look like yyyy-MM-dd.';

  @override
  String get razUndone => 'Last change undone.';

  @override
  String get razNothingToUndo => 'Nothing to undo.';

  @override
  String get razAudit => 'Audit';

  @override
  String get razAuditDone => 'Audit refreshed.';

  @override
  String get razAiAudit => 'Ask the coach';

  @override
  String get razExport => 'Export';

  @override
  String get razExported => 'Encrypted bundle copied to the clipboard.';

  @override
  String get razImport => 'Import';

  @override
  String get razImportTitle => 'Import a vault backup';

  @override
  String get razImportBundle => 'Encrypted bundle';

  @override
  String razImported(Object count) {
    return 'Imported $count entry(ies).';
  }

  @override
  String get razLock => 'Lock';

  @override
  String get razLocked => 'Vault locked and the key wiped from memory.';

  @override
  String get razNoEntries => 'No entries match. Add one, or clear the filters.';

  @override
  String get razUntitled => '(untitled)';

  @override
  String razExpiresOn(Object date) {
    return 'expires $date';
  }

  @override
  String razTotpValue(Object code, Object seconds) {
    return 'TOTP $code — ${seconds}s left';
  }

  @override
  String get razRevealSecret => 'Reveal';

  @override
  String get razHideSecret => 'Hide';

  @override
  String get razTotpRefresh => 'Refresh TOTP';

  @override
  String get razCopySecret => 'Copy secret';

  @override
  String get razDeleteTitle => 'Delete this entry?';

  @override
  String razDeleteMessage(Object title) {
    return '“$title” will be removed. Undo can bring it back until the vault closes.';
  }

  @override
  String get razFieldTitle => 'Title';

  @override
  String get razFieldSecret => 'Secret';

  @override
  String get razFieldUsername => 'Username';

  @override
  String get razFieldUrl => 'URL';

  @override
  String get razFieldNotes => 'Notes';

  @override
  String get razFieldTags => 'Tags (comma-separated)';

  @override
  String get razFieldExpires => 'Expires on';

  @override
  String get razFieldTotpSeed => 'TOTP seed (Base32)';

  @override
  String get razFieldTotpDigits => 'Digits';

  @override
  String get razFieldTotpPeriod => 'Period (s)';

  @override
  String get razFieldFavorite => 'Favorite';

  @override
  String get razGenerate => 'Generate a password';

  @override
  String get razAuditTitle => 'Vault health';

  @override
  String get razStatEntries => 'entries';

  @override
  String get razStatWeak => 'weak';

  @override
  String get razStatReused => 'reused';

  @override
  String get razStatExpired => 'expired';

  @override
  String get razStatExpiringSoon => 'expiring soon';

  @override
  String get razStatOld => 'stale';

  @override
  String get razStatAverageLength => 'avg length';

  @override
  String get razStatUnique => 'distinct secrets';

  @override
  String get razCoachTitle => 'Security coach';

  @override
  String get razCoachSubtitle =>
      'The coach only ever sees aggregate counts — never titles, urls, usernames, notes, seeds, or secrets.';

  @override
  String get razCoachQuestion => 'Ask about your vault hygiene';

  @override
  String get razAsk => 'Ask';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied to the clipboard';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonEmpty => 'Nothing here yet';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle =>
      'Non-secret configuration, stored in a local SQLite database';

  @override
  String get settingsKeyLabel => 'Key';

  @override
  String get settingsValueLabel => 'Value';

  @override
  String get settingsAddTitle => 'Add or update a setting';

  @override
  String get settingsSearchHint => 'Filter keys…';

  @override
  String get settingsEmpty => 'No settings saved yet.';

  @override
  String get settingsNoMatch => 'No key matches your filter.';

  @override
  String get settingsRefusedSecretTitle => 'Refused: that looks like a secret';

  @override
  String get settingsRefusedSecretBody =>
      'The settings database is plaintext. Keep API keys, tokens and passwords in the secure store instead.';

  @override
  String get settingsRemoveTitle => 'Remove this setting?';

  @override
  String get settingsRemoved => 'Setting removed';

  @override
  String get settingsSaved => 'Setting saved';

  @override
  String get settingsClearAllTitle => 'Clear every setting?';

  @override
  String get settingsClearAllBody =>
      'This removes all saved settings from this device.';

  @override
  String settingsCleared(int count) {
    return 'Cleared $count setting(s)';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow the system';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguagePersian => 'Persian (فارسی)';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'Follow the system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsDatabase => 'Database';

  @override
  String get settingsWelcome => 'Welcome to JameJam';

  @override
  String get soroushTitle => 'Soroush AI';

  @override
  String get soroushSubtitle =>
      'One safe, provider-agnostic funnel for every AI call';

  @override
  String get soroushProvider => 'Provider';

  @override
  String get soroushModel => 'Model';

  @override
  String get soroushEndpoint => 'Endpoint';

  @override
  String get soroushApiKey => 'API key';

  @override
  String get soroushApiKeyHint =>
      'Stored in the device secure store — never in the settings database';

  @override
  String get soroushApiKeySaved => 'API key saved to the secure store';

  @override
  String get soroushApiKeyCleared => 'API key removed';

  @override
  String soroushKeyConfigured(String masked) {
    return 'Key configured ($masked)';
  }

  @override
  String get soroushKeyMissing => 'No API key configured';

  @override
  String get soroushPromptHint => 'Ask Soroush anything…';

  @override
  String get soroushSend => 'Send';

  @override
  String get soroushResponse => 'Response';

  @override
  String soroushMeta(
    String provider,
    String model,
    int attempts,
    int duration,
  ) {
    return '$provider · $model · $attempts attempt(s) · $duration ms';
  }

  @override
  String get soroushHistory => 'Recent calls';

  @override
  String get soroushHistoryEmpty =>
      'No calls yet — your prompts stay on this device.';

  @override
  String get soroushClearHistory => 'Clear history';

  @override
  String get soroushHistoryCleared => 'History cleared';

  @override
  String get soroushInsecureEndpoint =>
      'Insecure endpoint refused. Use HTTPS (plain HTTP is only allowed on loopback).';

  @override
  String get soroushLocalModel => 'Loopback endpoint — no API key needed';

  @override
  String get soroushProviders => 'Known providers';

  @override
  String get greeterTitle => 'Greeter';

  @override
  String get greeterSubtitle =>
      'Friendly greetings — locally, or crafted by Soroush AI';

  @override
  String get greeterNameLabel => 'Your name';

  @override
  String get greeterNameHint => 'Leave empty to greet the world';

  @override
  String get greeterGreet => 'Greet';

  @override
  String get greeterAiGreet => 'Greet with AI';

  @override
  String get greeterDefaultName => 'Default name';

  @override
  String get greeterDefaultNameSaved => 'Default name saved';

  @override
  String get greeterGreetedWorld => 'You greeted the world';

  @override
  String greeterGreetedName(String name) {
    return 'You greeted $name';
  }

  @override
  String get greeterNeedsAiKey =>
      'The AI greeting needs an API key — add one in Soroush AI.';

  @override
  String get dashboardWelcome => 'Welcome back';

  @override
  String dashboardStep(int number) {
    return 'Step $number';
  }

  @override
  String get dashboardReady => 'Ready';

  @override
  String get dashboardPlanned => 'Planned';

  @override
  String dashboardProgress(int done, int total) {
    return '$done of $total steps implemented';
  }

  @override
  String get haftKhanTitle => 'Haft Khan — the seven labours';

  @override
  String haftKhanStatsLine(int todo, int doing, int done, int overdue) {
    return '$todo to do · $doing doing · $done done · $overdue overdue';
  }

  @override
  String haftKhanStreak(int current, int best) {
    return 'Streak $current day(s) · best $best';
  }

  @override
  String haftKhanDoneWindow(int today, int week) {
    return '$today conquered today · $week in the last 7 days';
  }

  @override
  String get haftKhanTabList => 'List';

  @override
  String get haftKhanTabBoard => 'Board';

  @override
  String get haftKhanTabMatrix => 'Matrix';

  @override
  String get haftKhanTabReport => 'Report';

  @override
  String get haftKhanViewOpen => 'Open';

  @override
  String get haftKhanViewAll => 'All';

  @override
  String get haftKhanViewDone => 'Done';

  @override
  String get haftKhanViewToday => 'Today';

  @override
  String get haftKhanViewOverdue => 'Overdue';

  @override
  String get haftKhanFilterPriority => 'Priority';

  @override
  String get haftKhanFilterTag => 'Tag';

  @override
  String get haftKhanFilterProject => 'Project';

  @override
  String get haftKhanClearFilters => 'Clear filters';

  @override
  String get haftKhanSearchHint => 'Search titles, notes, projects, tags';

  @override
  String get haftKhanEmptyView => 'No tasks in this view.';

  @override
  String get haftKhanNoMatches => 'Nothing matches that search.';

  @override
  String get haftKhanAddTask => 'Add a labour';

  @override
  String get haftKhanFieldTitle => 'Title';

  @override
  String get haftKhanFieldNotes => 'Notes';

  @override
  String get haftKhanFieldDue => 'Due';

  @override
  String get haftKhanFieldDueHint =>
      '2026-09-25, tomorrow, next monday, in 3 days';

  @override
  String get haftKhanFieldPriority => 'Priority';

  @override
  String get haftKhanFieldEffort => 'Effort';

  @override
  String get haftKhanFieldRecurrence => 'Repeats';

  @override
  String get haftKhanFieldInterval => 'Interval';

  @override
  String get haftKhanFieldProject => 'Project';

  @override
  String get haftKhanFieldTags => 'Tags';

  @override
  String get haftKhanFieldTagsHint => 'chores,quick';

  @override
  String get haftKhanFieldBlockedBy => 'Blocked by';

  @override
  String get haftKhanFieldBlockedByHint => 'task ids, e.g. 1,4';

  @override
  String get haftKhanStart => 'Start';

  @override
  String get haftKhanComplete => 'Conquer';

  @override
  String get haftKhanCompleteAnyway => 'Conquer anyway';

  @override
  String get haftKhanClearDone => 'Clear done';

  @override
  String haftKhanClearedDone(int count) {
    return 'Cleared $count completed task(s).';
  }

  @override
  String haftKhanUndoDone(String operation, int count) {
    return 'Reverted \'$operation\' ($count task(s) affected).';
  }

  @override
  String get haftKhanAiBreakdown => 'Break down with AI';

  @override
  String get haftKhanAiSummary => 'Summarise with AI';

  @override
  String haftKhanPlanHeader(int id, String title, String steps) {
    return 'Plan for #$id — $title\n$steps';
  }

  @override
  String get haftKhanTransfer => 'Import / export';

  @override
  String get haftKhanExportJson => 'Copy backup JSON';

  @override
  String get haftKhanExportMarkdown => 'Copy markdown';

  @override
  String haftKhanExported(int count) {
    return 'Copied $count task(s) to the clipboard.';
  }

  @override
  String get haftKhanExportedMarkdown => 'Copied the markdown checklist.';

  @override
  String get haftKhanImport => 'Import from the box';

  @override
  String get haftKhanImportReplace => 'Replace everything first';

  @override
  String get haftKhanTransferHint => 'Paste a backup JSON here';

  @override
  String haftKhanImported(int tasks, int links) {
    return 'Imported $tasks task(s), $links link(s).';
  }

  @override
  String get haftKhanBadPayload => 'That payload could not be read';

  @override
  String haftKhanAdded(int id, String title) {
    return 'Added #$id: $title';
  }

  @override
  String haftKhanStarted(int id, String title) {
    return 'Started #$id: $title';
  }

  @override
  String haftKhanConquered(int id, String title) {
    return 'Conquered #$id: $title';
  }

  @override
  String haftKhanRespawned(int id, String title, String due) {
    return 'Respawned #$id: $title (due $due)';
  }

  @override
  String haftKhanRemoved(int id) {
    return 'Removed #$id.';
  }

  @override
  String get haftKhanOverdueLabel => 'overdue';

  @override
  String haftKhanBlockedBy(String ids) {
    return 'blocked by $ids';
  }

  @override
  String haftKhanConqueredOn(String date) {
    return 'conquered $date';
  }

  @override
  String haftKhanEvery(int interval, String kind) {
    return 'every $interval $kind';
  }

  @override
  String get haftKhanColumnTodo => 'TODO';

  @override
  String get haftKhanColumnDoing => 'DOING';

  @override
  String get haftKhanColumnDone => 'DONE';

  @override
  String haftKhanColumnCount(int count) {
    return '$count task(s)';
  }

  @override
  String get haftKhanFocusTitle => 'Focus next';

  @override
  String get haftKhanFocusSubtitle => 'One fast, manageable step at a time';

  @override
  String formatDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get divanTitle => 'Divan — the notes pad';

  @override
  String get divanSubtitle =>
      'Markdown notes with notebooks, tags, wiki-links, checklists, a daily journal, and full-text search.';

  @override
  String divanStatNotebooks(Object count) {
    return '$count notebooks';
  }

  @override
  String divanStatNotes(Object count) {
    return '$count notes';
  }

  @override
  String divanStatWords(Object count) {
    return '$count words';
  }

  @override
  String divanStatTodos(Object count) {
    return '$count open todos';
  }

  @override
  String divanStatArchived(Object count) {
    return '$count archived';
  }

  @override
  String get divanSearchHint => 'Search the pad';

  @override
  String get divanFieldNotebook => 'Notebook';

  @override
  String get divanAllNotebooks => 'All notebooks';

  @override
  String get divanFieldTag => 'Tag';

  @override
  String get divanAllTags => 'All tags';

  @override
  String get divanFilterPinned => 'Pinned';

  @override
  String get divanFilterArchived => 'Archived';

  @override
  String get divanFilterChecklists => 'Checklists';

  @override
  String get divanClearFilters => 'Clear';

  @override
  String get divanNewNote => 'New note';

  @override
  String get divanNewNotebook => 'New notebook';

  @override
  String get divanJournal => 'Today\'s journal';

  @override
  String get divanUndo => 'Undo';

  @override
  String get divanRefresh => 'Refresh';

  @override
  String get divanTransfer => 'Markdown files';

  @override
  String get divanSync => 'Sync';

  @override
  String get divanNotebooks => 'Notebooks';

  @override
  String get divanNotes => 'Notes';

  @override
  String get divanNoNotes => 'No notes match the filters yet.';

  @override
  String get divanArchivedLabel => 'archived';

  @override
  String get divanNotebookMenu => 'Notebook actions';

  @override
  String get divanRenameNotebook => 'Rename';

  @override
  String get divanArchiveNotebook => 'Archive';

  @override
  String get divanRestoreNotebook => 'Restore';

  @override
  String get divanDelete => 'Delete';

  @override
  String get divanNoSelection => 'Pick a note on the left, or create one.';

  @override
  String get divanFieldTitle => 'Title';

  @override
  String get divanFieldTags => 'Tags';

  @override
  String get divanFieldTagsHint => 'Comma separated, e.g. work, idea';

  @override
  String get divanFieldBody => 'Body';

  @override
  String get divanFieldBodyHint =>
      'Markdown — [[wiki-links]] and - [ ] checklists work';

  @override
  String get divanSave => 'Save';

  @override
  String get divanPin => 'Pin';

  @override
  String get divanUnpin => 'Unpin';

  @override
  String get divanArchive => 'Archive';

  @override
  String get divanRestore => 'Restore';

  @override
  String divanUpdatedAt(Object stamp) {
    return 'Updated $stamp';
  }

  @override
  String divanMetricWords(Object count) {
    return '$count words';
  }

  @override
  String divanMetricCharacters(Object count) {
    return '$count characters';
  }

  @override
  String divanMetricReading(Object count) {
    return '$count s to read';
  }

  @override
  String divanMetricChecklist(int done, int total) {
    return 'Checklist $done/$total';
  }

  @override
  String divanMetricLinks(Object count) {
    return '$count links';
  }

  @override
  String get divanChecklist => 'Checklist';

  @override
  String get divanLinks => 'Wiki-links';

  @override
  String get divanBacklinks => 'Backlinks';

  @override
  String get divanBacklinksEmpty => 'Nothing links here yet.';

  @override
  String get divanTodos => 'Open todos';

  @override
  String get divanTodoHint => 'Add an item to today\'s journal';

  @override
  String get divanAdd => 'Add';

  @override
  String get divanTodosEmpty => 'No open checklist items.';

  @override
  String get divanAi => 'AI';

  @override
  String get divanAiClear => 'Clear';

  @override
  String get divanAiSummarize => 'Summarize';

  @override
  String get divanAiTitle => 'Propose a title';

  @override
  String get divanAiTags => 'Propose tags';

  @override
  String get divanAskHint => 'Ask the pad a question';

  @override
  String get divanAiAsk => 'Ask';

  @override
  String get divanAiApplyTitle => 'Use this title';

  @override
  String get divanAiApplyTags => 'Use these tags';

  @override
  String get divanStats => 'Stats';

  @override
  String divanStatsDetail(int tagged, int links) {
    return '$tagged tagged notes · $links wiki-links';
  }

  @override
  String get divanDismiss => 'Dismiss';

  @override
  String get divanTabNotes => 'Notes';

  @override
  String get divanTabEditor => 'Editor';

  @override
  String get divanTabTools => 'Tools';

  @override
  String get divanCancel => 'Cancel';

  @override
  String divanDeleteNoteTitle(Object title) {
    return 'Delete “$title”?';
  }

  @override
  String divanDeleteNotebookTitle(Object name) {
    return 'Delete “$name”?';
  }

  @override
  String get divanDeleteNotebookBody =>
      'Its notes are deleted with it — this is one undoable step.';

  @override
  String get divanDeleteUndoable => 'This is one undoable step.';

  @override
  String get divanFieldFolder => 'Folder';

  @override
  String get divanTransferHint =>
      'Export writes one .md file per active note; import reads every .md file back as a new note.';

  @override
  String get divanExport => 'Export';

  @override
  String get divanImport => 'Import';

  @override
  String get divanSyncHint =>
      'Merge keeps both devices\' changes; pull never writes the remote; push replaces it.';

  @override
  String get divanSyncMerge => 'Merge';

  @override
  String get divanSyncPull => 'Pull';

  @override
  String get divanSyncPush => 'Push';

  @override
  String get divanDefaultNotebook => 'Default notebook';

  @override
  String get divanEditorWrite => 'Write';

  @override
  String get divanEditorPreview => 'Preview';

  @override
  String get divanPreviewEmpty => 'Nothing to preview yet.';

  @override
  String get ganjoorTitle => 'Ganjoor — wallet';

  @override
  String get ganjoorTabAccounts => 'Accounts';

  @override
  String get ganjoorTabLedger => 'Ledger';

  @override
  String get ganjoorTabTools => 'Reports & plans';

  @override
  String get ganjoorTotal => 'Total';

  @override
  String get ganjoorAccounts => 'Accounts';

  @override
  String get ganjoorNoAccounts => 'No accounts yet — add one to start.';

  @override
  String get ganjoorShowArchived => 'Show archived';

  @override
  String get ganjoorAccountAdd => 'New account';

  @override
  String get ganjoorAccountName => 'Name';

  @override
  String get ganjoorAccountCurrency => 'Currency';

  @override
  String get ganjoorAccountStart => 'Starting balance';

  @override
  String get ganjoorAccountArchived => 'archived';

  @override
  String get ganjoorAccountArchive => 'Archive';

  @override
  String get ganjoorAccountUnarchive => 'Unarchive';

  @override
  String get ganjoorAccountRename => 'Rename';

  @override
  String get ganjoorAccountRemove => 'Remove account';

  @override
  String get ganjoorAccountRemoveConfirm =>
      'Remove this account and leave its history behind?';

  @override
  String get ganjoorAccountRemoveForce => 'This account holds transactions';

  @override
  String get ganjoorCancel => 'Cancel';

  @override
  String get ganjoorSave => 'Save';

  @override
  String get ganjoorConfirm => 'Confirm';

  @override
  String get ganjoorQuickAdd => 'Quick add';

  @override
  String get ganjoorKindSpend => 'Spend';

  @override
  String get ganjoorKindEarn => 'Earn';

  @override
  String get ganjoorKindTransfer => 'Transfer';

  @override
  String get ganjoorFrom => 'From';

  @override
  String get ganjoorTo => 'To';

  @override
  String get ganjoorAmount => 'Amount';

  @override
  String get ganjoorCategory => 'Category';

  @override
  String get ganjoorNotes => 'Notes';

  @override
  String get ganjoorTags => 'Tags';

  @override
  String get ganjoorDate => 'Date (yyyy-MM-dd)';

  @override
  String get ganjoorAdd => 'Add';

  @override
  String get ganjoorLedger => 'Ledger';

  @override
  String get ganjoorLedgerEmpty => 'No transactions match.';

  @override
  String get ganjoorRemoveTransaction => 'Delete transaction';

  @override
  String get ganjoorFilterAccount => 'Account';

  @override
  String get ganjoorFilterKind => 'Kind';

  @override
  String get ganjoorFilterCategory => 'Category (Enter)';

  @override
  String get ganjoorFilterAll => 'All';

  @override
  String get ganjoorFilterQuery => 'Search';

  @override
  String get ganjoorFilterClear => 'Clear filters';

  @override
  String get ganjoorPrevMonth => 'Previous month';

  @override
  String get ganjoorNextMonth => 'Next month';

  @override
  String get ganjoorBudgets => 'Budgets';

  @override
  String get ganjoorBudgetEmpty => 'No budgets set.';

  @override
  String get ganjoorBudgetSet => 'Set budget';

  @override
  String get ganjoorBudgetRemove => 'Remove budget';

  @override
  String get ganjoorBudgetLimit => 'Monthly limit';

  @override
  String get ganjoorBudgetOver => 'over budget';

  @override
  String get ganjoorBudgetClose => 'close to the limit';

  @override
  String get ganjoorBills => 'Bills';

  @override
  String get ganjoorBillEmpty => 'No bills yet.';

  @override
  String get ganjoorBillApply => 'Apply due';

  @override
  String get ganjoorBillRemove => 'Remove bill';

  @override
  String get ganjoorBillDue => 'due';

  @override
  String get ganjoorGoals => 'Goals';

  @override
  String get ganjoorGoalEmpty => 'No goals yet.';

  @override
  String get ganjoorGoalContribute => 'Add to goal';

  @override
  String get ganjoorGoalWithdraw => 'Take from goal';

  @override
  String get ganjoorGoalNearlyDone => 'almost there';

  @override
  String get ganjoorDebts => 'Debts';

  @override
  String get ganjoorDebtEmpty => 'No debts tracked.';

  @override
  String get ganjoorDebtSettle => 'Settle';

  @override
  String get ganjoorDebtRemove => 'Remove debt';

  @override
  String get ganjoorDebtOwedByMe => 'you owe';

  @override
  String get ganjoorDebtOwedToMe => 'owed by';

  @override
  String get ganjoorDebtOutstanding => 'outstanding';

  @override
  String get ganjoorDebtFullySettled => 'fully settled';

  @override
  String get ganjoorReports => 'Reports';

  @override
  String get ganjoorIncome => 'Income';

  @override
  String get ganjoorExpenses => 'Expenses';

  @override
  String get ganjoorNet => 'Net';

  @override
  String get ganjoorTopCategories => 'Top categories';

  @override
  String get ganjoorUndo => 'Undo';

  @override
  String get ganjoorRefresh => 'Refresh';

  @override
  String get ganjoorTransfer => 'Backup & files';

  @override
  String get ganjoorTransferPath => 'File path';

  @override
  String get ganjoorExportJson => 'Export JSON';

  @override
  String get ganjoorImportJson => 'Import JSON';

  @override
  String get ganjoorExportCsv => 'Export CSV';

  @override
  String get ganjoorImportCsv => 'Import CSV';

  @override
  String get ganjoorCsvAccount => 'CSV account';

  @override
  String get ganjoorAi => 'Finance assistant';

  @override
  String get ganjoorAiInsights => 'Insights';

  @override
  String get ganjoorAiAsk => 'Ask';

  @override
  String get ganjoorAiQuestion => 'Your question';

  @override
  String get ganjoorAiAnswer => 'Answer';

  @override
  String get ganjoorAiClear => 'Clear';

  @override
  String get ganjoorAiCategorize => 'Suggest a category';

  @override
  String get ganjoorAiUnavailable => 'AI is not available in this context.';

  @override
  String ganjoorCount(int count) {
    return '$count shown';
  }

  @override
  String ganjoorFromBill(int id) {
    return 'bill #$id';
  }

  @override
  String ganjoorBillNext(String date) {
    return 'next $date';
  }

  @override
  String ganjoorGoalDeadline(String date) {
    return 'by $date';
  }

  @override
  String ganjoorDebtSettled(String amount) {
    return 'settled $amount';
  }

  @override
  String ganjoorNetWorth(String total) {
    return 'Net worth: $total';
  }

  @override
  String ganjoorNetWorthBreakdown(
    String accounts,
    String receivable,
    String payable,
  ) {
    return 'accounts $accounts, owed to you $receivable, you owe $payable';
  }

  @override
  String get navSync => 'Sync';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncIntro =>
      'Two devices converge on one document per service. Each run pulls, merges by identity, then writes the merged result back — no cursors, nothing to corrupt.';

  @override
  String get syncDismiss => 'Dismiss';

  @override
  String get syncDeviceTitle => 'This device';

  @override
  String get syncDeviceHint =>
      'The identity travels inside every envelope, so the other device can tell who sealed the remote.';

  @override
  String get syncDeviceName => 'Device name';

  @override
  String get syncDeviceId => 'Device id';

  @override
  String get syncSave => 'Save';

  @override
  String get syncTokenSet => 'JAMEJAM_SYNC_TOKEN is set';

  @override
  String get syncTokenMissing =>
      'No sync token — the remote must accept anonymous writes';

  @override
  String syncServiceTag(String service, String key) {
    return 'Service tag $service · saved as $key';
  }

  @override
  String get syncUrl => 'Sync URL';

  @override
  String syncEnvOverride(String url) {
    return 'JAMEJAM_SYNC_URL wins over every saved URL: $url';
  }

  @override
  String get syncMode => 'Mode';

  @override
  String get syncModeMerge => 'Merge';

  @override
  String get syncModePull => 'Pull';

  @override
  String get syncModePush => 'Push';

  @override
  String get syncModeMergeHint =>
      'Pull, merge, and write the merged result back — both devices converge.';

  @override
  String get syncModePullHint =>
      'Pull and merge into this device only; the remote is never written.';

  @override
  String get syncModePushHint =>
      'Replace the remote with this device\'s state. It asks first when the remote holds other changes.';

  @override
  String get syncSaveUrl => 'Save URL';

  @override
  String get syncRun => 'Sync now';

  @override
  String get syncRulesTitle => 'What stays true';

  @override
  String get syncRuleHttps =>
      'HTTPS only — plain HTTP is allowed on loopback for a local server.';

  @override
  String get syncRuleToken =>
      'The bearer token comes from JAMEJAM_SYNC_TOKEN and is never stored or shown.';

  @override
  String get syncRuleConverge =>
      'Merging is deterministic and commutative, so repeated runs land on the same state on every device.';

  @override
  String get syncRuleRaz =>
      'Raz never syncs: the vault is encrypted on this device and has no adapter, by design.';

  @override
  String get syncProtocol =>
      'Wire protocol: jamejam.sync/1 · one service per URL';

  @override
  String get syncOverwriteTitle => 'Overwrite the remote?';

  @override
  String get syncOverwrite => 'Overwrite';

  @override
  String get syncCancel => 'Cancel';

  @override
  String get syncDeviceIdPending => 'Created by the first sync';

  @override
  String get taqvimAgendaTitle => 'Agenda';

  @override
  String get taqvimAgendaSubtitle =>
      'Events in the chosen scope, with this calendar\'s own conflicts flagged.';

  @override
  String get taqvimAgendaEmpty => 'Nothing scheduled in this scope.';

  @override
  String get taqvimPreviousDay => 'Previous day';

  @override
  String get taqvimNextDay => 'Next day';

  @override
  String get taqvimRefresh => 'Reload';

  @override
  String get taqvimUndo => 'Undo the last change';

  @override
  String get taqvimFilterCalendar => 'Calendar';

  @override
  String get taqvimFilterTag => 'Tag';

  @override
  String get taqvimFilterApply => 'Filter';

  @override
  String taqvimConflictCount(int count) {
    return '$count conflict(s)';
  }

  @override
  String taqvimStatEvents(int count) {
    return '$count events';
  }

  @override
  String taqvimStatRecurring(int count) {
    return '$count repeating';
  }

  @override
  String taqvimStatAllDay(int count) {
    return '$count all-day';
  }

  @override
  String taqvimStatTagged(int count) {
    return '$count tagged';
  }

  @override
  String taqvimStatReminders(int count) {
    return '$count reminders';
  }

  @override
  String taqvimStatNextSevenDays(int count) {
    return '$count in the next 7 days';
  }

  @override
  String taqvimStatBusyMinutes(int minutes) {
    return '$minutes busy minutes';
  }

  @override
  String get taqvimCaptureTitle => 'Quick capture';

  @override
  String get taqvimCaptureSubtitle =>
      'Write a sentence; the parser fills the editor. Nothing is invented when the sentence carries no date or time.';

  @override
  String get taqvimCaptureHint => 'lunch with Sara next Tuesday at 1pm';

  @override
  String get taqvimCaptureAction => 'Capture';

  @override
  String get taqvimEditorNewTitle => 'New event';

  @override
  String taqvimEditorEditTitle(int id) {
    return 'Event #$id';
  }

  @override
  String get taqvimEditorSubtitle =>
      'The same rails as the CLI: a title, an end after the start, bounded tags and reminders.';

  @override
  String get taqvimEditorNewAction => 'New';

  @override
  String get taqvimFieldTitle => 'Title';

  @override
  String get taqvimFieldStart => 'Start';

  @override
  String get taqvimFieldEnd => 'End';

  @override
  String get taqvimWhenHint => '2026-09-21 14:30, 2026-09-21, or 14:30';

  @override
  String get taqvimFieldAllDay => 'All day';

  @override
  String get taqvimFieldCalendar => 'Calendar';

  @override
  String get taqvimFieldLocation => 'Location';

  @override
  String get taqvimFieldTags => 'Tags';

  @override
  String get taqvimTagsHint => 'work, deep';

  @override
  String get taqvimFieldNotes => 'Notes';

  @override
  String get taqvimFieldRepeat => 'Repeat';

  @override
  String get taqvimFieldRepeatInterval => 'Every N';

  @override
  String get taqvimFieldReminders => 'Remind (minutes before)';

  @override
  String get taqvimRemindersHint => '30, 10';

  @override
  String get taqvimRepeatOnce => 'Once';

  @override
  String get taqvimRepeatDaily => 'Daily';

  @override
  String get taqvimRepeatWeekly => 'Weekly';

  @override
  String get taqvimRepeatMonthly => 'Monthly';

  @override
  String get taqvimRepeatYearly => 'Yearly';

  @override
  String get taqvimSaveAdd => 'Add event';

  @override
  String get taqvimSaveEdit => 'Save changes';

  @override
  String get taqvimDeleteAction => 'Delete';

  @override
  String get taqvimDeleteConfirmTitle => 'Delete this event?';

  @override
  String get taqvimDeleteConfirmBody =>
      'The deletion is recorded so other devices learn of it. Undo restores it.';

  @override
  String get taqvimScopeToday => 'Today';

  @override
  String get taqvimScopeTomorrow => 'Tomorrow';

  @override
  String get taqvimScopeWeek => 'This week';

  @override
  String get taqvimScopeMonth => 'This month';

  @override
  String get taqvimScopeUpcoming => 'Upcoming';

  @override
  String get taqvimSearchTitle => 'Search';

  @override
  String get taqvimSearchSubtitle =>
      'Full text over titles, notes and locations — every term must match.';

  @override
  String get taqvimSearchHint => 'dentist x-rays';

  @override
  String get taqvimSearchAction => 'Search';

  @override
  String get taqvimSearchEmpty => 'No search yet.';

  @override
  String get taqvimWindowsTitle => 'Free windows';

  @override
  String get taqvimWindowsSubtitle =>
      'The gaps between events inside a window of the day; clashes are flagged under the agenda.';

  @override
  String get taqvimFieldDay => 'Day';

  @override
  String get taqvimDayHint => '2026-09-21';

  @override
  String get taqvimFieldFrom => 'From';

  @override
  String get taqvimFieldTo => 'To';

  @override
  String get taqvimFieldMinutes => 'Min';

  @override
  String get taqvimFreeAction => 'Find free windows';

  @override
  String get taqvimFreeEmpty => 'No free windows computed yet.';

  @override
  String taqvimFreeMinutesLabel(int minutes) {
    return '$minutes min free';
  }

  @override
  String get taqvimTransferTitle => 'Import and export (.ics)';

  @override
  String get taqvimTransferSubtitle =>
      'One document, at most 2000 events, timestamps in UTC.';

  @override
  String get taqvimTransferAction => 'Open the .ics box';

  @override
  String get taqvimTransferBody =>
      'Paste an .ics document to import, or fill the box with the current export.';

  @override
  String get taqvimExportAction => 'Fill with export';

  @override
  String get taqvimImportAction => 'Import';

  @override
  String get taqvimCopyAction => 'Copy';

  @override
  String get taqvimAiTitle => 'Schedule assistant';

  @override
  String get taqvimAiSubtitle =>
      'Prompts carry the agenda inside ---EVENT BEGIN--- markers and say the text within is untrusted.';

  @override
  String get taqvimAiBrief => 'Brief the day';

  @override
  String get taqvimAiPlan => 'Plan the week';

  @override
  String get taqvimAiCapture => 'Suggest a command';

  @override
  String get taqvimAiAsk => 'Ask';

  @override
  String get taqvimAiAskHint => 'when is my next free hour?';

  @override
  String get taqvimAiEmpty => 'No answer yet.';

  @override
  String taqvimAiSuggestion(String command) {
    return 'Suggestion (copy, check, then run): $command';
  }

  @override
  String get settingsClearFilter => 'Clear the filter';

  @override
  String get soroushShowKey => 'Show the key';

  @override
  String get soroushHideKey => 'Hide the key';

  @override
  String get a11yToolboxGrid => 'The toolbox steps';

  @override
  String get a11yCalendarAgenda => 'Agenda';

  @override
  String get settingsMigrate => 'Bring data across from the .NET toolbox';

  @override
  String get migrationTitle => 'Bring your data across';

  @override
  String get migrationSubtitle =>
      'Read a file the .NET toolbox exported, so nothing has to be retyped.';

  @override
  String get migrationPaste => 'Paste from clipboard';

  @override
  String get migrationTextLabel => 'The exported file';

  @override
  String get migrationTextHint =>
      'Paste a .json backup or an .ics calendar here';

  @override
  String get migrationImport => 'Import';

  @override
  String get migrationNothing => 'Nothing pasted yet.';

  @override
  String get migrationNotJson => 'This is neither JSON nor an .ics document.';

  @override
  String get migrationNotADocument =>
      'This JSON is not a document this app can read.';

  @override
  String get migrationKindHaftKhan => 'Haft Khan backup';

  @override
  String get migrationKindGanjoor => 'Ganjoor wallet backup';

  @override
  String get migrationKindRaz => 'Raz vault bundle';

  @override
  String get migrationKindTaqvim => 'Taqvim calendar (.ics)';

  @override
  String get migrationNoteHaftKhan =>
      'Haft Khan: the .json written by haftkhan export (versions 1 and 2).';

  @override
  String get migrationNoteGanjoor =>
      'Ganjoor: the .json written by ganjoor export.';

  @override
  String get migrationNoteRaz =>
      'Raz: the .json written by raz export — unlock the vault first; the bundle opens under the passphrase it was made with.';

  @override
  String get migrationNoteTaqvim =>
      'Taqvim: the .ics written by taqvim export.';

  @override
  String get migrationNoteLocal =>
      'Divan reads a folder of markdown files from its own transfer panel, and the SQLite files keep the names and shapes the .NET wrote — an existing ~/.jamejam folder is read in place.';

  @override
  String migrationVersion(int version) {
    return 'version $version';
  }

  @override
  String migrationTasks(int count) {
    return '$count task(s)';
  }

  @override
  String migrationLinks(int count) {
    return '$count link(s)';
  }

  @override
  String migrationAccounts(int count) {
    return '$count account(s)';
  }

  @override
  String migrationTransactions(int count) {
    return '$count transaction(s)';
  }

  @override
  String migrationBudgets(int count) {
    return '$count budget(s)';
  }

  @override
  String migrationEvents(int count) {
    return '$count event(s)';
  }

  @override
  String migrationResult(String kind, int count) {
    return 'Imported $kind: $count record(s).';
  }
}
