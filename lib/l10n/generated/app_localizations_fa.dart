// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'جام‌جم';

  @override
  String get appTagline => 'جعبه‌ابزاری خصوصی و محلی';

  @override
  String get navDashboard => 'خانه';

  @override
  String get navGreeter => 'خوش‌آمدگو';

  @override
  String get navHaftKhan => 'هفت‌خان';

  @override
  String get navAnahita => 'آناهیتا';

  @override
  String get navGanjoor => 'گنجور';

  @override
  String get navRaz => 'راز';

  @override
  String get navDivan => 'دیوان';

  @override
  String get navTaqvim => 'تقویم';

  @override
  String get navSoroush => 'هوش مصنوعی سروش';

  @override
  String get navSettings => 'تنظیمات';

  @override
  String haftKhanConfirmRemove(int id, String title) {
    return 'کار «$id#» با نام «$title» برداشته شود؟ تنها با بازگردانی می‌توان آن را برگرداند.';
  }

  @override
  String haftKhanConfirmClearDone(int count) {
    return 'همهٔ $count کار انجام‌شده برداشته شوند؟';
  }

  @override
  String get haftKhanConfirmImportReplace =>
      'ورود با گزینهٔ «جایگزینی» ابتدا انبار کنونی را پاک می‌کند. ادامه می‌دهید؟';

  @override
  String get anahitaTabNow => 'اکنون';

  @override
  String get anahitaTabForecast => 'پیش‌بینی';

  @override
  String get anahitaTabHourly => 'ساعتی';

  @override
  String get anahitaTabAlerts => 'هشدارها';

  @override
  String get anahitaTabBest => 'بهترین روزها';

  @override
  String get anahitaTabPlan => 'برنامه';

  @override
  String get anahitaUnitsMetric => '°C';

  @override
  String get anahitaUnitsImperial => '°F';

  @override
  String get anahitaLocation => 'مکان';

  @override
  String get anahitaLocationHint => 'تهران، یا 35.69,51.39';

  @override
  String get anahitaSaveLocation => 'ذخیرهٔ مکان';

  @override
  String anahitaLocationSaved(String place) {
    return 'مکان ذخیره شد: $place — از این پس استفاده می‌شود.';
  }

  @override
  String anahitaAsOf(String place, String timezone) {
    return '$place · منطقهٔ زمانی $timezone';
  }

  @override
  String get anahitaFetchFailed => 'آب‌وهوا دریافت نشد';

  @override
  String get anahitaNothingYet =>
      'نام یک مکان را بنویسید و پیش‌بینی را بگیرید.';

  @override
  String anahitaFeelsLike(String value) {
    return 'حس‌شده $value';
  }

  @override
  String get anahitaHumidity => 'رطوبت';

  @override
  String get anahitaWind => 'باد';

  @override
  String anahitaWindDirection(String direction) {
    return '$direction';
  }

  @override
  String get anahitaPrecipitation => 'بارش';

  @override
  String get anahitaSun => 'خورشید';

  @override
  String get anahitaUvMax => 'بیشینهٔ فرابنفش';

  @override
  String anahitaForecastTitle(int days) {
    return 'پیش‌بینی $days روزه';
  }

  @override
  String anahitaHourlyTitle(int hours) {
    return '$hours ساعت آینده';
  }

  @override
  String get anahitaNoAlerts => 'در روزهای آینده هشداری نیست.';

  @override
  String get anahitaBestTitle => 'بهترین روزها در فضای باز';

  @override
  String get anahitaBestSubtitle => 'بر پایهٔ احتمال باران، دما، باد و توفان';

  @override
  String anahitaScore(int score) {
    return 'امتیاز $score';
  }

  @override
  String get anahitaPlanTitle => 'هوا برای برنامه‌های شما';

  @override
  String get anahitaPlanSubtitle => 'کارهای باز، زیر پیش‌بینی روز سررسیدشان';

  @override
  String get anahitaNothingToCopy => 'هنوز چیزی برای رونویسی نیست.';

  @override
  String get anahitaExplain => 'توضیح بده';

  @override
  String get anahitaExplanationRequested =>
      'توضیح آماده است — تاریخچهٔ کامل در صفحهٔ هوش مصنوعی.';

  @override
  String get anahitaAiPlan => 'برنامهٔ هوشمند';

  @override
  String get anahitaAskTitle => 'از این پیش‌بینی بپرس';

  @override
  String get anahitaAskSubtitle => 'پاسخ تنها از دادهٔ بالا استفاده می‌کند';

  @override
  String get anahitaAskLabel => 'پرسش';

  @override
  String get anahitaAskHint => 'ساعت ۱۸ دوچرخه سواری کنم؟';

  @override
  String get anahitaAsk => 'بپرس';

  @override
  String get anahitaAnswered => 'پاسخ آماده است.';

  @override
  String get razTitle => 'راز — گنجینۀ رمزگذاری‌شده';

  @override
  String get razSubtitle =>
      'رمزها اینجا رمزنگاری‌شده می‌مانند: AES-256-GCM با کلید مشتق‌شده از PBKDF2-HMAC-SHA512. هیچ‌چیز از این دستگاه خارج نمی‌شود.';

  @override
  String get razCreateTitle => 'گنجینه را بسازید';

  @override
  String get razUnlockTitle => 'گنجینه را باز کنید';

  @override
  String get razPassphraseHint =>
      'عبارت عبور در گنجینه ذخیره نمی‌شود — همان کلیدی را می‌سازد که رمزگشایی می‌کند.';

  @override
  String get razPassphrase => 'عبارت عبور';

  @override
  String get razRememberPassphrase => 'در جاکلیدی به خاطر بسپار';

  @override
  String get razCreate => 'ساخت گنجینه';

  @override
  String get razUnlock => 'باز کردن';

  @override
  String get razVaultCreated => 'گنجینه ساخته و باز شد.';

  @override
  String get razUnlocked => 'گنجینه باز شد.';

  @override
  String get razUseStoredPassphrase => 'استفاده از عبارت عبور به‌خاطر‌مانده';

  @override
  String get razNoStoredPassphrase =>
      'عبارت عبوری به خاطر نمانده — یکی بنویسید.';

  @override
  String get razForgetPassphrase => 'فراموش کن';

  @override
  String get razPassphraseForgotten => 'عبارت عبور به‌خاطر‌مانده پاک شد.';

  @override
  String get razLocalOnly =>
      'برای راز هیچ همگام‌سازی‌ای وجود ندارد؛ از روی طراحی، رازها هیچ مسیری به شبکه ندارند.';

  @override
  String get razSearch => 'جست‌وجو';

  @override
  String get razFilterFavorites => 'برگزیده‌ها';

  @override
  String get razFilterWeak => 'ضعیف';

  @override
  String get razFilterExpired => 'منقضی';

  @override
  String razTagFilter(Object tag) {
    return 'برچسب: $tag';
  }

  @override
  String get razAddEntry => 'ورودی تازه';

  @override
  String get razEditEntry => 'ویرایش ورودی';

  @override
  String get razEntryAdded => 'ورودی افزوده شد.';

  @override
  String get razEntrySaved => 'ورودی ذخیره شد.';

  @override
  String get razEntryDeleted => 'ورودی حذف شد — واگرد بازش می‌گرداند.';

  @override
  String get razInvalidDate => 'قالب تاریخ ‎yyyy-MM-dd‎ است.';

  @override
  String get razUndone => 'آخرین تغییر واگرد شد.';

  @override
  String get razNothingToUndo => 'چیزی برای واگرد نیست.';

  @override
  String get razAudit => 'حسابرسی';

  @override
  String get razAuditDone => 'حسابرسی تازه شد.';

  @override
  String get razAiAudit => 'پرسش از مربی';

  @override
  String get razExport => 'برون‌بری';

  @override
  String get razExported => 'بستهٔ رمزنگاری‌شده در بریدهدان کپی شد.';

  @override
  String get razImport => 'درون‌ریزی';

  @override
  String get razImportTitle => 'درون‌ریزی پشتیبان گنجینه';

  @override
  String get razImportBundle => 'بستهٔ رمزنگاری‌شده';

  @override
  String razImported(Object count) {
    return '$count ورودی درون‌ریزی شد.';
  }

  @override
  String get razLock => 'قفل';

  @override
  String get razLocked => 'گنجینه قفل و کلید از حافظه پاک شد.';

  @override
  String get razNoEntries =>
      'ورودی‌ای با این پالایه‌ها نیست. یکی بیفزایید یا پالایه‌ها را پاک کنید.';

  @override
  String get razUntitled => '(بی‌نام)';

  @override
  String razExpiresOn(Object date) {
    return 'انقضا $date';
  }

  @override
  String razTotpValue(Object code, Object seconds) {
    return 'TOTP $code — $seconds ثانیه مانده';
  }

  @override
  String get razRevealSecret => 'نمایش';

  @override
  String get razHideSecret => 'پنهان';

  @override
  String get razTotpRefresh => 'تازه‌سازی TOTP';

  @override
  String get razCopySecret => 'رونوشت راز';

  @override
  String get razDeleteTitle => 'این ورودی حذف شود؟';

  @override
  String razDeleteMessage(Object title) {
    return '«$title» برداشته می‌شود. تا وقتی گنجینه باز است واگرد می‌تواند بازش گرداند.';
  }

  @override
  String get razFieldTitle => 'عنوان';

  @override
  String get razFieldSecret => 'راز';

  @override
  String get razFieldUsername => 'نام کاربری';

  @override
  String get razFieldUrl => 'نشانی';

  @override
  String get razFieldNotes => 'یادداشت';

  @override
  String get razFieldTags => 'برچسب‌ها (با کاما)';

  @override
  String get razFieldExpires => 'تاریخ انقضا';

  @override
  String get razFieldTotpSeed => 'بذر TOTP (Base32)';

  @override
  String get razFieldTotpDigits => 'رقم‌ها';

  @override
  String get razFieldTotpPeriod => 'دوره (ثانیه)';

  @override
  String get razFieldFavorite => 'برگزیده';

  @override
  String get razGenerate => 'ساخت گذرواژه';

  @override
  String get razAuditTitle => 'سلامت گنجینه';

  @override
  String get razStatEntries => 'ورودی';

  @override
  String get razStatWeak => 'ضعیف';

  @override
  String get razStatReused => 'تکراری';

  @override
  String get razStatExpired => 'منقضی';

  @override
  String get razStatExpiringSoon => 'نزدیک انقضا';

  @override
  String get razStatOld => 'کهنه';

  @override
  String get razStatAverageLength => 'میانگین طول';

  @override
  String get razStatUnique => 'رازهای یکتا';

  @override
  String get razCoachTitle => 'مربی امنیت';

  @override
  String get razCoachSubtitle =>
      'مربی تنها شمارهای کلانی می‌بیند — هرگز عنوان، نشانی، نام کاربری، یادداشت، بذر یا رازی نه.';

  @override
  String get razCoachQuestion => 'دربارۀ بهداشت گنجینه بپرسید';

  @override
  String get razAsk => 'بپرس';

  @override
  String get commonSave => 'ذخیره';

  @override
  String get commonCancel => 'انصراف';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonRemove => 'برداشتن';

  @override
  String get commonAdd => 'افزودن';

  @override
  String get commonEdit => 'ویرایش';

  @override
  String get commonClose => 'بستن';

  @override
  String get commonRetry => 'تلاش دوباره';

  @override
  String get commonRefresh => 'به‌روزرسانی';

  @override
  String get commonSearch => 'جست‌وجو';

  @override
  String get commonClear => 'پاک‌سازی';

  @override
  String get commonUndo => 'بازگردانی';

  @override
  String get commonCopy => 'رونوشت';

  @override
  String get commonCopied => 'در بریدگی‌دان رونوشت شد';

  @override
  String get commonError => 'خطایی رخ داد';

  @override
  String get commonLoading => 'در حال بارگذاری…';

  @override
  String get commonEmpty => 'هنوز چیزی اینجا نیست';

  @override
  String get commonConfirm => 'تأیید';

  @override
  String get settingsTitle => 'تنظیمات';

  @override
  String get settingsSubtitle =>
      'تنظیمات غیر‌محرمانه، ذخیره‌شده در پایگاه‌دادهٔ محلی SQLite';

  @override
  String get settingsKeyLabel => 'کلید';

  @override
  String get settingsValueLabel => 'مقدار';

  @override
  String get settingsAddTitle => 'افزودن یا ویرایش یک تنظیم';

  @override
  String get settingsSearchHint => 'پالایش کلیدها…';

  @override
  String get settingsEmpty => 'هنوز تنظیمی ذخیره نشده است.';

  @override
  String get settingsNoMatch => 'هیچ کلیدی با پالایش شما نمی‌خواند.';

  @override
  String get settingsRefusedSecretTitle => 'رد شد: این کلید مانند یک راز است';

  @override
  String get settingsRefusedSecretBody =>
      'پایگاه‌دادهٔ تنظیمات متنِ آشکار است. کلیدهای API، نشانه‌ها و گذرواژه‌ها را در انبار امن نگه دارید.';

  @override
  String get settingsRemoveTitle => 'این تنظیم برداشته شود؟';

  @override
  String get settingsRemoved => 'تنظیم برداشته شد';

  @override
  String get settingsSaved => 'تنظیم ذخیره شد';

  @override
  String get settingsClearAllTitle => 'همهٔ تنظیمات پاک شود؟';

  @override
  String get settingsClearAllBody =>
      'این کار همهٔ تنظیمات ذخیره‌شده در این دستگاه را برمی‌دارد.';

  @override
  String settingsCleared(int count) {
    return '$count تنظیم پاک شد';
  }

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsLanguageSystem => 'پیروی از سامانه';

  @override
  String get settingsLanguageEnglish => 'انگلیسی (English)';

  @override
  String get settingsLanguagePersian => 'فارسی';

  @override
  String get settingsTheme => 'پوسته';

  @override
  String get settingsThemeSystem => 'پیروی از سامانه';

  @override
  String get settingsThemeLight => 'روشن';

  @override
  String get settingsThemeDark => 'تاریک';

  @override
  String get settingsDatabase => 'پایگاه‌داده';

  @override
  String get settingsWelcome => 'به جام‌جم خوش آمدید';

  @override
  String get soroushTitle => 'هوش مصنوعی سروش';

  @override
  String get soroushSubtitle =>
      'یک مسیر امن و مستقل از سرویس‌دهنده برای همهٔ فراخوانی‌های هوش مصنوعی';

  @override
  String get soroushProvider => 'سرویس‌دهنده';

  @override
  String get soroushModel => 'مدل';

  @override
  String get soroushEndpoint => 'نشانی پایانه';

  @override
  String get soroushApiKey => 'کلید API';

  @override
  String get soroushApiKeyHint =>
      'در انبار امن دستگاه ذخیره می‌شود — هرگز در پایگاه‌دادهٔ تنظیمات';

  @override
  String get soroushApiKeySaved => 'کلید API در انبار امن ذخیره شد';

  @override
  String get soroushApiKeyCleared => 'کلید API برداشته شد';

  @override
  String soroushKeyConfigured(String masked) {
    return 'کلید تنظیم شده است ($masked)';
  }

  @override
  String get soroushKeyMissing => 'هیچ کلید API تنظیم نشده است';

  @override
  String get soroushPromptHint => 'هر چیزی از سروش بپرسید…';

  @override
  String get soroushSend => 'بفرست';

  @override
  String get soroushResponse => 'پاسخ';

  @override
  String soroushMeta(
    String provider,
    String model,
    int attempts,
    int duration,
  ) {
    return '$provider · $model · $attempts تلاش · $duration میلی‌ثانیه';
  }

  @override
  String get soroushHistory => 'فراخوانی‌های اخیر';

  @override
  String get soroushHistoryEmpty =>
      'هنوز فراخوانی‌ای نبوده — درخواست‌های شما روی همین دستگاه می‌مانند.';

  @override
  String get soroushClearHistory => 'پاک‌کردن تاریخچه';

  @override
  String get soroushHistoryCleared => 'تاریخچه پاک شد';

  @override
  String get soroushInsecureEndpoint =>
      'پایانهٔ ناامن رد شد. از HTTPS استفاده کنید (HTTP ساده تنها روی میزبان محلی مجاز است).';

  @override
  String get soroushLocalModel => 'پایانهٔ محلی — نیازی به کلید API نیست';

  @override
  String get soroushProviders => 'سرویس‌دهنده‌های شناخته‌شده';

  @override
  String get greeterTitle => 'خوش‌آمدگو';

  @override
  String get greeterSubtitle =>
      'سلام‌های گرم — به‌صورت محلی یا ساختهٔ هوش مصنوعی سروش';

  @override
  String get greeterNameLabel => 'نام شما';

  @override
  String get greeterNameHint => 'خالی بگذارید تا به همه‌جهان سلام شود';

  @override
  String get greeterGreet => 'سلام کن';

  @override
  String get greeterAiGreet => 'سلام با هوش مصنوعی';

  @override
  String get greeterDefaultName => 'نام پیش‌فرض';

  @override
  String get greeterDefaultNameSaved => 'نام پیش‌فرض ذخیره شد';

  @override
  String get greeterGreetedWorld => 'به همه‌جهان سلام کردید';

  @override
  String greeterGreetedName(String name) {
    return 'به $name سلام کردید';
  }

  @override
  String get greeterNeedsAiKey =>
      'سلام هوش مصنوعی به کلید API نیاز دارد — آن را در سروش وارد کنید.';

  @override
  String get dashboardWelcome => 'خوش آمدید';

  @override
  String dashboardStep(int number) {
    return 'گام $number';
  }

  @override
  String get dashboardReady => 'آماده';

  @override
  String get dashboardPlanned => 'برنامه‌ریزی‌شده';

  @override
  String dashboardProgress(int done, int total) {
    return '$done از $total گام پیاده‌سازی شده';
  }

  @override
  String get haftKhanTitle => 'هفت‌خان — هفت خانِ کارها';

  @override
  String haftKhanStatsLine(int todo, int doing, int done, int overdue) {
    return '$todo انجام‌نشده · $doing در جریان · $done انجام‌شده · $overdue عقب‌افتاده';
  }

  @override
  String haftKhanStreak(int current, int best) {
    return 'زنجیره $current روز · بهترین $best';
  }

  @override
  String haftKhanDoneWindow(int today, int week) {
    return 'امروز $today کار · در ۷ روز گذشته $week کار';
  }

  @override
  String get haftKhanTabList => 'فهرست';

  @override
  String get haftKhanTabBoard => 'تخته';

  @override
  String get haftKhanTabMatrix => 'ماتریس';

  @override
  String get haftKhanTabReport => 'گزارش';

  @override
  String get haftKhanViewOpen => 'باز';

  @override
  String get haftKhanViewAll => 'همه';

  @override
  String get haftKhanViewDone => 'انجام‌شده';

  @override
  String get haftKhanViewToday => 'امروز';

  @override
  String get haftKhanViewOverdue => 'عقب‌افتاده';

  @override
  String get haftKhanFilterPriority => 'اولویت';

  @override
  String get haftKhanFilterTag => 'برچسب';

  @override
  String get haftKhanFilterProject => 'پروژه';

  @override
  String get haftKhanClearFilters => 'پاک کردن صافی‌ها';

  @override
  String get haftKhanSearchHint => 'جست‌وجو در عنوان، یادداشت، پروژه و برچسب';

  @override
  String get haftKhanEmptyView => 'کاری در این نما نیست.';

  @override
  String get haftKhanNoMatches => 'چیزی با این جست‌وجو یافت نشد.';

  @override
  String get haftKhanAddTask => 'افزودن یک کار';

  @override
  String get haftKhanFieldTitle => 'عنوان';

  @override
  String get haftKhanFieldNotes => 'یادداشت';

  @override
  String get haftKhanFieldDue => 'سررسید';

  @override
  String get haftKhanFieldDueHint =>
      '۲۰۲۶-۰۹-۲۵، فردا، دوشنبهٔ بعد، ۳ روز دیگر';

  @override
  String get haftKhanFieldPriority => 'اولویت';

  @override
  String get haftKhanFieldEffort => 'اندازهٔ کار';

  @override
  String get haftKhanFieldRecurrence => 'تکرار';

  @override
  String get haftKhanFieldInterval => 'فاصله';

  @override
  String get haftKhanFieldProject => 'پروژه';

  @override
  String get haftKhanFieldTags => 'برچسب‌ها';

  @override
  String get haftKhanFieldTagsHint => 'خانه، سریع';

  @override
  String get haftKhanFieldBlockedBy => 'وابسته به';

  @override
  String get haftKhanFieldBlockedByHint => 'شناسهٔ کارها، مثلاً ۱،۴';

  @override
  String get haftKhanStart => 'شروع';

  @override
  String get haftKhanComplete => 'انجام شد';

  @override
  String get haftKhanCompleteAnyway => 'با این حال انجام شد';

  @override
  String get haftKhanClearDone => 'پاک کردن انجام‌شده‌ها';

  @override
  String haftKhanClearedDone(int count) {
    return '$count کار انجام‌شده پاک شد.';
  }

  @override
  String haftKhanUndoDone(String operation, int count) {
    return '«$operation» بازگردانده شد ($count کار).';
  }

  @override
  String get haftKhanAiBreakdown => 'شکستن با هوش مصنوعی';

  @override
  String get haftKhanAiSummary => 'خلاصه با هوش مصنوعی';

  @override
  String haftKhanPlanHeader(int id, String title, String steps) {
    return 'نقشهٔ #$id — $title\n$steps';
  }

  @override
  String get haftKhanTransfer => 'درون‌ریزی و برون‌ریزی';

  @override
  String get haftKhanExportJson => 'رونوشت پشتیبان JSON';

  @override
  String get haftKhanExportMarkdown => 'رونوشت مارک‌داون';

  @override
  String haftKhanExported(int count) {
    return '$count کار در بریدگی‌دان رونوشت شد.';
  }

  @override
  String get haftKhanExportedMarkdown => 'سیاههٔ مارک‌داون رونوشت شد.';

  @override
  String get haftKhanImport => 'درون‌ریزی از کادر';

  @override
  String get haftKhanImportReplace => 'نخست همه پاک شود';

  @override
  String get haftKhanTransferHint => 'پشتیبان JSON را اینجا بچسبانید';

  @override
  String haftKhanImported(int tasks, int links) {
    return '$tasks کار و $links پیوند درون‌ریزی شد.';
  }

  @override
  String get haftKhanBadPayload => 'این داده خوانده نشد';

  @override
  String haftKhanAdded(int id, String title) {
    return 'افزوده شد #$id: $title';
  }

  @override
  String haftKhanStarted(int id, String title) {
    return 'آغاز شد #$id: $title';
  }

  @override
  String haftKhanConquered(int id, String title) {
    return 'انجام شد #$id: $title';
  }

  @override
  String haftKhanRespawned(int id, String title, String due) {
    return 'زاده شد #$id: $title (سررسید $due)';
  }

  @override
  String haftKhanRemoved(int id) {
    return 'حذف شد #$id.';
  }

  @override
  String get haftKhanOverdueLabel => 'عقب‌افتاده';

  @override
  String haftKhanBlockedBy(String ids) {
    return 'وابسته به $ids';
  }

  @override
  String haftKhanConqueredOn(String date) {
    return 'انجام‌شده در $date';
  }

  @override
  String haftKhanEvery(int interval, String kind) {
    return 'هر $interval $kind';
  }

  @override
  String get haftKhanColumnTodo => 'انجام‌نشده';

  @override
  String get haftKhanColumnDoing => 'در جریان';

  @override
  String get haftKhanColumnDone => 'انجام‌شده';

  @override
  String haftKhanColumnCount(int count) {
    return '$count کار';
  }

  @override
  String get haftKhanFocusTitle => 'تمرکز بعدی';

  @override
  String get haftKhanFocusSubtitle => 'هر بار یک گام کوتاه و شدنی';

  @override
  String formatDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get divanTitle => 'دیوان — دفتر یادداشت‌ها';

  @override
  String get divanSubtitle =>
      'یادداشت‌های مارک‌داون با دفترها، برچسب‌ها، پیوندهای ویکی، چک‌لیست‌ها، دفتر روزانه و جست‌وجوی متن کامل.';

  @override
  String divanStatNotebooks(Object count) {
    return '$count دفتر';
  }

  @override
  String divanStatNotes(Object count) {
    return '$count یادداشت';
  }

  @override
  String divanStatWords(Object count) {
    return '$count واژه';
  }

  @override
  String divanStatTodos(Object count) {
    return '$count کار باز';
  }

  @override
  String divanStatArchived(Object count) {
    return '$count بایگانی‌شده';
  }

  @override
  String get divanSearchHint => 'جست‌وجو در دیوان';

  @override
  String get divanFieldNotebook => 'دفتر';

  @override
  String get divanAllNotebooks => 'همهٔ دفترها';

  @override
  String get divanFieldTag => 'برچسب';

  @override
  String get divanAllTags => 'همهٔ برچسب‌ها';

  @override
  String get divanFilterPinned => 'سنجاق‌شده';

  @override
  String get divanFilterArchived => 'بایگانی‌شده';

  @override
  String get divanFilterChecklists => 'چک‌لیست‌ها';

  @override
  String get divanClearFilters => 'پاک کردن';

  @override
  String get divanNewNote => 'یادداشت تازه';

  @override
  String get divanNewNotebook => 'دفتر تازه';

  @override
  String get divanJournal => 'دفتر امروز';

  @override
  String get divanUndo => 'واگرد';

  @override
  String get divanRefresh => 'تازه‌سازی';

  @override
  String get divanTransfer => 'پرونده‌های مارک‌داون';

  @override
  String get divanSync => 'همگام‌سازی';

  @override
  String get divanNotebooks => 'دفترها';

  @override
  String get divanNotes => 'یادداشت‌ها';

  @override
  String get divanNoNotes => 'هنوز هیچ یادداشتی با این صافی‌ها نمی‌خواند.';

  @override
  String get divanArchivedLabel => 'بایگانی‌شده';

  @override
  String get divanNotebookMenu => 'کارهای دفتر';

  @override
  String get divanRenameNotebook => 'تغییر نام';

  @override
  String get divanArchiveNotebook => 'بایگانی';

  @override
  String get divanRestoreNotebook => 'بازگرداندن';

  @override
  String get divanDelete => 'حذف';

  @override
  String get divanNoSelection =>
      'از ستون کنار یک یادداشت را برگزینید یا یکی بسازید.';

  @override
  String get divanFieldTitle => 'عنوان';

  @override
  String get divanFieldTags => 'برچسب‌ها';

  @override
  String get divanFieldTagsHint => 'جدا شده با کاما، مانند کار، ایده';

  @override
  String get divanFieldBody => 'متن';

  @override
  String get divanFieldBodyHint =>
      'مارک‌داون — [[پیوندهای ویکی]] و - [ ] چک‌لیست‌ها کار می‌کنند';

  @override
  String get divanSave => 'ذخیره';

  @override
  String get divanPin => 'سنجاق';

  @override
  String get divanUnpin => 'بی‌سنجاق';

  @override
  String get divanArchive => 'بایگانی';

  @override
  String get divanRestore => 'بازگرداندن';

  @override
  String divanUpdatedAt(Object stamp) {
    return 'به‌روزرسانی: $stamp';
  }

  @override
  String divanMetricWords(Object count) {
    return '$count واژه';
  }

  @override
  String divanMetricCharacters(Object count) {
    return '$count نویسه';
  }

  @override
  String divanMetricReading(Object count) {
    return '$count ثانیه خواندن';
  }

  @override
  String divanMetricChecklist(int done, int total) {
    return 'چک‌لیست $done/$total';
  }

  @override
  String divanMetricLinks(Object count) {
    return '$count پیوند';
  }

  @override
  String get divanChecklist => 'چک‌لیست';

  @override
  String get divanLinks => 'پیوندهای ویکی';

  @override
  String get divanBacklinks => 'پیوندهای بازگشتی';

  @override
  String get divanBacklinksEmpty => 'هنوز چیزی به اینجا پیوند ندارد.';

  @override
  String get divanTodos => 'کارهای باز';

  @override
  String get divanTodoHint => 'افزودن موردی به دفتر امروز';

  @override
  String get divanAdd => 'افزودن';

  @override
  String get divanTodosEmpty => 'مورد بازِ چک‌لیستی نیست.';

  @override
  String get divanAi => 'هوش مصنوعی';

  @override
  String get divanAiClear => 'پاک کردن';

  @override
  String get divanAiSummarize => 'خلاصه';

  @override
  String get divanAiTitle => 'پیشنهاد عنوان';

  @override
  String get divanAiTags => 'پیشنهاد برچسب';

  @override
  String get divanAskHint => 'پرسشی از دیوان بپرسید';

  @override
  String get divanAiAsk => 'بپرس';

  @override
  String get divanAiApplyTitle => 'این عنوان را بگذار';

  @override
  String get divanAiApplyTags => 'این برچسب‌ها را بگذار';

  @override
  String get divanStats => 'آمار';

  @override
  String divanStatsDetail(int tagged, int links) {
    return '$tagged یادداشت برچسب‌دار · $links پیوند ویکی';
  }

  @override
  String get divanDismiss => 'بستن';

  @override
  String get divanTabNotes => 'یادداشت‌ها';

  @override
  String get divanTabEditor => 'ویرایشگر';

  @override
  String get divanTabTools => 'ابزارها';

  @override
  String get divanCancel => 'لغو';

  @override
  String divanDeleteNoteTitle(Object title) {
    return '«$title» حذف شود؟';
  }

  @override
  String divanDeleteNotebookTitle(Object name) {
    return '«$name» حذف شود؟';
  }

  @override
  String get divanDeleteNotebookBody =>
      'یادداشت‌هایش هم با آن حذف می‌شوند — این یک گام واگردشدنی است.';

  @override
  String get divanDeleteUndoable => 'این یک گام واگردشدنی است.';

  @override
  String get divanFieldFolder => 'پوشه';

  @override
  String get divanTransferHint =>
      'برون‌ریزی برای هر یادداشت فعال یک پروندهٔ .md می‌نویسد؛ درون‌ریزی هر پروندهٔ .md را یادداشتی تازه می‌کند.';

  @override
  String get divanExport => 'برون‌ریزی';

  @override
  String get divanImport => 'درون‌ریزی';

  @override
  String get divanSyncHint =>
      'ادغام دگرگونی‌های هر دو دستگاه را نگه می‌دارد؛ کشیدن هرگز روی دوردست نمی‌نویسد؛ راندن آن را جانشین می‌کند.';

  @override
  String get divanSyncMerge => 'ادغام';

  @override
  String get divanSyncPull => 'کشیدن';

  @override
  String get divanSyncPush => 'راندن';

  @override
  String get divanDefaultNotebook => 'دفتر پیش‌فرض';

  @override
  String get divanEditorWrite => 'نوشتن';

  @override
  String get divanEditorPreview => 'پیش‌نمایش';

  @override
  String get divanPreviewEmpty => 'هنوز چیزی برای پیش‌نمایش نیست.';

  @override
  String get ganjoorTitle => 'گنجور — کیف پول';

  @override
  String get ganjoorTabAccounts => 'حساب‌ها';

  @override
  String get ganjoorTabLedger => 'دفتر';

  @override
  String get ganjoorTabTools => 'گزارش‌ها و برنامه‌ها';

  @override
  String get ganjoorTotal => 'مجموع';

  @override
  String get ganjoorAccounts => 'حساب‌ها';

  @override
  String get ganjoorNoAccounts => 'هنوز حسابی نیست — برای شروع یکی بسازید.';

  @override
  String get ganjoorShowArchived => 'نمایش بایگانی‌شده‌ها';

  @override
  String get ganjoorAccountAdd => 'حساب تازه';

  @override
  String get ganjoorAccountName => 'نام';

  @override
  String get ganjoorAccountCurrency => 'واحد پول';

  @override
  String get ganjoorAccountStart => 'موجودی آغازین';

  @override
  String get ganjoorAccountArchived => 'بایگانی';

  @override
  String get ganjoorAccountArchive => 'بایگانی کن';

  @override
  String get ganjoorAccountUnarchive => 'از بایگانی بیرون بیاور';

  @override
  String get ganjoorAccountRename => 'تغییر نام';

  @override
  String get ganjoorAccountRemove => 'حذف حساب';

  @override
  String get ganjoorAccountRemoveConfirm =>
      'این حساب حذف شود و تاریخچه‌اش بماند؟';

  @override
  String get ganjoorAccountRemoveForce => 'این حساب تراکنش دارد';

  @override
  String get ganjoorCancel => 'لغو';

  @override
  String get ganjoorSave => 'ذخیره';

  @override
  String get ganjoorConfirm => 'تأیید';

  @override
  String get ganjoorQuickAdd => 'ثبت سریع';

  @override
  String get ganjoorKindSpend => 'هزینه';

  @override
  String get ganjoorKindEarn => 'درآمد';

  @override
  String get ganjoorKindTransfer => 'انتقال';

  @override
  String get ganjoorFrom => 'از';

  @override
  String get ganjoorTo => 'به';

  @override
  String get ganjoorAmount => 'مبلغ';

  @override
  String get ganjoorCategory => 'دسته';

  @override
  String get ganjoorNotes => 'یادداشت';

  @override
  String get ganjoorTags => 'برچسب‌ها';

  @override
  String get ganjoorDate => 'تاریخ (yyyy-MM-dd)';

  @override
  String get ganjoorAdd => 'افزودن';

  @override
  String get ganjoorLedger => 'دفتر';

  @override
  String get ganjoorLedgerEmpty => 'تراکنشی مطابق فیلترها نیست.';

  @override
  String get ganjoorRemoveTransaction => 'حذف تراکنش';

  @override
  String get ganjoorFilterAccount => 'حساب';

  @override
  String get ganjoorFilterKind => 'نوع';

  @override
  String get ganjoorFilterCategory => 'دسته (Enter)';

  @override
  String get ganjoorFilterAll => 'همه';

  @override
  String get ganjoorFilterQuery => 'جست‌وجو';

  @override
  String get ganjoorFilterClear => 'پاک کردن فیلترها';

  @override
  String get ganjoorPrevMonth => 'ماه پیش';

  @override
  String get ganjoorNextMonth => 'ماه بعد';

  @override
  String get ganjoorBudgets => 'بودجه‌ها';

  @override
  String get ganjoorBudgetEmpty => 'بودجه‌ای تعیین نشده.';

  @override
  String get ganjoorBudgetSet => 'ثبت بودجه';

  @override
  String get ganjoorBudgetRemove => 'حذف بودجه';

  @override
  String get ganjoorBudgetLimit => 'سقف ماهانه';

  @override
  String get ganjoorBudgetOver => 'فراتر از بودجه';

  @override
  String get ganjoorBudgetClose => 'نزدیک سقف';

  @override
  String get ganjoorBills => 'قبض‌ها';

  @override
  String get ganjoorBillEmpty => 'هنوز قبضی نیست.';

  @override
  String get ganjoorBillApply => 'ثبت سررسیدها';

  @override
  String get ganjoorBillRemove => 'حذف قبض';

  @override
  String get ganjoorBillDue => 'سررسید';

  @override
  String get ganjoorGoals => 'هدف‌ها';

  @override
  String get ganjoorGoalEmpty => 'هنوز هدفی نیست.';

  @override
  String get ganjoorGoalContribute => 'افزودن به هدف';

  @override
  String get ganjoorGoalWithdraw => 'برداشت از هدف';

  @override
  String get ganjoorGoalNearlyDone => 'نزدیک پایان';

  @override
  String get ganjoorDebts => 'بدهی‌ها';

  @override
  String get ganjoorDebtEmpty => 'بدهی‌ای ثبت نشده.';

  @override
  String get ganjoorDebtSettle => 'تسویه';

  @override
  String get ganjoorDebtRemove => 'حذف بدهی';

  @override
  String get ganjoorDebtOwedByMe => 'بدهکارید به';

  @override
  String get ganjoorDebtOwedToMe => 'طلبکارید از';

  @override
  String get ganjoorDebtOutstanding => 'باقی‌مانده';

  @override
  String get ganjoorDebtFullySettled => 'تسویه کامل';

  @override
  String get ganjoorReports => 'گزارش‌ها';

  @override
  String get ganjoorIncome => 'درآمد';

  @override
  String get ganjoorExpenses => 'هزینه';

  @override
  String get ganjoorNet => 'خالص';

  @override
  String get ganjoorTopCategories => 'بیشترین دسته‌ها';

  @override
  String get ganjoorUndo => 'بازگردانی';

  @override
  String get ganjoorRefresh => 'به‌روزرسانی';

  @override
  String get ganjoorTransfer => 'پشتیبان و فایل';

  @override
  String get ganjoorTransferPath => 'مسیر فایل';

  @override
  String get ganjoorExportJson => 'برون‌بری JSON';

  @override
  String get ganjoorImportJson => 'درون‌ریزی JSON';

  @override
  String get ganjoorExportCsv => 'برون‌بری CSV';

  @override
  String get ganjoorImportCsv => 'درون‌ریزی CSV';

  @override
  String get ganjoorCsvAccount => 'حساب مقصد CSV';

  @override
  String get ganjoorAi => 'دستیار مالی';

  @override
  String get ganjoorAiInsights => 'تحلیل';

  @override
  String get ganjoorAiAsk => 'بپرس';

  @override
  String get ganjoorAiQuestion => 'پرسش شما';

  @override
  String get ganjoorAiAnswer => 'پاسخ';

  @override
  String get ganjoorAiClear => 'پاک کردن';

  @override
  String get ganjoorAiCategorize => 'پیشنهاد دسته';

  @override
  String get ganjoorAiUnavailable => 'هوش مصنوعی در این حالت در دسترس نیست.';

  @override
  String ganjoorCount(int count) {
    return '$count مورد';
  }

  @override
  String ganjoorFromBill(int id) {
    return 'قبض #$id';
  }

  @override
  String ganjoorBillNext(String date) {
    return 'بعدی $date';
  }

  @override
  String ganjoorGoalDeadline(String date) {
    return 'تا $date';
  }

  @override
  String ganjoorDebtSettled(String amount) {
    return 'تسویه‌شده $amount';
  }

  @override
  String ganjoorNetWorth(String total) {
    return 'ارزش خالص: $total';
  }

  @override
  String ganjoorNetWorthBreakdown(
    String accounts,
    String receivable,
    String payable,
  ) {
    return 'حساب‌ها $accounts، طلب شما $receivable، بدهی شما $payable';
  }

  @override
  String get navSync => 'همگام‌سازی';

  @override
  String get syncTitle => 'همگام‌سازی';

  @override
  String get syncIntro =>
      'دو دستگاه روی یک سند برای هر سرویس به هم می‌رسند. هر اجرا دریافت می‌کند، بر پایهٔ شناسه ادغام می‌کند و نتیجهٔ ادغام‌شده را بازمی‌نویسد — بدون مکان‌نما و بدون چیزی که خراب شود.';

  @override
  String get syncDismiss => 'بستن';

  @override
  String get syncDeviceTitle => 'این دستگاه';

  @override
  String get syncDeviceHint =>
      'شناسه درون هر پاکت سفر می‌کند، تا دستگاه دیگر بداند سند راه دور را چه کسی مهر کرده است.';

  @override
  String get syncDeviceName => 'نام دستگاه';

  @override
  String get syncDeviceId => 'شناسهٔ دستگاه';

  @override
  String get syncSave => 'ذخیره';

  @override
  String get syncTokenSet => 'متغیر JAMEJAM_SYNC_TOKEN تنظیم شده است';

  @override
  String get syncTokenMissing =>
      'توکن همگام‌سازی نیست — سرور مقصد باید نوشتن بی‌نام را بپذیرد';

  @override
  String syncServiceTag(String service, String key) {
    return 'برچسب سرویس $service · ذخیره‌شده به‌نام $key';
  }

  @override
  String get syncUrl => 'نشانی همگام‌سازی';

  @override
  String syncEnvOverride(String url) {
    return 'متغیر JAMEJAM_SYNC_URL بر هر نشانی ذخیره‌شده اولویت دارد: $url';
  }

  @override
  String get syncMode => 'حالت';

  @override
  String get syncModeMerge => 'ادغام';

  @override
  String get syncModePull => 'دریافت';

  @override
  String get syncModePush => 'ارسال';

  @override
  String get syncModeMergeHint =>
      'دریافت، ادغام و نوشتن نتیجهٔ ادغام‌شده — هر دو دستگاه به هم می‌رسند.';

  @override
  String get syncModePullHint =>
      'دریافت و ادغام فقط روی این دستگاه؛ سند راه دور هرگز نوشته نمی‌شود.';

  @override
  String get syncModePushHint =>
      'جای‌گزینی سند راه دور با وضعیت این دستگاه. اگر سند راه دور تغییر دیگری داشته باشد، نخست می‌پرسد.';

  @override
  String get syncSaveUrl => 'ذخیرهٔ نشانی';

  @override
  String get syncRun => 'اکنون همگام کن';

  @override
  String get syncRulesTitle => 'چه چیزی همیشه برجاست';

  @override
  String get syncRuleHttps =>
      'فقط HTTPS — HTTP ساده تنها روی لوپ‌بک برای سرور محلی مجاز است.';

  @override
  String get syncRuleToken =>
      'توکن Bearer از JAMEJAM_SYNC_TOKEN می‌آید و هرگز ذخیره یا نمایش داده نمی‌شود.';

  @override
  String get syncRuleConverge =>
      'ادغام قطعی و جابه‌جایی‌پذیر است؛ پس اجراهای تکراری روی هر دستگاه به وضعیت یکسانی می‌رسند.';

  @override
  String get syncRuleRaz =>
      'راز هرگز همگام نمی‌شود: گاوصندوق روی همین دستگاه رمز می‌شود و به‌صورت طراحی‌شده آداپتوری ندارد.';

  @override
  String get syncProtocol =>
      'پروتکل انتقال: jamejam.sync/1 · یک سرویس برای هر نشانی';

  @override
  String get syncOverwriteTitle => 'سند راه دور بازنویسی شود؟';

  @override
  String get syncOverwrite => 'بازنویسی';

  @override
  String get syncCancel => 'انصراف';

  @override
  String get syncDeviceIdPending => 'در نخستین همگام‌سازی ساخته می‌شود';

  @override
  String get taqvimAgendaTitle => 'برنامه';

  @override
  String get taqvimAgendaSubtitle =>
      'رویدادهای بازهٔ انتخابی، همراه با نشان دادن تداخل‌های همین تقویم.';

  @override
  String get taqvimAgendaEmpty => 'در این بازه چیزی برنامه‌ریزی نشده است.';

  @override
  String get taqvimPreviousDay => 'روز پیشین';

  @override
  String get taqvimNextDay => 'روز بعد';

  @override
  String get taqvimRefresh => 'بارگذاری دوباره';

  @override
  String get taqvimUndo => 'واگرد آخرین تغییر';

  @override
  String get taqvimFilterCalendar => 'تقویم';

  @override
  String get taqvimFilterTag => 'برچسب';

  @override
  String get taqvimFilterApply => 'پالایش';

  @override
  String taqvimConflictCount(int count) {
    return '$count تداخل';
  }

  @override
  String taqvimStatEvents(int count) {
    return '$count رویداد';
  }

  @override
  String taqvimStatRecurring(int count) {
    return '$count تکرارشونده';
  }

  @override
  String taqvimStatAllDay(int count) {
    return '$count تمام‌روز';
  }

  @override
  String taqvimStatTagged(int count) {
    return '$count برچسب‌دار';
  }

  @override
  String taqvimStatReminders(int count) {
    return '$count یادآور';
  }

  @override
  String taqvimStatNextSevenDays(int count) {
    return '$count در ۷ روز آینده';
  }

  @override
  String taqvimStatBusyMinutes(int minutes) {
    return '$minutes دقیقه پرمشغله';
  }

  @override
  String get taqvimCaptureTitle => 'ثبت سریع';

  @override
  String get taqvimCaptureSubtitle =>
      'یک جمله بنویسید؛ تحلیل‌گر فرم را پر می‌کند. اگر جمله تاریخ یا ساعتی نداشته باشد چیزی ساخته نمی‌شود.';

  @override
  String get taqvimCaptureHint => 'ناهار با سارا سه‌شنبه آینده ساعت ۱';

  @override
  String get taqvimCaptureAction => 'ثبت';

  @override
  String get taqvimEditorNewTitle => 'رویداد تازه';

  @override
  String taqvimEditorEditTitle(int id) {
    return 'رویداد #$id';
  }

  @override
  String get taqvimEditorSubtitle =>
      'همان مرزهای خط فرمان: عنوان، پایان پس از آغاز، برچسب و یادآور کران‌دار.';

  @override
  String get taqvimEditorNewAction => 'تازه';

  @override
  String get taqvimFieldTitle => 'عنوان';

  @override
  String get taqvimFieldStart => 'آغاز';

  @override
  String get taqvimFieldEnd => 'پایان';

  @override
  String get taqvimWhenHint => '۲۰۲۶-۰۹-۲۱ ۱۴:۳۰ یا ۲۰۲۶-۰۹-۲۱ یا ۱۴:۳۰';

  @override
  String get taqvimFieldAllDay => 'تمام‌روز';

  @override
  String get taqvimFieldCalendar => 'تقویم';

  @override
  String get taqvimFieldLocation => 'مکان';

  @override
  String get taqvimFieldTags => 'برچسب‌ها';

  @override
  String get taqvimTagsHint => 'کار، تمرکز';

  @override
  String get taqvimFieldNotes => 'یادداشت';

  @override
  String get taqvimFieldRepeat => 'تکرار';

  @override
  String get taqvimFieldRepeatInterval => 'هر N بار';

  @override
  String get taqvimFieldReminders => 'یادآور (دقیقه پیش از رویداد)';

  @override
  String get taqvimRemindersHint => '۳۰، ۱۰';

  @override
  String get taqvimRepeatOnce => 'یک‌بار';

  @override
  String get taqvimRepeatDaily => 'روزانه';

  @override
  String get taqvimRepeatWeekly => 'هفتگی';

  @override
  String get taqvimRepeatMonthly => 'ماهانه';

  @override
  String get taqvimRepeatYearly => 'سالانه';

  @override
  String get taqvimSaveAdd => 'افزودن رویداد';

  @override
  String get taqvimSaveEdit => 'ذخیرهٔ تغییرات';

  @override
  String get taqvimDeleteAction => 'حذف';

  @override
  String get taqvimDeleteConfirmTitle => 'این رویداد حذف شود؟';

  @override
  String get taqvimDeleteConfirmBody =>
      'حذف ثبت می‌شود تا دستگاه‌های دیگر باخبر شوند. واگرد آن را بازمی‌گرداند.';

  @override
  String get taqvimScopeToday => 'امروز';

  @override
  String get taqvimScopeTomorrow => 'فردا';

  @override
  String get taqvimScopeWeek => 'این هفته';

  @override
  String get taqvimScopeMonth => 'این ماه';

  @override
  String get taqvimScopeUpcoming => 'پیش‌رو';

  @override
  String get taqvimSearchTitle => 'جست‌وجو';

  @override
  String get taqvimSearchSubtitle =>
      'جست‌وجوی متن کامل در عنوان، یادداشت و مکان — هر واژه باید بیاید.';

  @override
  String get taqvimSearchHint => 'دندان‌پزشک رادیوگرافی';

  @override
  String get taqvimSearchAction => 'جست‌وجو';

  @override
  String get taqvimSearchEmpty => 'هنوز جست‌وجویی انجام نشده است.';

  @override
  String get taqvimWindowsTitle => 'بازه‌های آزاد';

  @override
  String get taqvimWindowsSubtitle =>
      'فاصله‌های میان رویدادها در بازهٔ دلخواه روز؛ تداخل‌ها زیر برنامه نشان داده می‌شوند.';

  @override
  String get taqvimFieldDay => 'روز';

  @override
  String get taqvimDayHint => '۲۰۲۶-۰۹-۲۱';

  @override
  String get taqvimFieldFrom => 'از';

  @override
  String get taqvimFieldTo => 'تا';

  @override
  String get taqvimFieldMinutes => 'دقیقه';

  @override
  String get taqvimFreeAction => 'یافتن بازه‌های آزاد';

  @override
  String get taqvimFreeEmpty => 'هنوز بازهٔ آزادی محاسبه نشده است.';

  @override
  String taqvimFreeMinutesLabel(int minutes) {
    return '$minutes دقیقه آزاد';
  }

  @override
  String get taqvimTransferTitle => 'درون‌ریزی و برون‌ریزی (.ics)';

  @override
  String get taqvimTransferSubtitle =>
      'یک سند، حداکثر ۲۰۰۰ رویداد، زمان‌ها به وقت جهانی.';

  @override
  String get taqvimTransferAction => 'باز کردن جعبهٔ .ics';

  @override
  String get taqvimTransferBody =>
      'یک سند .ics را برای درون‌ریزی بچسبانید، یا جعبه را با برون‌ریزی کنونی پر کنید.';

  @override
  String get taqvimExportAction => 'پر کردن با برون‌ریزی';

  @override
  String get taqvimImportAction => 'درون‌ریزی';

  @override
  String get taqvimCopyAction => 'رونوشت';

  @override
  String get taqvimAiTitle => 'دستیار برنامه';

  @override
  String get taqvimAiSubtitle =>
      'درخواست‌ها برنامه را میان نشانگرهای ---EVENT BEGIN--- می‌گذارند و می‌گویند متن درونشان نامطمئن است.';

  @override
  String get taqvimAiBrief => 'خلاصهٔ روز';

  @override
  String get taqvimAiPlan => 'برنامهٔ هفته';

  @override
  String get taqvimAiCapture => 'پیشنهاد فرمان';

  @override
  String get taqvimAiAsk => 'بپرس';

  @override
  String get taqvimAiAskHint => 'نخستین ساعت آزاد من کِی است؟';

  @override
  String get taqvimAiEmpty => 'هنوز پاسخی نیست.';

  @override
  String taqvimAiSuggestion(String command) {
    return 'پیشنهاد (رونوشت کنید، بررسی کنید، سپس اجرا): $command';
  }

  @override
  String get settingsClearFilter => 'پاک کردن پالایه';

  @override
  String get soroushShowKey => 'نمایش کلید';

  @override
  String get soroushHideKey => 'پنهان کردن کلید';

  @override
  String get a11yToolboxGrid => 'گام‌های جعبه‌ابزار';

  @override
  String get a11yCalendarAgenda => 'برنامه';

  @override
  String get settingsMigrate => 'آوردن داده از جعبه‌ابزار .NET';

  @override
  String get migrationTitle => 'داده‌های پیشین را بیاورید';

  @override
  String get migrationSubtitle =>
      'پرونده‌ای را که جعبه‌ابزار .NET برون‌ریزی کرده بخوانید تا چیزی دوباره نوشته نشود.';

  @override
  String get migrationPaste => 'چسباندن از کلیپ‌بورد';

  @override
  String get migrationTextLabel => 'پروندهٔ برون‌ریزی‌شده';

  @override
  String get migrationTextHint =>
      'یک پشتیبان .json یا تقویم .ics را اینجا بچسبانید';

  @override
  String get migrationImport => 'درون‌ریزی';

  @override
  String get migrationNothing => 'هنوز چیزی چسبانده نشده.';

  @override
  String get migrationNotJson => 'این متن نه JSON است و نه سند .ics.';

  @override
  String get migrationNotADocument =>
      'این JSON سندی نیست که این برنامه بخواند.';

  @override
  String get migrationKindHaftKhan => 'پشتیبان هفت‌خان';

  @override
  String get migrationKindGanjoor => 'پشتیبان کیف پول گنجور';

  @override
  String get migrationKindRaz => 'بستهٔ گنجینهٔ راز';

  @override
  String get migrationKindTaqvim => 'تقویم (.ics)';

  @override
  String get migrationNoteHaftKhan =>
      'هفت‌خان: پروندهٔ .json که haftkhan export نوشته است (نگارش‌های ۱ و ۲).';

  @override
  String get migrationNoteGanjoor =>
      'گنجور: پروندهٔ .json که ganjoor export نوشته است.';

  @override
  String get migrationNoteRaz =>
      'راز: پروندهٔ .json که raz export نوشته است؛ نخست گنجینه را باز کنید — بسته با همان گذرواژه‌ای باز می‌شود که با آن ساخته شده است.';

  @override
  String get migrationNoteTaqvim =>
      'تقویم: پروندهٔ .ics که taqvim export نوشته است.';

  @override
  String get migrationNoteLocal =>
      'دیوان پوشه‌ای از پرونده‌های مارک‌داون را از پنل انتقال خودش می‌خواند، و پرونده‌های SQLite همان نام و همان ساختار .NET را دارند — پوشهٔ ~/.jamejam موجود در جای خود خوانده می‌شود.';

  @override
  String migrationVersion(int version) {
    return 'نگارش $version';
  }

  @override
  String migrationTasks(int count) {
    return '$count کار';
  }

  @override
  String migrationLinks(int count) {
    return '$count پیوند';
  }

  @override
  String migrationAccounts(int count) {
    return '$count حساب';
  }

  @override
  String migrationTransactions(int count) {
    return '$count تراکنش';
  }

  @override
  String migrationBudgets(int count) {
    return '$count بودجه';
  }

  @override
  String migrationEvents(int count) {
    return '$count رویداد';
  }

  @override
  String migrationResult(String kind, int count) {
    return '$kind درون‌ریزی شد: $count مورد.';
  }
}
