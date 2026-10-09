import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// The application name.
  ///
  /// In en, this message translates to:
  /// **'JameJam'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'A private, local-first toolbox'**
  String get appTagline;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navDashboard;

  /// No description provided for @navGreeter.
  ///
  /// In en, this message translates to:
  /// **'Greeter'**
  String get navGreeter;

  /// No description provided for @navHaftKhan.
  ///
  /// In en, this message translates to:
  /// **'Haft Khan'**
  String get navHaftKhan;

  /// No description provided for @navAnahita.
  ///
  /// In en, this message translates to:
  /// **'Anahita'**
  String get navAnahita;

  /// No description provided for @navGanjoor.
  ///
  /// In en, this message translates to:
  /// **'Ganjoor'**
  String get navGanjoor;

  /// No description provided for @navRaz.
  ///
  /// In en, this message translates to:
  /// **'Raz'**
  String get navRaz;

  /// No description provided for @navDivan.
  ///
  /// In en, this message translates to:
  /// **'Divan'**
  String get navDivan;

  /// No description provided for @navTaqvim.
  ///
  /// In en, this message translates to:
  /// **'Taqvim'**
  String get navTaqvim;

  /// No description provided for @navSoroush.
  ///
  /// In en, this message translates to:
  /// **'Soroush AI'**
  String get navSoroush;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @haftKhanConfirmRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove #{id} “{title}”? This cannot be undone except with Undo.'**
  String haftKhanConfirmRemove(int id, String title);

  /// No description provided for @haftKhanConfirmClearDone.
  ///
  /// In en, this message translates to:
  /// **'Remove all {count} conquered task(s)?'**
  String haftKhanConfirmClearDone(int count);

  /// No description provided for @haftKhanConfirmImportReplace.
  ///
  /// In en, this message translates to:
  /// **'Importing with “replace” wipes the current store first. Continue?'**
  String get haftKhanConfirmImportReplace;

  /// No description provided for @anahitaTabNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get anahitaTabNow;

  /// No description provided for @anahitaTabForecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get anahitaTabForecast;

  /// No description provided for @anahitaTabHourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get anahitaTabHourly;

  /// No description provided for @anahitaTabAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get anahitaTabAlerts;

  /// No description provided for @anahitaTabBest.
  ///
  /// In en, this message translates to:
  /// **'Best days'**
  String get anahitaTabBest;

  /// No description provided for @anahitaTabPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get anahitaTabPlan;

  /// No description provided for @anahitaUnitsMetric.
  ///
  /// In en, this message translates to:
  /// **'°C'**
  String get anahitaUnitsMetric;

  /// No description provided for @anahitaUnitsImperial.
  ///
  /// In en, this message translates to:
  /// **'°F'**
  String get anahitaUnitsImperial;

  /// No description provided for @anahitaLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get anahitaLocation;

  /// No description provided for @anahitaLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Berlin, or 52.52,13.41'**
  String get anahitaLocationHint;

  /// No description provided for @anahitaSaveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save place'**
  String get anahitaSaveLocation;

  /// No description provided for @anahitaLocationSaved.
  ///
  /// In en, this message translates to:
  /// **'Location saved: {place} — the app uses it from now on.'**
  String anahitaLocationSaved(String place);

  /// No description provided for @anahitaAsOf.
  ///
  /// In en, this message translates to:
  /// **'{place} · timezone {timezone}'**
  String anahitaAsOf(String place, String timezone);

  /// No description provided for @anahitaFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'The weather could not be fetched'**
  String get anahitaFetchFailed;

  /// No description provided for @anahitaNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Name a place and fetch the forecast.'**
  String get anahitaNothingYet;

  /// No description provided for @anahitaFeelsLike.
  ///
  /// In en, this message translates to:
  /// **'feels like {value}'**
  String anahitaFeelsLike(String value);

  /// No description provided for @anahitaHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get anahitaHumidity;

  /// No description provided for @anahitaWind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get anahitaWind;

  /// No description provided for @anahitaWindDirection.
  ///
  /// In en, this message translates to:
  /// **'{direction}'**
  String anahitaWindDirection(String direction);

  /// No description provided for @anahitaPrecipitation.
  ///
  /// In en, this message translates to:
  /// **'Precipitation'**
  String get anahitaPrecipitation;

  /// No description provided for @anahitaSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get anahitaSun;

  /// No description provided for @anahitaUvMax.
  ///
  /// In en, this message translates to:
  /// **'UV max'**
  String get anahitaUvMax;

  /// No description provided for @anahitaForecastTitle.
  ///
  /// In en, this message translates to:
  /// **'{days}-day forecast'**
  String anahitaForecastTitle(int days);

  /// No description provided for @anahitaHourlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Next {hours} hour(s)'**
  String anahitaHourlyTitle(int hours);

  /// No description provided for @anahitaNoAlerts.
  ///
  /// In en, this message translates to:
  /// **'Nothing to warn about in the next days.'**
  String get anahitaNoAlerts;

  /// No description provided for @anahitaBestTitle.
  ///
  /// In en, this message translates to:
  /// **'Best days outdoors'**
  String get anahitaBestTitle;

  /// No description provided for @anahitaBestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ranked by rain chance, temperature, wind, and storms'**
  String get anahitaBestSubtitle;

  /// No description provided for @anahitaScore.
  ///
  /// In en, this message translates to:
  /// **'score {score}'**
  String anahitaScore(int score);

  /// No description provided for @anahitaPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather for your plans'**
  String get anahitaPlanTitle;

  /// No description provided for @anahitaPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open tasks grouped under their due day\'s forecast'**
  String get anahitaPlanSubtitle;

  /// No description provided for @anahitaNothingToCopy.
  ///
  /// In en, this message translates to:
  /// **'Nothing to copy yet.'**
  String get anahitaNothingToCopy;

  /// No description provided for @anahitaExplain.
  ///
  /// In en, this message translates to:
  /// **'Explain'**
  String get anahitaExplain;

  /// No description provided for @anahitaExplanationRequested.
  ///
  /// In en, this message translates to:
  /// **'Explanation ready — check the AI screen for the full history.'**
  String get anahitaExplanationRequested;

  /// No description provided for @anahitaAiPlan.
  ///
  /// In en, this message translates to:
  /// **'AI plan'**
  String get anahitaAiPlan;

  /// No description provided for @anahitaAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about this forecast'**
  String get anahitaAskTitle;

  /// No description provided for @anahitaAskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The answer uses only the data above'**
  String get anahitaAskSubtitle;

  /// No description provided for @anahitaAskLabel.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get anahitaAskLabel;

  /// No description provided for @anahitaAskHint.
  ///
  /// In en, this message translates to:
  /// **'Should I cycle at 6pm?'**
  String get anahitaAskHint;

  /// No description provided for @anahitaAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get anahitaAsk;

  /// No description provided for @anahitaAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answer ready.'**
  String get anahitaAnswered;

  /// No description provided for @razTitle.
  ///
  /// In en, this message translates to:
  /// **'Raz — encrypted vault'**
  String get razTitle;

  /// No description provided for @razSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secrets live here in ciphertext: AES-256-GCM with a PBKDF2-HMAC-SHA512 key. Nothing leaves this device.'**
  String get razSubtitle;

  /// No description provided for @razCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your vault'**
  String get razCreateTitle;

  /// No description provided for @razUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock the vault'**
  String get razUnlockTitle;

  /// No description provided for @razPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'The passphrase is never stored in the vault — it derives the key that decrypts it.'**
  String get razPassphraseHint;

  /// No description provided for @razPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get razPassphrase;

  /// No description provided for @razRememberPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Remember in the keychain'**
  String get razRememberPassphrase;

  /// No description provided for @razCreate.
  ///
  /// In en, this message translates to:
  /// **'Create vault'**
  String get razCreate;

  /// No description provided for @razUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get razUnlock;

  /// No description provided for @razVaultCreated.
  ///
  /// In en, this message translates to:
  /// **'Vault created and unlocked.'**
  String get razVaultCreated;

  /// No description provided for @razUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Vault unlocked.'**
  String get razUnlocked;

  /// No description provided for @razUseStoredPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Use remembered passphrase'**
  String get razUseStoredPassphrase;

  /// No description provided for @razNoStoredPassphrase.
  ///
  /// In en, this message translates to:
  /// **'No remembered passphrase — type one.'**
  String get razNoStoredPassphrase;

  /// No description provided for @razForgetPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get razForgetPassphrase;

  /// No description provided for @razPassphraseForgotten.
  ///
  /// In en, this message translates to:
  /// **'Remembered passphrase removed.'**
  String get razPassphraseForgotten;

  /// No description provided for @razLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'There is no sync adapter for Raz, by design: secrets have no code path to a network transport.'**
  String get razLocalOnly;

  /// No description provided for @razSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get razSearch;

  /// No description provided for @razFilterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get razFilterFavorites;

  /// No description provided for @razFilterWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get razFilterWeak;

  /// No description provided for @razFilterExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get razFilterExpired;

  /// No description provided for @razTagFilter.
  ///
  /// In en, this message translates to:
  /// **'Tag: {tag}'**
  String razTagFilter(Object tag);

  /// No description provided for @razAddEntry.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get razAddEntry;

  /// No description provided for @razEditEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get razEditEntry;

  /// No description provided for @razEntryAdded.
  ///
  /// In en, this message translates to:
  /// **'Entry added.'**
  String get razEntryAdded;

  /// No description provided for @razEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Entry saved.'**
  String get razEntrySaved;

  /// No description provided for @razEntryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Entry deleted — undo brings it back.'**
  String get razEntryDeleted;

  /// No description provided for @razInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Dates look like yyyy-MM-dd.'**
  String get razInvalidDate;

  /// No description provided for @razUndone.
  ///
  /// In en, this message translates to:
  /// **'Last change undone.'**
  String get razUndone;

  /// No description provided for @razNothingToUndo.
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo.'**
  String get razNothingToUndo;

  /// No description provided for @razAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get razAudit;

  /// No description provided for @razAuditDone.
  ///
  /// In en, this message translates to:
  /// **'Audit refreshed.'**
  String get razAuditDone;

  /// No description provided for @razAiAudit.
  ///
  /// In en, this message translates to:
  /// **'Ask the coach'**
  String get razAiAudit;

  /// No description provided for @razExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get razExport;

  /// No description provided for @razExported.
  ///
  /// In en, this message translates to:
  /// **'Encrypted bundle copied to the clipboard.'**
  String get razExported;

  /// No description provided for @razImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get razImport;

  /// No description provided for @razImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import a vault backup'**
  String get razImportTitle;

  /// No description provided for @razImportBundle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted bundle'**
  String get razImportBundle;

  /// No description provided for @razImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} entry(ies).'**
  String razImported(Object count);

  /// No description provided for @razLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get razLock;

  /// No description provided for @razLocked.
  ///
  /// In en, this message translates to:
  /// **'Vault locked and the key wiped from memory.'**
  String get razLocked;

  /// No description provided for @razNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries match. Add one, or clear the filters.'**
  String get razNoEntries;

  /// No description provided for @razUntitled.
  ///
  /// In en, this message translates to:
  /// **'(untitled)'**
  String get razUntitled;

  /// No description provided for @razExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'expires {date}'**
  String razExpiresOn(Object date);

  /// No description provided for @razTotpValue.
  ///
  /// In en, this message translates to:
  /// **'TOTP {code} — {seconds}s left'**
  String razTotpValue(Object code, Object seconds);

  /// No description provided for @razRevealSecret.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get razRevealSecret;

  /// No description provided for @razHideSecret.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get razHideSecret;

  /// No description provided for @razTotpRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh TOTP'**
  String get razTotpRefresh;

  /// No description provided for @razCopySecret.
  ///
  /// In en, this message translates to:
  /// **'Copy secret'**
  String get razCopySecret;

  /// No description provided for @razDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get razDeleteTitle;

  /// No description provided for @razDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed. Undo can bring it back until the vault closes.'**
  String razDeleteMessage(Object title);

  /// No description provided for @razFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get razFieldTitle;

  /// No description provided for @razFieldSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get razFieldSecret;

  /// No description provided for @razFieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get razFieldUsername;

  /// No description provided for @razFieldUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get razFieldUrl;

  /// No description provided for @razFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get razFieldNotes;

  /// No description provided for @razFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma-separated)'**
  String get razFieldTags;

  /// No description provided for @razFieldExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires on'**
  String get razFieldExpires;

  /// No description provided for @razFieldTotpSeed.
  ///
  /// In en, this message translates to:
  /// **'TOTP seed (Base32)'**
  String get razFieldTotpSeed;

  /// No description provided for @razFieldTotpDigits.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get razFieldTotpDigits;

  /// No description provided for @razFieldTotpPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period (s)'**
  String get razFieldTotpPeriod;

  /// No description provided for @razFieldFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get razFieldFavorite;

  /// No description provided for @razGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate a password'**
  String get razGenerate;

  /// No description provided for @razAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault health'**
  String get razAuditTitle;

  /// No description provided for @razStatEntries.
  ///
  /// In en, this message translates to:
  /// **'entries'**
  String get razStatEntries;

  /// No description provided for @razStatWeak.
  ///
  /// In en, this message translates to:
  /// **'weak'**
  String get razStatWeak;

  /// No description provided for @razStatReused.
  ///
  /// In en, this message translates to:
  /// **'reused'**
  String get razStatReused;

  /// No description provided for @razStatExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get razStatExpired;

  /// No description provided for @razStatExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'expiring soon'**
  String get razStatExpiringSoon;

  /// No description provided for @razStatOld.
  ///
  /// In en, this message translates to:
  /// **'stale'**
  String get razStatOld;

  /// No description provided for @razStatAverageLength.
  ///
  /// In en, this message translates to:
  /// **'avg length'**
  String get razStatAverageLength;

  /// No description provided for @razStatUnique.
  ///
  /// In en, this message translates to:
  /// **'distinct secrets'**
  String get razStatUnique;

  /// No description provided for @razCoachTitle.
  ///
  /// In en, this message translates to:
  /// **'Security coach'**
  String get razCoachTitle;

  /// No description provided for @razCoachSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The coach only ever sees aggregate counts — never titles, urls, usernames, notes, seeds, or secrets.'**
  String get razCoachSubtitle;

  /// No description provided for @razCoachQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask about your vault hygiene'**
  String get razCoachQuestion;

  /// No description provided for @razAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get razAsk;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard'**
  String get commonCopied;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get commonEmpty;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Non-secret configuration, stored in a local SQLite database'**
  String get settingsSubtitle;

  /// No description provided for @settingsKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get settingsKeyLabel;

  /// No description provided for @settingsValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get settingsValueLabel;

  /// No description provided for @settingsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add or update a setting'**
  String get settingsAddTitle;

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Filter keys…'**
  String get settingsSearchHint;

  /// No description provided for @settingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No settings saved yet.'**
  String get settingsEmpty;

  /// No description provided for @settingsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No key matches your filter.'**
  String get settingsNoMatch;

  /// No description provided for @settingsRefusedSecretTitle.
  ///
  /// In en, this message translates to:
  /// **'Refused: that looks like a secret'**
  String get settingsRefusedSecretTitle;

  /// No description provided for @settingsRefusedSecretBody.
  ///
  /// In en, this message translates to:
  /// **'The settings database is plaintext. Keep API keys, tokens and passwords in the secure store instead.'**
  String get settingsRefusedSecretBody;

  /// No description provided for @settingsRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this setting?'**
  String get settingsRemoveTitle;

  /// No description provided for @settingsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Setting removed'**
  String get settingsRemoved;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Setting saved'**
  String get settingsSaved;

  /// No description provided for @settingsClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear every setting?'**
  String get settingsClearAllTitle;

  /// No description provided for @settingsClearAllBody.
  ///
  /// In en, this message translates to:
  /// **'This removes all saved settings from this device.'**
  String get settingsClearAllBody;

  /// No description provided for @settingsCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared {count} setting(s)'**
  String settingsCleared(int count);

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the system'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguagePersian.
  ///
  /// In en, this message translates to:
  /// **'Persian (فارسی)'**
  String get settingsLanguagePersian;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the system'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get settingsDatabase;

  /// No description provided for @settingsWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to JameJam'**
  String get settingsWelcome;

  /// No description provided for @soroushTitle.
  ///
  /// In en, this message translates to:
  /// **'Soroush AI'**
  String get soroushTitle;

  /// No description provided for @soroushSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One safe, provider-agnostic funnel for every AI call'**
  String get soroushSubtitle;

  /// No description provided for @soroushProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get soroushProvider;

  /// No description provided for @soroushModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get soroushModel;

  /// No description provided for @soroushEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get soroushEndpoint;

  /// No description provided for @soroushApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get soroushApiKey;

  /// No description provided for @soroushApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Stored in the device secure store — never in the settings database'**
  String get soroushApiKeyHint;

  /// No description provided for @soroushApiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'API key saved to the secure store'**
  String get soroushApiKeySaved;

  /// No description provided for @soroushApiKeyCleared.
  ///
  /// In en, this message translates to:
  /// **'API key removed'**
  String get soroushApiKeyCleared;

  /// No description provided for @soroushKeyConfigured.
  ///
  /// In en, this message translates to:
  /// **'Key configured ({masked})'**
  String soroushKeyConfigured(String masked);

  /// No description provided for @soroushKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'No API key configured'**
  String get soroushKeyMissing;

  /// No description provided for @soroushPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Ask Soroush anything…'**
  String get soroushPromptHint;

  /// No description provided for @soroushSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get soroushSend;

  /// No description provided for @soroushResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get soroushResponse;

  /// No description provided for @soroushMeta.
  ///
  /// In en, this message translates to:
  /// **'{provider} · {model} · {attempts} attempt(s) · {duration} ms'**
  String soroushMeta(String provider, String model, int attempts, int duration);

  /// No description provided for @soroushHistory.
  ///
  /// In en, this message translates to:
  /// **'Recent calls'**
  String get soroushHistory;

  /// No description provided for @soroushHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No calls yet — your prompts stay on this device.'**
  String get soroushHistoryEmpty;

  /// No description provided for @soroushClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get soroushClearHistory;

  /// No description provided for @soroushHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get soroushHistoryCleared;

  /// No description provided for @soroushInsecureEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Insecure endpoint refused. Use HTTPS (plain HTTP is only allowed on loopback).'**
  String get soroushInsecureEndpoint;

  /// No description provided for @soroushLocalModel.
  ///
  /// In en, this message translates to:
  /// **'Loopback endpoint — no API key needed'**
  String get soroushLocalModel;

  /// No description provided for @soroushProviders.
  ///
  /// In en, this message translates to:
  /// **'Known providers'**
  String get soroushProviders;

  /// No description provided for @greeterTitle.
  ///
  /// In en, this message translates to:
  /// **'Greeter'**
  String get greeterTitle;

  /// No description provided for @greeterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Friendly greetings — locally, or crafted by Soroush AI'**
  String get greeterSubtitle;

  /// No description provided for @greeterNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get greeterNameLabel;

  /// No description provided for @greeterNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to greet the world'**
  String get greeterNameHint;

  /// No description provided for @greeterGreet.
  ///
  /// In en, this message translates to:
  /// **'Greet'**
  String get greeterGreet;

  /// No description provided for @greeterAiGreet.
  ///
  /// In en, this message translates to:
  /// **'Greet with AI'**
  String get greeterAiGreet;

  /// No description provided for @greeterDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Default name'**
  String get greeterDefaultName;

  /// No description provided for @greeterDefaultNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Default name saved'**
  String get greeterDefaultNameSaved;

  /// No description provided for @greeterGreetedWorld.
  ///
  /// In en, this message translates to:
  /// **'You greeted the world'**
  String get greeterGreetedWorld;

  /// No description provided for @greeterGreetedName.
  ///
  /// In en, this message translates to:
  /// **'You greeted {name}'**
  String greeterGreetedName(String name);

  /// No description provided for @greeterNeedsAiKey.
  ///
  /// In en, this message translates to:
  /// **'The AI greeting needs an API key — add one in Soroush AI.'**
  String get greeterNeedsAiKey;

  /// No description provided for @dashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get dashboardWelcome;

  /// No description provided for @dashboardStep.
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String dashboardStep(int number);

  /// No description provided for @dashboardReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get dashboardReady;

  /// No description provided for @dashboardPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get dashboardPlanned;

  /// No description provided for @dashboardProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} steps implemented'**
  String dashboardProgress(int done, int total);

  /// No description provided for @haftKhanTitle.
  ///
  /// In en, this message translates to:
  /// **'Haft Khan — the seven labours'**
  String get haftKhanTitle;

  /// No description provided for @haftKhanStatsLine.
  ///
  /// In en, this message translates to:
  /// **'{todo} to do · {doing} doing · {done} done · {overdue} overdue'**
  String haftKhanStatsLine(int todo, int doing, int done, int overdue);

  /// No description provided for @haftKhanStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak {current} day(s) · best {best}'**
  String haftKhanStreak(int current, int best);

  /// No description provided for @haftKhanDoneWindow.
  ///
  /// In en, this message translates to:
  /// **'{today} conquered today · {week} in the last 7 days'**
  String haftKhanDoneWindow(int today, int week);

  /// No description provided for @haftKhanTabList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get haftKhanTabList;

  /// No description provided for @haftKhanTabBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get haftKhanTabBoard;

  /// No description provided for @haftKhanTabMatrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix'**
  String get haftKhanTabMatrix;

  /// No description provided for @haftKhanTabReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get haftKhanTabReport;

  /// No description provided for @haftKhanViewOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get haftKhanViewOpen;

  /// No description provided for @haftKhanViewAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get haftKhanViewAll;

  /// No description provided for @haftKhanViewDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get haftKhanViewDone;

  /// No description provided for @haftKhanViewToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get haftKhanViewToday;

  /// No description provided for @haftKhanViewOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get haftKhanViewOverdue;

  /// No description provided for @haftKhanFilterPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get haftKhanFilterPriority;

  /// No description provided for @haftKhanFilterTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get haftKhanFilterTag;

  /// No description provided for @haftKhanFilterProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get haftKhanFilterProject;

  /// No description provided for @haftKhanClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get haftKhanClearFilters;

  /// No description provided for @haftKhanSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles, notes, projects, tags'**
  String get haftKhanSearchHint;

  /// No description provided for @haftKhanEmptyView.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this view.'**
  String get haftKhanEmptyView;

  /// No description provided for @haftKhanNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that search.'**
  String get haftKhanNoMatches;

  /// No description provided for @haftKhanAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add a labour'**
  String get haftKhanAddTask;

  /// No description provided for @haftKhanFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get haftKhanFieldTitle;

  /// No description provided for @haftKhanFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get haftKhanFieldNotes;

  /// No description provided for @haftKhanFieldDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get haftKhanFieldDue;

  /// No description provided for @haftKhanFieldDueHint.
  ///
  /// In en, this message translates to:
  /// **'2026-09-25, tomorrow, next monday, in 3 days'**
  String get haftKhanFieldDueHint;

  /// No description provided for @haftKhanFieldPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get haftKhanFieldPriority;

  /// No description provided for @haftKhanFieldEffort.
  ///
  /// In en, this message translates to:
  /// **'Effort'**
  String get haftKhanFieldEffort;

  /// No description provided for @haftKhanFieldRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get haftKhanFieldRecurrence;

  /// No description provided for @haftKhanFieldInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get haftKhanFieldInterval;

  /// No description provided for @haftKhanFieldProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get haftKhanFieldProject;

  /// No description provided for @haftKhanFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get haftKhanFieldTags;

  /// No description provided for @haftKhanFieldTagsHint.
  ///
  /// In en, this message translates to:
  /// **'chores,quick'**
  String get haftKhanFieldTagsHint;

  /// No description provided for @haftKhanFieldBlockedBy.
  ///
  /// In en, this message translates to:
  /// **'Blocked by'**
  String get haftKhanFieldBlockedBy;

  /// No description provided for @haftKhanFieldBlockedByHint.
  ///
  /// In en, this message translates to:
  /// **'task ids, e.g. 1,4'**
  String get haftKhanFieldBlockedByHint;

  /// No description provided for @haftKhanStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get haftKhanStart;

  /// No description provided for @haftKhanComplete.
  ///
  /// In en, this message translates to:
  /// **'Conquer'**
  String get haftKhanComplete;

  /// No description provided for @haftKhanCompleteAnyway.
  ///
  /// In en, this message translates to:
  /// **'Conquer anyway'**
  String get haftKhanCompleteAnyway;

  /// No description provided for @haftKhanClearDone.
  ///
  /// In en, this message translates to:
  /// **'Clear done'**
  String get haftKhanClearDone;

  /// No description provided for @haftKhanClearedDone.
  ///
  /// In en, this message translates to:
  /// **'Cleared {count} completed task(s).'**
  String haftKhanClearedDone(int count);

  /// No description provided for @haftKhanUndoDone.
  ///
  /// In en, this message translates to:
  /// **'Reverted \'{operation}\' ({count} task(s) affected).'**
  String haftKhanUndoDone(String operation, int count);

  /// No description provided for @haftKhanAiBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Break down with AI'**
  String get haftKhanAiBreakdown;

  /// No description provided for @haftKhanAiSummary.
  ///
  /// In en, this message translates to:
  /// **'Summarise with AI'**
  String get haftKhanAiSummary;

  /// No description provided for @haftKhanPlanHeader.
  ///
  /// In en, this message translates to:
  /// **'Plan for #{id} — {title}\n{steps}'**
  String haftKhanPlanHeader(int id, String title, String steps);

  /// No description provided for @haftKhanTransfer.
  ///
  /// In en, this message translates to:
  /// **'Import / export'**
  String get haftKhanTransfer;

  /// No description provided for @haftKhanExportJson.
  ///
  /// In en, this message translates to:
  /// **'Copy backup JSON'**
  String get haftKhanExportJson;

  /// No description provided for @haftKhanExportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy markdown'**
  String get haftKhanExportMarkdown;

  /// No description provided for @haftKhanExported.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} task(s) to the clipboard.'**
  String haftKhanExported(int count);

  /// No description provided for @haftKhanExportedMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copied the markdown checklist.'**
  String get haftKhanExportedMarkdown;

  /// No description provided for @haftKhanImport.
  ///
  /// In en, this message translates to:
  /// **'Import from the box'**
  String get haftKhanImport;

  /// No description provided for @haftKhanImportReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace everything first'**
  String get haftKhanImportReplace;

  /// No description provided for @haftKhanTransferHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a backup JSON here'**
  String get haftKhanTransferHint;

  /// No description provided for @haftKhanImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {tasks} task(s), {links} link(s).'**
  String haftKhanImported(int tasks, int links);

  /// No description provided for @haftKhanBadPayload.
  ///
  /// In en, this message translates to:
  /// **'That payload could not be read'**
  String get haftKhanBadPayload;

  /// No description provided for @haftKhanAdded.
  ///
  /// In en, this message translates to:
  /// **'Added #{id}: {title}'**
  String haftKhanAdded(int id, String title);

  /// No description provided for @haftKhanStarted.
  ///
  /// In en, this message translates to:
  /// **'Started #{id}: {title}'**
  String haftKhanStarted(int id, String title);

  /// No description provided for @haftKhanConquered.
  ///
  /// In en, this message translates to:
  /// **'Conquered #{id}: {title}'**
  String haftKhanConquered(int id, String title);

  /// No description provided for @haftKhanRespawned.
  ///
  /// In en, this message translates to:
  /// **'Respawned #{id}: {title} (due {due})'**
  String haftKhanRespawned(int id, String title, String due);

  /// No description provided for @haftKhanRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed #{id}.'**
  String haftKhanRemoved(int id);

  /// No description provided for @haftKhanOverdueLabel.
  ///
  /// In en, this message translates to:
  /// **'overdue'**
  String get haftKhanOverdueLabel;

  /// No description provided for @haftKhanBlockedBy.
  ///
  /// In en, this message translates to:
  /// **'blocked by {ids}'**
  String haftKhanBlockedBy(String ids);

  /// No description provided for @haftKhanConqueredOn.
  ///
  /// In en, this message translates to:
  /// **'conquered {date}'**
  String haftKhanConqueredOn(String date);

  /// No description provided for @haftKhanEvery.
  ///
  /// In en, this message translates to:
  /// **'every {interval} {kind}'**
  String haftKhanEvery(int interval, String kind);

  /// No description provided for @haftKhanColumnTodo.
  ///
  /// In en, this message translates to:
  /// **'TODO'**
  String get haftKhanColumnTodo;

  /// No description provided for @haftKhanColumnDoing.
  ///
  /// In en, this message translates to:
  /// **'DOING'**
  String get haftKhanColumnDoing;

  /// No description provided for @haftKhanColumnDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get haftKhanColumnDone;

  /// No description provided for @haftKhanColumnCount.
  ///
  /// In en, this message translates to:
  /// **'{count} task(s)'**
  String haftKhanColumnCount(int count);

  /// No description provided for @haftKhanFocusTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus next'**
  String get haftKhanFocusTitle;

  /// No description provided for @haftKhanFocusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One fast, manageable step at a time'**
  String get haftKhanFocusSubtitle;

  /// No description provided for @formatDate.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String formatDate(DateTime date);

  /// No description provided for @divanTitle.
  ///
  /// In en, this message translates to:
  /// **'Divan — the notes pad'**
  String get divanTitle;

  /// No description provided for @divanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Markdown notes with notebooks, tags, wiki-links, checklists, a daily journal, and full-text search.'**
  String get divanSubtitle;

  /// No description provided for @divanStatNotebooks.
  ///
  /// In en, this message translates to:
  /// **'{count} notebooks'**
  String divanStatNotebooks(Object count);

  /// No description provided for @divanStatNotes.
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String divanStatNotes(Object count);

  /// No description provided for @divanStatWords.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String divanStatWords(Object count);

  /// No description provided for @divanStatTodos.
  ///
  /// In en, this message translates to:
  /// **'{count} open todos'**
  String divanStatTodos(Object count);

  /// No description provided for @divanStatArchived.
  ///
  /// In en, this message translates to:
  /// **'{count} archived'**
  String divanStatArchived(Object count);

  /// No description provided for @divanSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search the pad'**
  String get divanSearchHint;

  /// No description provided for @divanFieldNotebook.
  ///
  /// In en, this message translates to:
  /// **'Notebook'**
  String get divanFieldNotebook;

  /// No description provided for @divanAllNotebooks.
  ///
  /// In en, this message translates to:
  /// **'All notebooks'**
  String get divanAllNotebooks;

  /// No description provided for @divanFieldTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get divanFieldTag;

  /// No description provided for @divanAllTags.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get divanAllTags;

  /// No description provided for @divanFilterPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get divanFilterPinned;

  /// No description provided for @divanFilterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get divanFilterArchived;

  /// No description provided for @divanFilterChecklists.
  ///
  /// In en, this message translates to:
  /// **'Checklists'**
  String get divanFilterChecklists;

  /// No description provided for @divanClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get divanClearFilters;

  /// No description provided for @divanNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get divanNewNote;

  /// No description provided for @divanNewNotebook.
  ///
  /// In en, this message translates to:
  /// **'New notebook'**
  String get divanNewNotebook;

  /// No description provided for @divanJournal.
  ///
  /// In en, this message translates to:
  /// **'Today\'s journal'**
  String get divanJournal;

  /// No description provided for @divanUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get divanUndo;

  /// No description provided for @divanRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get divanRefresh;

  /// No description provided for @divanTransfer.
  ///
  /// In en, this message translates to:
  /// **'Markdown files'**
  String get divanTransfer;

  /// No description provided for @divanSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get divanSync;

  /// No description provided for @divanNotebooks.
  ///
  /// In en, this message translates to:
  /// **'Notebooks'**
  String get divanNotebooks;

  /// No description provided for @divanNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get divanNotes;

  /// No description provided for @divanNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes match the filters yet.'**
  String get divanNoNotes;

  /// No description provided for @divanArchivedLabel.
  ///
  /// In en, this message translates to:
  /// **'archived'**
  String get divanArchivedLabel;

  /// No description provided for @divanNotebookMenu.
  ///
  /// In en, this message translates to:
  /// **'Notebook actions'**
  String get divanNotebookMenu;

  /// No description provided for @divanRenameNotebook.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get divanRenameNotebook;

  /// No description provided for @divanArchiveNotebook.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get divanArchiveNotebook;

  /// No description provided for @divanRestoreNotebook.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get divanRestoreNotebook;

  /// No description provided for @divanDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get divanDelete;

  /// No description provided for @divanNoSelection.
  ///
  /// In en, this message translates to:
  /// **'Pick a note on the left, or create one.'**
  String get divanNoSelection;

  /// No description provided for @divanFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get divanFieldTitle;

  /// No description provided for @divanFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get divanFieldTags;

  /// No description provided for @divanFieldTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Comma separated, e.g. work, idea'**
  String get divanFieldTagsHint;

  /// No description provided for @divanFieldBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get divanFieldBody;

  /// No description provided for @divanFieldBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Markdown — [[wiki-links]] and - [ ] checklists work'**
  String get divanFieldBodyHint;

  /// No description provided for @divanSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get divanSave;

  /// No description provided for @divanPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get divanPin;

  /// No description provided for @divanUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get divanUnpin;

  /// No description provided for @divanArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get divanArchive;

  /// No description provided for @divanRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get divanRestore;

  /// No description provided for @divanUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {stamp}'**
  String divanUpdatedAt(Object stamp);

  /// No description provided for @divanMetricWords.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String divanMetricWords(Object count);

  /// No description provided for @divanMetricCharacters.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String divanMetricCharacters(Object count);

  /// No description provided for @divanMetricReading.
  ///
  /// In en, this message translates to:
  /// **'{count} s to read'**
  String divanMetricReading(Object count);

  /// No description provided for @divanMetricChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist {done}/{total}'**
  String divanMetricChecklist(int done, int total);

  /// No description provided for @divanMetricLinks.
  ///
  /// In en, this message translates to:
  /// **'{count} links'**
  String divanMetricLinks(Object count);

  /// No description provided for @divanChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get divanChecklist;

  /// No description provided for @divanLinks.
  ///
  /// In en, this message translates to:
  /// **'Wiki-links'**
  String get divanLinks;

  /// No description provided for @divanBacklinks.
  ///
  /// In en, this message translates to:
  /// **'Backlinks'**
  String get divanBacklinks;

  /// No description provided for @divanBacklinksEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing links here yet.'**
  String get divanBacklinksEmpty;

  /// No description provided for @divanTodos.
  ///
  /// In en, this message translates to:
  /// **'Open todos'**
  String get divanTodos;

  /// No description provided for @divanTodoHint.
  ///
  /// In en, this message translates to:
  /// **'Add an item to today\'s journal'**
  String get divanTodoHint;

  /// No description provided for @divanAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get divanAdd;

  /// No description provided for @divanTodosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open checklist items.'**
  String get divanTodosEmpty;

  /// No description provided for @divanAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get divanAi;

  /// No description provided for @divanAiClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get divanAiClear;

  /// No description provided for @divanAiSummarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get divanAiSummarize;

  /// No description provided for @divanAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Propose a title'**
  String get divanAiTitle;

  /// No description provided for @divanAiTags.
  ///
  /// In en, this message translates to:
  /// **'Propose tags'**
  String get divanAiTags;

  /// No description provided for @divanAskHint.
  ///
  /// In en, this message translates to:
  /// **'Ask the pad a question'**
  String get divanAskHint;

  /// No description provided for @divanAiAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get divanAiAsk;

  /// No description provided for @divanAiApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Use this title'**
  String get divanAiApplyTitle;

  /// No description provided for @divanAiApplyTags.
  ///
  /// In en, this message translates to:
  /// **'Use these tags'**
  String get divanAiApplyTags;

  /// No description provided for @divanStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get divanStats;

  /// No description provided for @divanStatsDetail.
  ///
  /// In en, this message translates to:
  /// **'{tagged} tagged notes · {links} wiki-links'**
  String divanStatsDetail(int tagged, int links);

  /// No description provided for @divanDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get divanDismiss;

  /// No description provided for @divanTabNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get divanTabNotes;

  /// No description provided for @divanTabEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get divanTabEditor;

  /// No description provided for @divanTabTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get divanTabTools;

  /// No description provided for @divanCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get divanCancel;

  /// No description provided for @divanDeleteNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String divanDeleteNoteTitle(Object title);

  /// No description provided for @divanDeleteNotebookTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String divanDeleteNotebookTitle(Object name);

  /// No description provided for @divanDeleteNotebookBody.
  ///
  /// In en, this message translates to:
  /// **'Its notes are deleted with it — this is one undoable step.'**
  String get divanDeleteNotebookBody;

  /// No description provided for @divanDeleteUndoable.
  ///
  /// In en, this message translates to:
  /// **'This is one undoable step.'**
  String get divanDeleteUndoable;

  /// No description provided for @divanFieldFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get divanFieldFolder;

  /// No description provided for @divanTransferHint.
  ///
  /// In en, this message translates to:
  /// **'Export writes one .md file per active note; import reads every .md file back as a new note.'**
  String get divanTransferHint;

  /// No description provided for @divanExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get divanExport;

  /// No description provided for @divanImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get divanImport;

  /// No description provided for @divanSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Merge keeps both devices\' changes; pull never writes the remote; push replaces it.'**
  String get divanSyncHint;

  /// No description provided for @divanSyncMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get divanSyncMerge;

  /// No description provided for @divanSyncPull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get divanSyncPull;

  /// No description provided for @divanSyncPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get divanSyncPush;

  /// No description provided for @divanDefaultNotebook.
  ///
  /// In en, this message translates to:
  /// **'Default notebook'**
  String get divanDefaultNotebook;

  /// No description provided for @divanEditorWrite.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get divanEditorWrite;

  /// No description provided for @divanEditorPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get divanEditorPreview;

  /// No description provided for @divanPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview yet.'**
  String get divanPreviewEmpty;

  /// No description provided for @ganjoorTitle.
  ///
  /// In en, this message translates to:
  /// **'Ganjoor — wallet'**
  String get ganjoorTitle;

  /// No description provided for @ganjoorTabAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get ganjoorTabAccounts;

  /// No description provided for @ganjoorTabLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ganjoorTabLedger;

  /// No description provided for @ganjoorTabTools.
  ///
  /// In en, this message translates to:
  /// **'Reports & plans'**
  String get ganjoorTabTools;

  /// No description provided for @ganjoorTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ganjoorTotal;

  /// No description provided for @ganjoorAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get ganjoorAccounts;

  /// No description provided for @ganjoorNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet — add one to start.'**
  String get ganjoorNoAccounts;

  /// No description provided for @ganjoorShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get ganjoorShowArchived;

  /// No description provided for @ganjoorAccountAdd.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get ganjoorAccountAdd;

  /// No description provided for @ganjoorAccountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get ganjoorAccountName;

  /// No description provided for @ganjoorAccountCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get ganjoorAccountCurrency;

  /// No description provided for @ganjoorAccountStart.
  ///
  /// In en, this message translates to:
  /// **'Starting balance'**
  String get ganjoorAccountStart;

  /// No description provided for @ganjoorAccountArchived.
  ///
  /// In en, this message translates to:
  /// **'archived'**
  String get ganjoorAccountArchived;

  /// No description provided for @ganjoorAccountArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get ganjoorAccountArchive;

  /// No description provided for @ganjoorAccountUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get ganjoorAccountUnarchive;

  /// No description provided for @ganjoorAccountRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get ganjoorAccountRename;

  /// No description provided for @ganjoorAccountRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get ganjoorAccountRemove;

  /// No description provided for @ganjoorAccountRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this account and leave its history behind?'**
  String get ganjoorAccountRemoveConfirm;

  /// No description provided for @ganjoorAccountRemoveForce.
  ///
  /// In en, this message translates to:
  /// **'This account holds transactions'**
  String get ganjoorAccountRemoveForce;

  /// No description provided for @ganjoorCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ganjoorCancel;

  /// No description provided for @ganjoorSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get ganjoorSave;

  /// No description provided for @ganjoorConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get ganjoorConfirm;

  /// No description provided for @ganjoorQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get ganjoorQuickAdd;

  /// No description provided for @ganjoorKindSpend.
  ///
  /// In en, this message translates to:
  /// **'Spend'**
  String get ganjoorKindSpend;

  /// No description provided for @ganjoorKindEarn.
  ///
  /// In en, this message translates to:
  /// **'Earn'**
  String get ganjoorKindEarn;

  /// No description provided for @ganjoorKindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get ganjoorKindTransfer;

  /// No description provided for @ganjoorFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get ganjoorFrom;

  /// No description provided for @ganjoorTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get ganjoorTo;

  /// No description provided for @ganjoorAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get ganjoorAmount;

  /// No description provided for @ganjoorCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get ganjoorCategory;

  /// No description provided for @ganjoorNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get ganjoorNotes;

  /// No description provided for @ganjoorTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get ganjoorTags;

  /// No description provided for @ganjoorDate.
  ///
  /// In en, this message translates to:
  /// **'Date (yyyy-MM-dd)'**
  String get ganjoorDate;

  /// No description provided for @ganjoorAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ganjoorAdd;

  /// No description provided for @ganjoorLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ganjoorLedger;

  /// No description provided for @ganjoorLedgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions match.'**
  String get ganjoorLedgerEmpty;

  /// No description provided for @ganjoorRemoveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get ganjoorRemoveTransaction;

  /// No description provided for @ganjoorFilterAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get ganjoorFilterAccount;

  /// No description provided for @ganjoorFilterKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get ganjoorFilterKind;

  /// No description provided for @ganjoorFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category (Enter)'**
  String get ganjoorFilterCategory;

  /// No description provided for @ganjoorFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ganjoorFilterAll;

  /// No description provided for @ganjoorFilterQuery.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get ganjoorFilterQuery;

  /// No description provided for @ganjoorFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get ganjoorFilterClear;

  /// No description provided for @ganjoorPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get ganjoorPrevMonth;

  /// No description provided for @ganjoorNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get ganjoorNextMonth;

  /// No description provided for @ganjoorBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get ganjoorBudgets;

  /// No description provided for @ganjoorBudgetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No budgets set.'**
  String get ganjoorBudgetEmpty;

  /// No description provided for @ganjoorBudgetSet.
  ///
  /// In en, this message translates to:
  /// **'Set budget'**
  String get ganjoorBudgetSet;

  /// No description provided for @ganjoorBudgetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove budget'**
  String get ganjoorBudgetRemove;

  /// No description provided for @ganjoorBudgetLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit'**
  String get ganjoorBudgetLimit;

  /// No description provided for @ganjoorBudgetOver.
  ///
  /// In en, this message translates to:
  /// **'over budget'**
  String get ganjoorBudgetOver;

  /// No description provided for @ganjoorBudgetClose.
  ///
  /// In en, this message translates to:
  /// **'close to the limit'**
  String get ganjoorBudgetClose;

  /// No description provided for @ganjoorBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get ganjoorBills;

  /// No description provided for @ganjoorBillEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bills yet.'**
  String get ganjoorBillEmpty;

  /// No description provided for @ganjoorBillApply.
  ///
  /// In en, this message translates to:
  /// **'Apply due'**
  String get ganjoorBillApply;

  /// No description provided for @ganjoorBillRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove bill'**
  String get ganjoorBillRemove;

  /// No description provided for @ganjoorBillDue.
  ///
  /// In en, this message translates to:
  /// **'due'**
  String get ganjoorBillDue;

  /// No description provided for @ganjoorGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get ganjoorGoals;

  /// No description provided for @ganjoorGoalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No goals yet.'**
  String get ganjoorGoalEmpty;

  /// No description provided for @ganjoorGoalContribute.
  ///
  /// In en, this message translates to:
  /// **'Add to goal'**
  String get ganjoorGoalContribute;

  /// No description provided for @ganjoorGoalWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Take from goal'**
  String get ganjoorGoalWithdraw;

  /// No description provided for @ganjoorGoalNearlyDone.
  ///
  /// In en, this message translates to:
  /// **'almost there'**
  String get ganjoorGoalNearlyDone;

  /// No description provided for @ganjoorDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get ganjoorDebts;

  /// No description provided for @ganjoorDebtEmpty.
  ///
  /// In en, this message translates to:
  /// **'No debts tracked.'**
  String get ganjoorDebtEmpty;

  /// No description provided for @ganjoorDebtSettle.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get ganjoorDebtSettle;

  /// No description provided for @ganjoorDebtRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove debt'**
  String get ganjoorDebtRemove;

  /// No description provided for @ganjoorDebtOwedByMe.
  ///
  /// In en, this message translates to:
  /// **'you owe'**
  String get ganjoorDebtOwedByMe;

  /// No description provided for @ganjoorDebtOwedToMe.
  ///
  /// In en, this message translates to:
  /// **'owed by'**
  String get ganjoorDebtOwedToMe;

  /// No description provided for @ganjoorDebtOutstanding.
  ///
  /// In en, this message translates to:
  /// **'outstanding'**
  String get ganjoorDebtOutstanding;

  /// No description provided for @ganjoorDebtFullySettled.
  ///
  /// In en, this message translates to:
  /// **'fully settled'**
  String get ganjoorDebtFullySettled;

  /// No description provided for @ganjoorReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get ganjoorReports;

  /// No description provided for @ganjoorIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get ganjoorIncome;

  /// No description provided for @ganjoorExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get ganjoorExpenses;

  /// No description provided for @ganjoorNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get ganjoorNet;

  /// No description provided for @ganjoorTopCategories.
  ///
  /// In en, this message translates to:
  /// **'Top categories'**
  String get ganjoorTopCategories;

  /// No description provided for @ganjoorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get ganjoorUndo;

  /// No description provided for @ganjoorRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get ganjoorRefresh;

  /// No description provided for @ganjoorTransfer.
  ///
  /// In en, this message translates to:
  /// **'Backup & files'**
  String get ganjoorTransfer;

  /// No description provided for @ganjoorTransferPath.
  ///
  /// In en, this message translates to:
  /// **'File path'**
  String get ganjoorTransferPath;

  /// No description provided for @ganjoorExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get ganjoorExportJson;

  /// No description provided for @ganjoorImportJson.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get ganjoorImportJson;

  /// No description provided for @ganjoorExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get ganjoorExportCsv;

  /// No description provided for @ganjoorImportCsv.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get ganjoorImportCsv;

  /// No description provided for @ganjoorCsvAccount.
  ///
  /// In en, this message translates to:
  /// **'CSV account'**
  String get ganjoorCsvAccount;

  /// No description provided for @ganjoorAi.
  ///
  /// In en, this message translates to:
  /// **'Finance assistant'**
  String get ganjoorAi;

  /// No description provided for @ganjoorAiInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get ganjoorAiInsights;

  /// No description provided for @ganjoorAiAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get ganjoorAiAsk;

  /// No description provided for @ganjoorAiQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your question'**
  String get ganjoorAiQuestion;

  /// No description provided for @ganjoorAiAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get ganjoorAiAnswer;

  /// No description provided for @ganjoorAiClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get ganjoorAiClear;

  /// No description provided for @ganjoorAiCategorize.
  ///
  /// In en, this message translates to:
  /// **'Suggest a category'**
  String get ganjoorAiCategorize;

  /// No description provided for @ganjoorAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI is not available in this context.'**
  String get ganjoorAiUnavailable;

  /// No description provided for @ganjoorCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String ganjoorCount(int count);

  /// No description provided for @ganjoorFromBill.
  ///
  /// In en, this message translates to:
  /// **'bill #{id}'**
  String ganjoorFromBill(int id);

  /// No description provided for @ganjoorBillNext.
  ///
  /// In en, this message translates to:
  /// **'next {date}'**
  String ganjoorBillNext(String date);

  /// No description provided for @ganjoorGoalDeadline.
  ///
  /// In en, this message translates to:
  /// **'by {date}'**
  String ganjoorGoalDeadline(String date);

  /// No description provided for @ganjoorDebtSettled.
  ///
  /// In en, this message translates to:
  /// **'settled {amount}'**
  String ganjoorDebtSettled(String amount);

  /// No description provided for @ganjoorNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth: {total}'**
  String ganjoorNetWorth(String total);

  /// No description provided for @ganjoorNetWorthBreakdown.
  ///
  /// In en, this message translates to:
  /// **'accounts {accounts}, owed to you {receivable}, you owe {payable}'**
  String ganjoorNetWorthBreakdown(
    String accounts,
    String receivable,
    String payable,
  );

  /// No description provided for @navSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get navSync;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncIntro.
  ///
  /// In en, this message translates to:
  /// **'Two devices converge on one document per service. Each run pulls, merges by identity, then writes the merged result back — no cursors, nothing to corrupt.'**
  String get syncIntro;

  /// No description provided for @syncDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get syncDismiss;

  /// No description provided for @syncDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get syncDeviceTitle;

  /// No description provided for @syncDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'The identity travels inside every envelope, so the other device can tell who sealed the remote.'**
  String get syncDeviceHint;

  /// No description provided for @syncDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get syncDeviceName;

  /// No description provided for @syncDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device id'**
  String get syncDeviceId;

  /// No description provided for @syncSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get syncSave;

  /// No description provided for @syncTokenSet.
  ///
  /// In en, this message translates to:
  /// **'JAMEJAM_SYNC_TOKEN is set'**
  String get syncTokenSet;

  /// No description provided for @syncTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'No sync token — the remote must accept anonymous writes'**
  String get syncTokenMissing;

  /// No description provided for @syncServiceTag.
  ///
  /// In en, this message translates to:
  /// **'Service tag {service} · saved as {key}'**
  String syncServiceTag(String service, String key);

  /// No description provided for @syncUrl.
  ///
  /// In en, this message translates to:
  /// **'Sync URL'**
  String get syncUrl;

  /// No description provided for @syncEnvOverride.
  ///
  /// In en, this message translates to:
  /// **'JAMEJAM_SYNC_URL wins over every saved URL: {url}'**
  String syncEnvOverride(String url);

  /// No description provided for @syncMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get syncMode;

  /// No description provided for @syncModeMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get syncModeMerge;

  /// No description provided for @syncModePull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get syncModePull;

  /// No description provided for @syncModePush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get syncModePush;

  /// No description provided for @syncModeMergeHint.
  ///
  /// In en, this message translates to:
  /// **'Pull, merge, and write the merged result back — both devices converge.'**
  String get syncModeMergeHint;

  /// No description provided for @syncModePullHint.
  ///
  /// In en, this message translates to:
  /// **'Pull and merge into this device only; the remote is never written.'**
  String get syncModePullHint;

  /// No description provided for @syncModePushHint.
  ///
  /// In en, this message translates to:
  /// **'Replace the remote with this device\'s state. It asks first when the remote holds other changes.'**
  String get syncModePushHint;

  /// No description provided for @syncSaveUrl.
  ///
  /// In en, this message translates to:
  /// **'Save URL'**
  String get syncSaveUrl;

  /// No description provided for @syncRun.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncRun;

  /// No description provided for @syncRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'What stays true'**
  String get syncRulesTitle;

  /// No description provided for @syncRuleHttps.
  ///
  /// In en, this message translates to:
  /// **'HTTPS only — plain HTTP is allowed on loopback for a local server.'**
  String get syncRuleHttps;

  /// No description provided for @syncRuleToken.
  ///
  /// In en, this message translates to:
  /// **'The bearer token comes from JAMEJAM_SYNC_TOKEN and is never stored or shown.'**
  String get syncRuleToken;

  /// No description provided for @syncRuleConverge.
  ///
  /// In en, this message translates to:
  /// **'Merging is deterministic and commutative, so repeated runs land on the same state on every device.'**
  String get syncRuleConverge;

  /// No description provided for @syncRuleRaz.
  ///
  /// In en, this message translates to:
  /// **'Raz never syncs: the vault is encrypted on this device and has no adapter, by design.'**
  String get syncRuleRaz;

  /// No description provided for @syncProtocol.
  ///
  /// In en, this message translates to:
  /// **'Wire protocol: jamejam.sync/1 · one service per URL'**
  String get syncProtocol;

  /// No description provided for @syncOverwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrite the remote?'**
  String get syncOverwriteTitle;

  /// No description provided for @syncOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get syncOverwrite;

  /// No description provided for @syncCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get syncCancel;

  /// No description provided for @syncDeviceIdPending.
  ///
  /// In en, this message translates to:
  /// **'Created by the first sync'**
  String get syncDeviceIdPending;

  /// No description provided for @taqvimAgendaTitle.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get taqvimAgendaTitle;

  /// No description provided for @taqvimAgendaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Events in the chosen scope, with this calendar\'s own conflicts flagged.'**
  String get taqvimAgendaSubtitle;

  /// No description provided for @taqvimAgendaEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled in this scope.'**
  String get taqvimAgendaEmpty;

  /// No description provided for @taqvimPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get taqvimPreviousDay;

  /// No description provided for @taqvimNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get taqvimNextDay;

  /// No description provided for @taqvimRefresh.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get taqvimRefresh;

  /// No description provided for @taqvimUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo the last change'**
  String get taqvimUndo;

  /// No description provided for @taqvimFilterCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get taqvimFilterCalendar;

  /// No description provided for @taqvimFilterTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get taqvimFilterTag;

  /// No description provided for @taqvimFilterApply.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get taqvimFilterApply;

  /// No description provided for @taqvimConflictCount.
  ///
  /// In en, this message translates to:
  /// **'{count} conflict(s)'**
  String taqvimConflictCount(int count);

  /// No description provided for @taqvimStatEvents.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String taqvimStatEvents(int count);

  /// No description provided for @taqvimStatRecurring.
  ///
  /// In en, this message translates to:
  /// **'{count} repeating'**
  String taqvimStatRecurring(int count);

  /// No description provided for @taqvimStatAllDay.
  ///
  /// In en, this message translates to:
  /// **'{count} all-day'**
  String taqvimStatAllDay(int count);

  /// No description provided for @taqvimStatTagged.
  ///
  /// In en, this message translates to:
  /// **'{count} tagged'**
  String taqvimStatTagged(int count);

  /// No description provided for @taqvimStatReminders.
  ///
  /// In en, this message translates to:
  /// **'{count} reminders'**
  String taqvimStatReminders(int count);

  /// No description provided for @taqvimStatNextSevenDays.
  ///
  /// In en, this message translates to:
  /// **'{count} in the next 7 days'**
  String taqvimStatNextSevenDays(int count);

  /// No description provided for @taqvimStatBusyMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} busy minutes'**
  String taqvimStatBusyMinutes(int minutes);

  /// No description provided for @taqvimCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick capture'**
  String get taqvimCaptureTitle;

  /// No description provided for @taqvimCaptureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write a sentence; the parser fills the editor. Nothing is invented when the sentence carries no date or time.'**
  String get taqvimCaptureSubtitle;

  /// No description provided for @taqvimCaptureHint.
  ///
  /// In en, this message translates to:
  /// **'lunch with Sara next Tuesday at 1pm'**
  String get taqvimCaptureHint;

  /// No description provided for @taqvimCaptureAction.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get taqvimCaptureAction;

  /// No description provided for @taqvimEditorNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get taqvimEditorNewTitle;

  /// No description provided for @taqvimEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Event #{id}'**
  String taqvimEditorEditTitle(int id);

  /// No description provided for @taqvimEditorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The same rails as the CLI: a title, an end after the start, bounded tags and reminders.'**
  String get taqvimEditorSubtitle;

  /// No description provided for @taqvimEditorNewAction.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get taqvimEditorNewAction;

  /// No description provided for @taqvimFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taqvimFieldTitle;

  /// No description provided for @taqvimFieldStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get taqvimFieldStart;

  /// No description provided for @taqvimFieldEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get taqvimFieldEnd;

  /// No description provided for @taqvimWhenHint.
  ///
  /// In en, this message translates to:
  /// **'2026-09-21 14:30, 2026-09-21, or 14:30'**
  String get taqvimWhenHint;

  /// No description provided for @taqvimFieldAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get taqvimFieldAllDay;

  /// No description provided for @taqvimFieldCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get taqvimFieldCalendar;

  /// No description provided for @taqvimFieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get taqvimFieldLocation;

  /// No description provided for @taqvimFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get taqvimFieldTags;

  /// No description provided for @taqvimTagsHint.
  ///
  /// In en, this message translates to:
  /// **'work, deep'**
  String get taqvimTagsHint;

  /// No description provided for @taqvimFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get taqvimFieldNotes;

  /// No description provided for @taqvimFieldRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get taqvimFieldRepeat;

  /// No description provided for @taqvimFieldRepeatInterval.
  ///
  /// In en, this message translates to:
  /// **'Every N'**
  String get taqvimFieldRepeatInterval;

  /// No description provided for @taqvimFieldReminders.
  ///
  /// In en, this message translates to:
  /// **'Remind (minutes before)'**
  String get taqvimFieldReminders;

  /// No description provided for @taqvimRemindersHint.
  ///
  /// In en, this message translates to:
  /// **'30, 10'**
  String get taqvimRemindersHint;

  /// No description provided for @taqvimRepeatOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get taqvimRepeatOnce;

  /// No description provided for @taqvimRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get taqvimRepeatDaily;

  /// No description provided for @taqvimRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get taqvimRepeatWeekly;

  /// No description provided for @taqvimRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get taqvimRepeatMonthly;

  /// No description provided for @taqvimRepeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get taqvimRepeatYearly;

  /// No description provided for @taqvimSaveAdd.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get taqvimSaveAdd;

  /// No description provided for @taqvimSaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get taqvimSaveEdit;

  /// No description provided for @taqvimDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get taqvimDeleteAction;

  /// No description provided for @taqvimDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get taqvimDeleteConfirmTitle;

  /// No description provided for @taqvimDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The deletion is recorded so other devices learn of it. Undo restores it.'**
  String get taqvimDeleteConfirmBody;

  /// No description provided for @taqvimScopeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get taqvimScopeToday;

  /// No description provided for @taqvimScopeTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get taqvimScopeTomorrow;

  /// No description provided for @taqvimScopeWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get taqvimScopeWeek;

  /// No description provided for @taqvimScopeMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get taqvimScopeMonth;

  /// No description provided for @taqvimScopeUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get taqvimScopeUpcoming;

  /// No description provided for @taqvimSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get taqvimSearchTitle;

  /// No description provided for @taqvimSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full text over titles, notes and locations — every term must match.'**
  String get taqvimSearchSubtitle;

  /// No description provided for @taqvimSearchHint.
  ///
  /// In en, this message translates to:
  /// **'dentist x-rays'**
  String get taqvimSearchHint;

  /// No description provided for @taqvimSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get taqvimSearchAction;

  /// No description provided for @taqvimSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No search yet.'**
  String get taqvimSearchEmpty;

  /// No description provided for @taqvimWindowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Free windows'**
  String get taqvimWindowsTitle;

  /// No description provided for @taqvimWindowsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The gaps between events inside a window of the day; clashes are flagged under the agenda.'**
  String get taqvimWindowsSubtitle;

  /// No description provided for @taqvimFieldDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get taqvimFieldDay;

  /// No description provided for @taqvimDayHint.
  ///
  /// In en, this message translates to:
  /// **'2026-09-21'**
  String get taqvimDayHint;

  /// No description provided for @taqvimFieldFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get taqvimFieldFrom;

  /// No description provided for @taqvimFieldTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get taqvimFieldTo;

  /// No description provided for @taqvimFieldMinutes.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get taqvimFieldMinutes;

  /// No description provided for @taqvimFreeAction.
  ///
  /// In en, this message translates to:
  /// **'Find free windows'**
  String get taqvimFreeAction;

  /// No description provided for @taqvimFreeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No free windows computed yet.'**
  String get taqvimFreeEmpty;

  /// No description provided for @taqvimFreeMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min free'**
  String taqvimFreeMinutesLabel(int minutes);

  /// No description provided for @taqvimTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Import and export (.ics)'**
  String get taqvimTransferTitle;

  /// No description provided for @taqvimTransferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One document, at most 2000 events, timestamps in UTC.'**
  String get taqvimTransferSubtitle;

  /// No description provided for @taqvimTransferAction.
  ///
  /// In en, this message translates to:
  /// **'Open the .ics box'**
  String get taqvimTransferAction;

  /// No description provided for @taqvimTransferBody.
  ///
  /// In en, this message translates to:
  /// **'Paste an .ics document to import, or fill the box with the current export.'**
  String get taqvimTransferBody;

  /// No description provided for @taqvimExportAction.
  ///
  /// In en, this message translates to:
  /// **'Fill with export'**
  String get taqvimExportAction;

  /// No description provided for @taqvimImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get taqvimImportAction;

  /// No description provided for @taqvimCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get taqvimCopyAction;

  /// No description provided for @taqvimAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule assistant'**
  String get taqvimAiTitle;

  /// No description provided for @taqvimAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prompts carry the agenda inside ---EVENT BEGIN--- markers and say the text within is untrusted.'**
  String get taqvimAiSubtitle;

  /// No description provided for @taqvimAiBrief.
  ///
  /// In en, this message translates to:
  /// **'Brief the day'**
  String get taqvimAiBrief;

  /// No description provided for @taqvimAiPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan the week'**
  String get taqvimAiPlan;

  /// No description provided for @taqvimAiCapture.
  ///
  /// In en, this message translates to:
  /// **'Suggest a command'**
  String get taqvimAiCapture;

  /// No description provided for @taqvimAiAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get taqvimAiAsk;

  /// No description provided for @taqvimAiAskHint.
  ///
  /// In en, this message translates to:
  /// **'when is my next free hour?'**
  String get taqvimAiAskHint;

  /// No description provided for @taqvimAiEmpty.
  ///
  /// In en, this message translates to:
  /// **'No answer yet.'**
  String get taqvimAiEmpty;

  /// No description provided for @taqvimAiSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion (copy, check, then run): {command}'**
  String taqvimAiSuggestion(String command);

  /// No description provided for @settingsClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear the filter'**
  String get settingsClearFilter;

  /// No description provided for @soroushShowKey.
  ///
  /// In en, this message translates to:
  /// **'Show the key'**
  String get soroushShowKey;

  /// No description provided for @soroushHideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide the key'**
  String get soroushHideKey;

  /// No description provided for @a11yToolboxGrid.
  ///
  /// In en, this message translates to:
  /// **'The toolbox steps'**
  String get a11yToolboxGrid;

  /// No description provided for @a11yCalendarAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get a11yCalendarAgenda;

  /// No description provided for @settingsMigrate.
  ///
  /// In en, this message translates to:
  /// **'Bring data across from the .NET toolbox'**
  String get settingsMigrate;

  /// No description provided for @migrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your data across'**
  String get migrationTitle;

  /// No description provided for @migrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read a file the .NET toolbox exported, so nothing has to be retyped.'**
  String get migrationSubtitle;

  /// No description provided for @migrationPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get migrationPaste;

  /// No description provided for @migrationTextLabel.
  ///
  /// In en, this message translates to:
  /// **'The exported file'**
  String get migrationTextLabel;

  /// No description provided for @migrationTextHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a .json backup or an .ics calendar here'**
  String get migrationTextHint;

  /// No description provided for @migrationImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get migrationImport;

  /// No description provided for @migrationNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing pasted yet.'**
  String get migrationNothing;

  /// No description provided for @migrationNotJson.
  ///
  /// In en, this message translates to:
  /// **'This is neither JSON nor an .ics document.'**
  String get migrationNotJson;

  /// No description provided for @migrationNotADocument.
  ///
  /// In en, this message translates to:
  /// **'This JSON is not a document this app can read.'**
  String get migrationNotADocument;

  /// No description provided for @migrationKindHaftKhan.
  ///
  /// In en, this message translates to:
  /// **'Haft Khan backup'**
  String get migrationKindHaftKhan;

  /// No description provided for @migrationKindGanjoor.
  ///
  /// In en, this message translates to:
  /// **'Ganjoor wallet backup'**
  String get migrationKindGanjoor;

  /// No description provided for @migrationKindRaz.
  ///
  /// In en, this message translates to:
  /// **'Raz vault bundle'**
  String get migrationKindRaz;

  /// No description provided for @migrationKindTaqvim.
  ///
  /// In en, this message translates to:
  /// **'Taqvim calendar (.ics)'**
  String get migrationKindTaqvim;

  /// No description provided for @migrationNoteHaftKhan.
  ///
  /// In en, this message translates to:
  /// **'Haft Khan: the .json written by haftkhan export (versions 1 and 2).'**
  String get migrationNoteHaftKhan;

  /// No description provided for @migrationNoteGanjoor.
  ///
  /// In en, this message translates to:
  /// **'Ganjoor: the .json written by ganjoor export.'**
  String get migrationNoteGanjoor;

  /// No description provided for @migrationNoteRaz.
  ///
  /// In en, this message translates to:
  /// **'Raz: the .json written by raz export — unlock the vault first; the bundle opens under the passphrase it was made with.'**
  String get migrationNoteRaz;

  /// No description provided for @migrationNoteTaqvim.
  ///
  /// In en, this message translates to:
  /// **'Taqvim: the .ics written by taqvim export.'**
  String get migrationNoteTaqvim;

  /// No description provided for @migrationNoteLocal.
  ///
  /// In en, this message translates to:
  /// **'Divan reads a folder of markdown files from its own transfer panel, and the SQLite files keep the names and shapes the .NET wrote — an existing ~/.jamejam folder is read in place.'**
  String get migrationNoteLocal;

  /// No description provided for @migrationVersion.
  ///
  /// In en, this message translates to:
  /// **'version {version}'**
  String migrationVersion(int version);

  /// No description provided for @migrationTasks.
  ///
  /// In en, this message translates to:
  /// **'{count} task(s)'**
  String migrationTasks(int count);

  /// No description provided for @migrationLinks.
  ///
  /// In en, this message translates to:
  /// **'{count} link(s)'**
  String migrationLinks(int count);

  /// No description provided for @migrationAccounts.
  ///
  /// In en, this message translates to:
  /// **'{count} account(s)'**
  String migrationAccounts(int count);

  /// No description provided for @migrationTransactions.
  ///
  /// In en, this message translates to:
  /// **'{count} transaction(s)'**
  String migrationTransactions(int count);

  /// No description provided for @migrationBudgets.
  ///
  /// In en, this message translates to:
  /// **'{count} budget(s)'**
  String migrationBudgets(int count);

  /// No description provided for @migrationEvents.
  ///
  /// In en, this message translates to:
  /// **'{count} event(s)'**
  String migrationEvents(int count);

  /// No description provided for @migrationResult.
  ///
  /// In en, this message translates to:
  /// **'Imported {kind}: {count} record(s).'**
  String migrationResult(String kind, int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
