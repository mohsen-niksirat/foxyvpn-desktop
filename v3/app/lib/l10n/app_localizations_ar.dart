// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'نظرة عامة';

  @override
  String get navAccounts => 'الحسابات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get stateConnected => 'متصل';

  @override
  String get stateConnecting => 'جارٍ الاتصال…';

  @override
  String get stateWaiting => 'في الانتظار';

  @override
  String get waitingForAccount =>
      'أضف Firefox Account من صفحة الحسابات للاتصال.';

  @override
  String get waitingForEnabledAccount =>
      'كل الحسابات متوقفة. شغّل أحدها من صفحة الحسابات.';

  @override
  String get stateError => 'خطأ';

  @override
  String get stateUnknown => 'غير معروف';

  @override
  String get restartProxy => 'إعادة تشغيل البروكسي';

  @override
  String copied(String value) {
    return 'تم نسخ $value';
  }

  @override
  String get activeAccount => 'الحساب النشط';

  @override
  String get noActiveAccount => 'لا يوجد حساب نشط';

  @override
  String get quotaNotRead => 'لم يُعرف الرصيد بعد';

  @override
  String get unlimited => 'غير محدود';

  @override
  String usedOf(String used, String limit) {
    return 'استُخدم $used من $limit';
  }

  @override
  String resets(String date) {
    return 'يُصفَّر في $date';
  }

  @override
  String switchAt(int percent) {
    return 'يُبدَّل الحساب عند $percent%';
  }

  @override
  String get publicIp => 'عنوان IP العام';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get testing => 'جارٍ الاختبار…';

  @override
  String get testFailed => 'فشل';

  @override
  String milliseconds(int value) {
    return '$value مللي ثانية';
  }

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(int n) {
    return 'منذ $n دقيقة';
  }

  @override
  String hoursAgo(int n) {
    return 'قبل $n ساعة';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return 'في $time';
  }

  @override
  String durationDays(int d, int h) {
    return '$d ي $h س';
  }

  @override
  String durationHours(int h, int m) {
    return '$h س $m د';
  }

  @override
  String durationMinutes(int m, int s) {
    return '$m د $s ث';
  }

  @override
  String durationSeconds(int s) {
    return '$s ث';
  }

  @override
  String accountsGuide(String size) {
    return 'لكل Firefox Account رصيد $size شهريًا. يمكنك إضافة عدة حسابات: عندما ينفد أحدها، ينتقل التطبيق إلى التالي تلقائيًا.';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'بترتيب هذه القائمة: كل حساب حتى $percent٪، والحساب الأخير حتى نفاد بياناته.';
  }

  @override
  String get addAccount => 'إضافة حساب';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'رصيد الحساب الحالي على وشك النفاد (تبقّى $left). أضف حسابًا آخر لتحصل على $size إضافية.';
  }

  @override
  String get noAccounts => 'لا توجد حسابات بعد';

  @override
  String get noAccountsHint => 'أضف Firefox Account للاتصال.';

  @override
  String get createAccountTitle => 'ليس لديك Firefox Account؟';

  @override
  String get createAccountHint =>
      'أنشئ حسابًا مجانيًا على accounts.firefox.com، ثم عد واضغط «إضافة حساب».';

  @override
  String get moveUp => 'نقل لأعلى';

  @override
  String get moveDown => 'نقل لأسفل';

  @override
  String get statusActive => 'نشط';

  @override
  String get statusReady => 'جاهز';

  @override
  String get statusNeedsSignIn => 'يلزم تسجيل الدخول';

  @override
  String get statusReserved => 'محجوز';

  @override
  String get statusUnavailable => 'غير متاح';

  @override
  String statusUnavailableUntil(String date) {
    return 'غير متاح حتى $date';
  }

  @override
  String get statusDisabled => 'معطّل';

  @override
  String get statusEnabled => 'مفعّل';

  @override
  String get useNow => 'استخدام الآن';

  @override
  String get signInAgain => 'تسجيل الدخول مجددًا';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'بلغ استهلاك هذا الحساب $percent%، فتولّى الحساب التالي.';
  }

  @override
  String get reasonQuotaExhausted =>
      'نفد رصيد هذا الشهر؛ يُستخدم مجددًا بعد التصفير الشهري.';

  @override
  String get reasonSignInRequired => 'سجّل الدخول مجددًا لاستخدام هذا الحساب.';

  @override
  String get reasonSignInConfirm =>
      'تطلب Mozilla تأكيد تسجيل الدخول: اضغط «تسجيل الدخول مجددًا» (يلزم الرمز فقط).';

  @override
  String reasonSignInFailed(String detail) {
    return 'فشل تسجيل الدخول التلقائي ($detail). سجّل الدخول مجددًا.';
  }

  @override
  String reasonSignInWait(String time) {
    return 'توقف آخر تسجيل دخول تلقائي عن العمل بعد قليل؛ المحاولة التالية الساعة $time.';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'لم يكتمل تسجيل الدخول التلقائي ($detail)؛ ستتم المحاولة مجددًا الساعة $time.';
  }

  @override
  String get reasonNotEntitled =>
      'رفضت Mozilla هذا الحساب؛ ستتم المحاولة لاحقًا.';

  @override
  String get more => 'المزيد';

  @override
  String get refreshQuota => 'تحديث الرصيد';

  @override
  String get remove => 'إزالة';

  @override
  String get removeTitle => 'إزالة الحساب؟';

  @override
  String removeBody(String name) {
    return 'سيُحذف الحساب $name وبيانات دخوله المحفوظة من هذا الكمبيوتر. يمكنك إضافته مرة أخرى لاحقًا.';
  }

  @override
  String get unlimitedQuota => 'رصيد غير محدود';

  @override
  String get signInTitle => 'تسجيل الدخول';

  @override
  String get signInIntro => 'سجّل الدخول باستخدام Firefox Account.';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailInvalid => 'أدخل البريد الإلكتروني للحساب';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordEmpty => 'أدخل كلمة المرور';

  @override
  String get show => 'إظهار';

  @override
  String get hide => 'إخفاء';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get done => 'تم';

  @override
  String get close => 'إغلاق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get tryAgain => 'إعادة المحاولة';

  @override
  String get signingIn => 'جارٍ تسجيل الدخول…';

  @override
  String get accountReady => 'الحساب جاهز';

  @override
  String get accountReadyHint => 'أُضيف في آخر قائمة الحسابات.';

  @override
  String get captchaLabel => 'الأحرف في الصورة';

  @override
  String get codeLabel => 'الرمز';

  @override
  String get captchaBroken => 'تعذّر عرض صورة CAPTCHA.';

  @override
  String stepEmailCode(String email) {
    return 'أرسلت Mozilla رمزًا إلى $email. أدخله هنا.';
  }

  @override
  String get stepTotp => 'أدخل الرمز من تطبيق المصادقة.';

  @override
  String stepUnblockCode(String email) {
    return 'رصدت Mozilla تسجيل دخول غير معتاد، وأرسلت رمز إلغاء الحظر إلى $email. أدخله هنا.';
  }

  @override
  String get stepCaptcha => 'اكتب الأحرف الظاهرة في الصورة.';

  @override
  String stepEmailLink(String email) {
    return 'افتح رابط التأكيد الذي أرسلته Mozilla إلى $email. ستستمر العملية تلقائيًا.';
  }

  @override
  String get signInFailed => 'لم تتم إضافة الحساب.';

  @override
  String get signInCancelled => 'أُلغي تسجيل الدخول.';

  @override
  String get signInNoAccount =>
      'لا يوجد Firefox Account بهذا البريد الإلكتروني.';

  @override
  String get signInNoAccountHint =>
      'تحقق من البريد الإلكتروني، أو أنشئ به Firefox Account مجانيًا على موقع Mozilla، وأكّده من بريدك، ثم أضفه هنا.';

  @override
  String get createAccountButton => 'إنشاء Firefox Account';

  @override
  String get signInWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get signInNoPassword =>
      'هذا الحساب بلا كلمة مرور: أُنشئ عبر تسجيل الدخول بـ Google أو Apple. عيّن كلمة مرور، ثم سجّل الدخول بها هنا.';

  @override
  String get setPasswordButton => 'تعيين كلمة مرور';

  @override
  String get signInTooManyAttempts =>
      'محاولات كثيرة جدًا. انتظر قليلًا ثم أعد المحاولة.';

  @override
  String get signInUnblockRejected =>
      'لم يُقبل رمز إلغاء الحظر. استخدم الرمز من أحدث رسالة من Mozilla.';

  @override
  String get signInWrongCode =>
      'الرمز خاطئ أو منتهي الصلاحية. استخدم الرمز من أحدث رسالة من Mozilla؛ يتوقف الرمز القديم عن العمل عند إرسال رمز جديد.';

  @override
  String get signInWrongTotp =>
      'الرمز خاطئ. أدخل الرمز الذي يعرضه تطبيق المصادقة الآن.';

  @override
  String get signInTooManyCodes =>
      'رموز خاطئة كثيرة جدًا. ابدأ تسجيل الدخول من جديد.';

  @override
  String get signInTimedOut =>
      'استغرق تسجيل الدخول وقتًا طويلًا. ابدأه من جديد.';

  @override
  String get signInNetwork =>
      'تعذّر الوصول إلى Mozilla. تحقق من الإنترنت وأعد المحاولة.';

  @override
  String get coreConnecting => 'جارٍ الاتصال بالنواة…';

  @override
  String get coreLost => 'انقطع الاتصال بالنواة. جارٍ إعادة المحاولة…';

  @override
  String get cantReachCore => 'تعذّر الوصول إلى النواة';

  @override
  String get startingCore => 'جارٍ تشغيل النواة…';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String errNoCore(String path) {
    return 'لم يُعثر على برنامج النواة بجوار التطبيق ($path).';
  }

  @override
  String errCoreExited(String detail) {
    return 'توقفت النواة: $detail';
  }

  @override
  String get errNotAnswering => 'النواة لا تستجيب.';

  @override
  String get errRefused =>
      'رفضت النواة الاتصال بالتطبيق؛ ربما تعود لنسخة أخرى منه.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get sectionGeneral => 'عام';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'لغة النظام';

  @override
  String get theme => 'المظهر';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get closeBehavior => 'عند إغلاق النافذة';

  @override
  String get closeAsk => 'السؤال في كل مرة';

  @override
  String get closeTray => 'الإخفاء بجوار الساعة';

  @override
  String get closeQuit => 'إنهاء التطبيق';

  @override
  String get sectionConnection => 'الاتصال';

  @override
  String get localProxy => 'البروكسي المحلي';

  @override
  String get systemProxy => 'بروكسي النظام';

  @override
  String get sectionRouting => 'التوجيه';

  @override
  String get routingDirect => 'اتصال مباشر للمواقع المحلية';

  @override
  String get routingDirectHint =>
      'مواقع البلد المختار وعناوين IP الخاصة به تتصل مباشرةً دون VPN، فتُفتح أسرع وتوفّر من رصيدك.';

  @override
  String get region => 'البلد';

  @override
  String get regionIr => 'إيران';

  @override
  String get regionCn => 'الصين';

  @override
  String get regionRu => 'روسيا';

  @override
  String get regionAf => 'أفغانستان';

  @override
  String get regionTr => 'تركيا';

  @override
  String get regionId => 'إندونيسيا';

  @override
  String get regionBr => 'البرازيل';

  @override
  String get regionNone => 'لا شيء';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get dataFolder => 'مجلد البيانات';

  @override
  String get openFolder => 'فتح المجلد';

  @override
  String get unofficialNote => 'عميل غير رسمي. لا صلة له بـ Mozilla.';

  @override
  String get closeTitle => 'إغلاق النافذة؟';

  @override
  String get closeBody =>
      'عند الإخفاء بجوار الساعة يبقى VPN متصلًا، أما الإنهاء فيقطعه.';

  @override
  String get rememberChoice => 'تذكّر اختياري';

  @override
  String get minimizeToTray => 'إخفاء بجوار الساعة';

  @override
  String get quit => 'إنهاء';

  @override
  String get trayOpen => 'فتح';

  @override
  String get trayQuit => 'إنهاء';

  @override
  String get trayProxyOnly => 'خدمة البروكسي فقط';

  @override
  String get traySetSystemProxy => 'تعيين بروكسي النظام';

  @override
  String errPortInUse(String port) {
    return 'المنفذ $port يستخدمه برنامج آخر، لذا لا يستطيع التطبيق الوصول إلى نواته.';
  }

  @override
  String proxyPortInUse(String port) {
    return 'تعذّر تشغيل البروكسي لأن برنامجًا آخر يستخدم المنفذ $port.';
  }

  @override
  String get changePort => 'تغيير المنفذ';

  @override
  String get portDialogTitle => 'اختر منفذًا';

  @override
  String portDialogBody(String port) {
    return 'المنفذ $port مشغول. نقترح أدناه منفذًا متاحًا؛ ويمكنك كتابة منفذ آخر.';
  }

  @override
  String get portChangeBody =>
      'تتصل التطبيقات بهذا المنفذ. اختر منفذًا بين 1024 و65535.';

  @override
  String get portLabel => 'المنفذ';

  @override
  String get portInvalid => 'أدخل منفذًا من 1024 إلى 65535';

  @override
  String get portBusy => 'هذا المنفذ مستخدم أيضًا';

  @override
  String get portInUse => 'برنامج آخر يستخدم هذا المنفذ';

  @override
  String get save => 'حفظ';

  @override
  String get proxyPort => 'منفذ البروكسي';

  @override
  String get appPort => 'منفذ التطبيق';

  @override
  String get welcomeTitle => 'مرحبًا';

  @override
  String get welcomeBody =>
      'اختر لغتك وبلدك. تُفتح مواقع بلدك مباشرةً دون VPN، فتكون أسرع وتوفّر من رصيدك.';

  @override
  String get start => 'ابدأ';

  @override
  String routingSuggestTitle(String country) {
    return 'فتح مواقع $country مباشرةً؟';
  }

  @override
  String routingSuggestBody(String country) {
    return 'ستُفتح مواقع وعناوين IP الخاصة بـ $country مباشرةً دون VPN. يمكنك تغيير ذلك في التوجيه.';
  }

  @override
  String get yes => 'نعم';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get navServers => 'الخوادم';

  @override
  String get navLogs => 'السجلات';

  @override
  String get realDelay => 'التأخير الفعلي';

  @override
  String noticePort(String port) {
    return 'بروكسي Mozilla لا يتصل بالمنفذ $port. لا تمر عبر VPN إلا المنافذ 80 و443 و8080 و8443.';
  }

  @override
  String get noticeCommand =>
      'طلب أحد التطبيقات اتصال UDP (الألعاب والمكالمات الصوتية والمرئية). بروكسي Mozilla لا ينقل إلا TCP، لذا لا يمكن تمريره.';

  @override
  String noticeTimes(int count, String time) {
    return '$count مرة، آخرها $time';
  }

  @override
  String get dismiss => 'تجاهل';

  @override
  String get modeRecommended => 'مُوصى به';

  @override
  String get modeFastest => 'الأسرع';

  @override
  String get modeRecommendedHint => 'تختار Mozilla الموقع نيابةً عنك.';

  @override
  String get modeFastestHint => 'الموقع الأقل تأخيرًا عند كل اتصال.';

  @override
  String get testDelay => 'اختبار التأخير الفعلي';

  @override
  String get testingDelay => 'جارٍ الاختبار… قد يستغرق ذلك دقيقة';

  @override
  String get search => 'بحث';

  @override
  String get noAnswer => 'لا استجابة';

  @override
  String testedAgo(String ago) {
    return 'اختُبر $ago';
  }

  @override
  String delaySummary(int answered, int total) {
    return 'استجاب $answered من $total';
  }

  @override
  String get noServers =>
      'لا توجد خوادم بعد. ستظهر بمجرد وصول النواة إلى Mozilla.';

  @override
  String get levelAll => 'الكل';

  @override
  String get filter => 'تصفية';

  @override
  String get follow => 'تمرير تلقائي';

  @override
  String get clear => 'مسح';

  @override
  String get copyAll => 'نسخ';

  @override
  String get logsCopied => 'تم نسخ السجلات';

  @override
  String get noLogs => 'السجل فارغ حتى الآن.';

  @override
  String get sectionAccounts => 'تبديل الحساب تلقائيًا';

  @override
  String get switchThreshold => 'تبديل الحساب عند';

  @override
  String get switchThresholdHint =>
      'ينتقل التطبيق إلى الحساب التالي عند استهلاك هذه النسبة من الرصيد.';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'خوادم DNS';

  @override
  String get dnsSystem => 'النظام';

  @override
  String get dnsAuto => 'تلقائي (Cloudflare وGoogle وQuad9)';

  @override
  String get dnsCustom => 'مخصص';

  @override
  String get dnsCustomHint =>
      'واحد في كل سطر: https://…/dns-query أو tls://… أو عنوان IP.';

  @override
  String get dnsFallback => 'الرجوع إلى DNS النظام';

  @override
  String get testDns => 'اختبار DNS';

  @override
  String get transport => 'البروتوكول';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'مباشر';

  @override
  String get directRulesHint =>
      'تُفتح المواقع والعناوين في هذه القائمة دون VPN، مباشرةً عبر اتصالك بالإنترنت. قواعد البلد الذي اخترته موجودة هنا مسبقًا: يمكنك إضافة أسطر أو تعديلها أو حذفها. اختيار بلد آخر يستبدلها بقواعده.';

  @override
  String get restoreRegionRules => 'استعادة قواعد البلد';

  @override
  String get blockRules => 'حظر';

  @override
  String get blockRulesHint =>
      'لا تُفتح المواقع والعناوين في هذه القائمة إطلاقًا، لا مباشرةً ولا عبر VPN: للإعلانات أو للمواقع التي لا تريد الوصول إليها أبدًا.';

  @override
  String get rulesTitle => 'القواعد';

  @override
  String get ruleSyntaxTitle => 'طريقة كتابة القواعد';

  @override
  String get resolveDomains => 'تطبيق قواعد IP على النطاقات';

  @override
  String get routingLists => 'ملفات geo';

  @override
  String get listSource => 'مصدر القوائم';

  @override
  String get listSourceCustom => 'مضبوط يدويًا';

  @override
  String listsUpdatedAgo(String ago) {
    return 'آخر تحديث: $ago';
  }

  @override
  String get updateLists => 'تحديث ملفات geo';

  @override
  String get listsUpdated => 'تم تحديث ملفات geo.';

  @override
  String get testDestination => 'فحص المسار';

  @override
  String get destinationHint => 'اسم نطاق أو عنوان IP أو رابط';

  @override
  String get check => 'فحص';

  @override
  String get routeDirect => 'يمر مباشرةً';

  @override
  String get routeProxy => 'يمر عبر VPN';

  @override
  String get routeBlock => 'محظور';

  @override
  String ruleMatched(String rule) {
    return 'القاعدة: $rule';
  }

  @override
  String get portRefusedNote => 'بروكسي Mozilla لا يتصل بهذا المنفذ.';

  @override
  String get sectionAdvanced => 'متقدم';

  @override
  String get listenAddress => 'الوصول إلى البروكسي';

  @override
  String get listenLocal => '127.0.0.1 · هذا الجهاز فقط';

  @override
  String get listenAll => '0.0.0.0 · كل الشبكات (LAN)';

  @override
  String get proxyUsername => 'اسم مستخدم البروكسي';

  @override
  String get proxyPassword => 'كلمة مرور البروكسي';

  @override
  String get proxyLoginHint =>
      'يجب على التطبيقات إدخال هذه البيانات للاتصال بالبروكسي. اتركهما فارغين للاتصال دونها.';

  @override
  String get loginBothOrNone => 'املأ الحقلين معًا، أو اترك كليهما فارغين.';

  @override
  String get proxyLogin => 'مصادقة البروكسي';

  @override
  String get idleSleep => 'السكون بعد الخمول لمدة';

  @override
  String get sleepNever => 'أبدًا';

  @override
  String sleepMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get sleepHour => 'ساعة واحدة';

  @override
  String get showPublicIp => 'إظهار عنوان IP العام';

  @override
  String get speedInNotification => 'عرض السرعة في الإشعار';

  @override
  String get liveTraffic => 'حركة البيانات الآن';

  @override
  String get totalTraffic => 'إجمالي البيانات';

  @override
  String get verboseLogs => 'سجلات مفصّلة';

  @override
  String get webDashboard => 'لوحة التحكم عبر الويب';

  @override
  String get webDashboardOpen => 'فتح';

  @override
  String get webDashboardHint => 'إعدادات متقدمة وأدوات إضافية';

  @override
  String numberInvalid(int min, int max) {
    return 'أدخل رقمًا من $min إلى $max';
  }

  @override
  String get notifySwitchedTitle => 'تم تبديل الحساب';

  @override
  String notifySwitchedBody(String name) {
    return 'يُستخدم الآن $name.';
  }

  @override
  String get notifySignInTitle => 'يلزم تسجيل الدخول';

  @override
  String get notifySignInBody =>
      'أحد الحسابات يحتاج إلى تسجيل الدخول مجددًا من صفحة الحسابات.';

  @override
  String get navAbout => 'حول';

  @override
  String get appVersionLabel => 'إصدار التطبيق';

  @override
  String get coreVersionLabel => 'إصدار النواة';

  @override
  String get checkUpdates => 'التحقق من التحديثات';

  @override
  String get checkingUpdates => 'جارٍ التحقق…';

  @override
  String get upToDate => 'لديك أحدث إصدار.';

  @override
  String updateAvailable(String version) {
    return 'الإصدار $version متاح.';
  }

  @override
  String get download => 'تنزيل';

  @override
  String updateCheckFailed(String error) {
    return 'تعذّر التحقق من التحديثات: $error';
  }

  @override
  String get repoNotSet => 'لم يُحدَّد مستودع GitHub بعد.';

  @override
  String get sourceCode => 'الشيفرة المصدرية';

  @override
  String get tapToConnect => 'انقر للاتصال';

  @override
  String get tapToDisconnect => 'انقر لقطع الاتصال';

  @override
  String get startOnBoot => 'التشغيل عند بدء النظام';

  @override
  String get connectOnStartup => 'الاتصال تلقائيًا عند بدء التشغيل';

  @override
  String get proxyServiceActive => 'خدمة البروكسي تعمل';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get groupApp => 'التطبيق';

  @override
  String get stateOff => 'غير متصل';

  @override
  String get tapToConnectPhone => 'اضغط للاتصال';

  @override
  String get tapToDisconnectPhone => 'اضغط لقطع الاتصال';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'الموقع المُوصى به';

  @override
  String dataLeftOf(String limit) {
    return 'من $limit';
  }

  @override
  String get homeLocation => 'الموقع';

  @override
  String get connectedTo => 'متصل بـ';

  @override
  String get vpnNotAllowed => 'يحتاج VPN إلى إذنك. اضغط الزر مجددًا واسمح به.';

  @override
  String get dataUsedTitle => 'البيانات المستخدمة';

  @override
  String get bypassApps => 'بروكسي لكل تطبيق';

  @override
  String get connectRetrying => 'تعذّر الاتصال. تحقّق من الإنترنت.';

  @override
  String get failUnreachable =>
      'خوادم Mozilla محجوبة على هذا الإنترنت. جرّب اتصال إنترنت آخر.';

  @override
  String get failRefused =>
      'رفض خادم Mozilla الاتصال. حاول مجددًا بعد بضع دقائق.';

  @override
  String get failLocationRefused =>
      'هذه الدولة غير متاحة لحسابك. اختر دولة أخرى.';

  @override
  String get useRecommendedLocation => 'استخدام الموقع المُوصى به';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'اخترت $chosen، لكن عنوان IP الخاص بك في $exit.';
  }

  @override
  String get failSignIn =>
      'انتهت صلاحية تسجيل دخول هذا الحساب. سجّل الدخول مجددًا من صفحة الحسابات.';

  @override
  String get failQuota => 'نفدت بيانات هذا الشهر. أضف حسابًا آخر.';

  @override
  String get failNotEntitled =>
      'لا تسمح Mozilla لهذا الحساب باستخدام VPN. أضف حسابًا آخر.';

  @override
  String get failRegion => 'لا تقدّم Mozilla خدمتها في بلدك.';

  @override
  String get failServer =>
      'خدمة Mozilla بها مشكلة مؤقتة. سيعيد التطبيق المحاولة تلقائيًا.';

  @override
  String get failNoAccount => 'لا يوجد حساب جاهز. افتح صفحة الحسابات.';

  @override
  String get failTestSite =>
      'تم الاتصال بالخادم، لكن المواقع لا تفتح. جرّب دولة أخرى.';

  @override
  String get failOther => 'تعذّر الاتصال. حاول مجددًا.';

  @override
  String get failNoInternet =>
      'لا يوجد اتصال بالإنترنت. تحقّق من Wi-Fi أو بيانات الجوال.';

  @override
  String get waitingForNetwork => 'في انتظار الاتصال بالإنترنت…';

  @override
  String proxyStartFailed(String port) {
    return 'تعذّر تشغيل البروكسي على المنفذ $port. اختر منفذًا آخر.';
  }

  @override
  String get connectionSettings => 'إعدادات الاتصال';

  @override
  String get appModeExclude => 'استثناء التطبيقات المحددة';

  @override
  String get appModeInclude => 'تمرير التطبيقات المحددة فقط';

  @override
  String get appModeExcludeHint =>
      'تتصل التطبيقات المحددة مباشرةً، لا عبر VPN: مثل تطبيقات البنوك التي ترفض العناوين الأجنبية.';

  @override
  String get appModeIncludeHint =>
      'تمر التطبيقات المحددة فقط عبر VPN؛ وتتصل البقية مباشرةً.';

  @override
  String fromRegionList(String region) {
    return 'مقترح: من قائمة $region';
  }

  @override
  String get modeProxy => 'بروكسي';

  @override
  String get connectionMode => 'وضع الاتصال';

  @override
  String get modeProxyHint =>
      'تمر عبره فقط التطبيقات المضبوطة على استخدام البروكسي؛ ولا يتغير شيء في Windows.';

  @override
  String get modeSystemProxyHint => 'يمر Windows ومعظم التطبيقات عبر البروكسي.';

  @override
  String get modeProxyHintOther =>
      'تمر عبره فقط التطبيقات المضبوطة على استخدام البروكسي؛ ولا يتغير شيء في إعدادات النظام.';

  @override
  String get modeSystemProxyHintOther =>
      'تمر المتصفحات ومعظم التطبيقات عبر البروكسي.';

  @override
  String get suggestedApps => 'التطبيقات المقترحة';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count تطبيق مقترح',
      many: 'تم تحديد $count تطبيقًا مقترحًا',
      few: 'تم تحديد $count تطبيقات مقترحة',
      two: 'تم تحديد تطبيقين مقترحين',
      one: 'تم تحديد تطبيق مقترح واحد',
      zero: 'التطبيقات المقترحة محددة بالفعل',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'تلقائي';

  @override
  String get locationsSection => 'المواقع';

  @override
  String get dnsSummaryOk => 'DNS المشفّر يعمل';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر حل $count اسم',
      many: 'تعذّر حل $count اسمًا',
      few: 'تعذّر حل $count أسماء',
      two: 'تعذّر حل اسمين',
      one: 'تعذّر حل اسم واحد',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return 'عبر $server';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أعاد DNS شبكتك عنوان حجب لـ $count اسم، ولا يستخدمه هذا التطبيق.',
      many:
          'أعاد DNS شبكتك عنوان حجب لـ $count اسمًا، ولا يستخدمه هذا التطبيق.',
      few: 'أعاد DNS شبكتك عنوان حجب لـ $count أسماء، ولا يستخدمه هذا التطبيق.',
      two: 'أعاد DNS شبكتك عنوان حجب لاسمين، ولا يستخدمه هذا التطبيق.',
      one: 'أعاد DNS شبكتك عنوان حجب لاسم واحد، ولا يستخدمه هذا التطبيق.',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'الإجابة:';

  @override
  String get dnsNetworkAnswer => 'DNS الشبكة:';

  @override
  String get dnsFiltered => 'محجوب';

  @override
  String get rulesSyntaxTitle => 'قاعدة واحدة في كل سطر';

  @override
  String get ruleDomain => 'الموقع ونطاقاته الفرعية';

  @override
  String get ruleFull => 'هذا الاسم بالضبط';

  @override
  String get ruleKeyword => 'الأسماء التي تحتوي على الكلمة';

  @override
  String get ruleGeosite => 'مواقع فئة من ملفات geo';

  @override
  String get ruleGeoip => 'عناوين IP لبلد من ملفات geo';

  @override
  String get ruleIp => 'عنوان IP أو نطاق شبكة';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'البروكسي فقط';

  @override
  String get noNetwork =>
      'لا يوجد اتصال بالإنترنت. شغّل Wi-Fi أو بيانات الجوال.';

  @override
  String get blockAds => 'حظر الإعلانات';

  @override
  String systemProxyTakenBy(String address) {
    return 'غيّر برنامج آخر بروكسي النظام إلى $address، لذا لا تمر حركة المرور عبر VPN.';
  }

  @override
  String get systemProxyTakenOff =>
      'أوقف برنامج آخر بروكسي النظام، لذا لا تمر حركة المرور عبر VPN.';

  @override
  String get setSystemProxyAgain => 'اضبطه مرة أخرى';
}
