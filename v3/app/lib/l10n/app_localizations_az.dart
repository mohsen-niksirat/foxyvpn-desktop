// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Azerbaijani (`az`).
class AppLocalizationsAz extends AppLocalizations {
  AppLocalizationsAz([String locale = 'az']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'İcmal';

  @override
  String get navAccounts => 'Hesablar';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get stateConnected => 'Qoşulub';

  @override
  String get stateConnecting => 'Qoşulur…';

  @override
  String get stateWaiting => 'Gözləyir';

  @override
  String get waitingForAccount =>
      'Qoşulmaq üçün Hesablar səhifəsində Firefox Account əlavə edin.';

  @override
  String get waitingForEnabledAccount =>
      'Bütün hesablar söndürülüb. Hesablar səhifəsində birini yandırın.';

  @override
  String get stateError => 'Xəta';

  @override
  String get stateUnknown => 'Naməlum';

  @override
  String get restartProxy => 'Proksini yenidən başlat';

  @override
  String copied(String value) {
    return '$value kopyalandı';
  }

  @override
  String get activeAccount => 'Aktiv hesab';

  @override
  String get noActiveAccount => 'Aktiv hesab yoxdur';

  @override
  String get quotaNotRead => 'Trafik hələ yoxlanılmayıb';

  @override
  String get unlimited => 'Limitsiz';

  @override
  String usedOf(String used, String limit) {
    return '$used / $limit istifadə olunub';
  }

  @override
  String resets(String date) {
    return '$date tarixində sıfırlanır';
  }

  @override
  String switchAt(int percent) {
    return '$percent%-də hesab dəyişir';
  }

  @override
  String get publicIp => 'Xarici IP';

  @override
  String get testConnection => 'Bağlantını yoxla';

  @override
  String get testing => 'Yoxlanılır…';

  @override
  String get testFailed => 'Uğursuz';

  @override
  String milliseconds(int value) {
    return '$value ms';
  }

  @override
  String get justNow => 'indicə';

  @override
  String minutesAgo(int n) {
    return '$n dəq əvvəl';
  }

  @override
  String hoursAgo(int n) {
    return '$n saat əvvəl';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün əvvəl',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return 'saat $time';
  }

  @override
  String durationDays(int d, int h) {
    return '${d}g ${h}s';
  }

  @override
  String durationHours(int h, int m) {
    return '${h}s ${m}dəq';
  }

  @override
  String durationMinutes(int m, int s) {
    return '${m}dəq ${s}san';
  }

  @override
  String durationSeconds(int s) {
    return '${s}san';
  }

  @override
  String accountsGuide(String size) {
    return 'Hər Firefox Account-un ayda $size trafiki var. Bir neçə hesab əlavə edə bilərsiniz: biri bitəndə tətbiq özü növbətiyə keçir.';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'Bu siyahının sırası ilə: hər hesab $percent%-dək, sonuncu isə datası bitənədək.';
  }

  @override
  String get addAccount => 'Hesab əlavə et';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'Cari hesabın trafiki bitmək üzrədir ($left qalıb). Daha bir hesab əlavə etsəniz, $size əlavə trafikiniz olacaq.';
  }

  @override
  String get noAccounts => 'Hələ hesab yoxdur';

  @override
  String get noAccountsHint => 'Qoşulmaq üçün Firefox Account əlavə edin.';

  @override
  String get createAccountTitle => 'Firefox Account hesabınız yoxdur?';

  @override
  String get createAccountHint =>
      'accounts.firefox.com saytında pulsuz hesab yaradın, sonra qayıdıb «Hesab əlavə et» düyməsini basın.';

  @override
  String get moveUp => 'Yuxarı';

  @override
  String get moveDown => 'Aşağı';

  @override
  String get statusActive => 'Aktiv';

  @override
  String get statusReady => 'Hazır';

  @override
  String get statusNeedsSignIn => 'Giriş lazımdır';

  @override
  String get statusReserved => 'Ehtiyatda';

  @override
  String get statusUnavailable => 'Əlçatmaz';

  @override
  String statusUnavailableUntil(String date) {
    return '$date tarixinədək əlçatmaz';
  }

  @override
  String get statusDisabled => 'Deaktiv';

  @override
  String get statusEnabled => 'Aktiv';

  @override
  String get useNow => 'İndi istifadə et';

  @override
  String get signInAgain => 'Yenidən daxil ol';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'Bu hesabın həcmi $percent%-ə çatdı və növbəti hesab aktivləşdi.';
  }

  @override
  String get reasonQuotaExhausted =>
      'Bu ayın trafiki bitib; aylıq sıfırlamadan sonra yenidən istifadə olunur.';

  @override
  String get reasonSignInRequired =>
      'Bu hesabdan istifadə etmək üçün yenidən daxil olun.';

  @override
  String get reasonSignInConfirm =>
      'Mozilla girişin təsdiqini istəyir: «Yenidən daxil ol» düyməsini basın (yalnız kod lazımdır).';

  @override
  String reasonSignInFailed(String detail) {
    return 'Avtomatik giriş alınmadı ($detail). Yenidən daxil olun.';
  }

  @override
  String reasonSignInWait(String time) {
    return 'Son avtomatik giriş qısa müddət sonra işləməyi dayandırdı; növbəti cəhd saat $time-dadır.';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'Avtomatik giriş başa çatmadı ($detail); saat $time-da yenidən cəhd ediləcək.';
  }

  @override
  String get reasonNotEntitled =>
      'Mozilla bu hesabı qəbul etmədi; sonra yenidən cəhd ediləcək.';

  @override
  String get more => 'Daha çox';

  @override
  String get refreshQuota => 'Trafiki yenilə';

  @override
  String get remove => 'Sil';

  @override
  String get removeTitle => 'Hesab silinsin?';

  @override
  String removeBody(String name) {
    return '$name və onun saxlanmış giriş məlumatları bu kompüterdən silinəcək. Sonra yenidən əlavə edə bilərsiniz.';
  }

  @override
  String get unlimitedQuota => 'Limitsiz trafik';

  @override
  String get signInTitle => 'Giriş';

  @override
  String get signInIntro => 'Firefox Account ilə daxil olun.';

  @override
  String get email => 'E-poçt';

  @override
  String get emailInvalid => 'Hesabın e-poçt ünvanını daxil edin';

  @override
  String get password => 'Parol';

  @override
  String get passwordEmpty => 'Parolu daxil edin';

  @override
  String get show => 'Göstər';

  @override
  String get hide => 'Gizlət';

  @override
  String get signIn => 'Daxil ol';

  @override
  String get continueLabel => 'Davam et';

  @override
  String get done => 'Hazır';

  @override
  String get close => 'Bağla';

  @override
  String get cancel => 'Ləğv et';

  @override
  String get tryAgain => 'Yenidən cəhd et';

  @override
  String get signingIn => 'Daxil olunur…';

  @override
  String get accountReady => 'Hesab hazırdır';

  @override
  String get accountReadyHint => 'Hesablar siyahısının sonuna əlavə olundu.';

  @override
  String get captchaLabel => 'Şəkildəki simvollar';

  @override
  String get codeLabel => 'Kod';

  @override
  String get captchaBroken => 'CAPTCHA şəkli göstərilə bilmədi.';

  @override
  String stepEmailCode(String email) {
    return 'Mozilla $email ünvanına kod göndərdi. Onu buraya daxil edin.';
  }

  @override
  String get stepTotp => 'Autentifikator tətbiqindəki kodu daxil edin.';

  @override
  String stepUnblockCode(String email) {
    return 'Mozilla bu girişi şübhəli hesab etdi və $email ünvanına blokdan çıxarma kodu göndərdi. Onu buraya daxil edin.';
  }

  @override
  String get stepCaptcha => 'Şəkildəki simvolları yazın.';

  @override
  String stepEmailLink(String email) {
    return 'Mozilla-nın $email ünvanına göndərdiyi təsdiq linkini açın. Sonra hər şey avtomatik davam edəcək.';
  }

  @override
  String get signInFailed => 'Hesab əlavə olunmadı.';

  @override
  String get signInCancelled => 'Giriş ləğv edildi.';

  @override
  String get signInNoAccount => 'Bu e-poçtla Firefox Account yoxdur.';

  @override
  String get signInNoAccountHint =>
      'E-poçtu yoxlayın və ya bu e-poçtla Mozilla saytında pulsuz Firefox Account yaradın, onu poçt qutunuzdan təsdiqləyin, sonra buraya əlavə edin.';

  @override
  String get createAccountButton => 'Firefox Account yarat';

  @override
  String get signInWrongPassword => 'Şifrə səhvdir.';

  @override
  String get signInNoPassword =>
      'Bu hesabın şifrəsi yoxdur: Google və ya Apple ilə giriş vasitəsilə yaradılıb. Şifrə təyin edin, sonra onunla burada daxil olun.';

  @override
  String get setPasswordButton => 'Şifrə təyin et';

  @override
  String get signInTooManyAttempts =>
      'Çox cəhd edildi. Bir az gözləyin və yenidən cəhd edin.';

  @override
  String get signInUnblockRejected =>
      'Blokdan çıxarma kodu qəbul olunmadı. Mozilla-nın son məktubundakı kodu istifadə edin.';

  @override
  String get signInWrongCode =>
      'Kod səhvdir və ya vaxtı keçib. Mozilla-nın son məktubundakı kodu istifadə edin; yeni kod göndəriləndə köhnəsi işləmir.';

  @override
  String get signInWrongTotp =>
      'Kod səhvdir. Autentifikator tətbiqinin indi göstərdiyi kodu daxil edin.';

  @override
  String get signInTooManyCodes =>
      'Çox səhv kod daxil edildi. Girişə yenidən başlayın.';

  @override
  String get signInTimedOut => 'Giriş çox uzun çəkdi. Yenidən başlayın.';

  @override
  String get signInNetwork =>
      'Mozilla-ya qoşulmaq mümkün olmadı. İnterneti yoxlayın və yenidən cəhd edin.';

  @override
  String get coreConnecting => 'Nüvəyə qoşulur…';

  @override
  String get coreLost => 'Nüvə ilə əlaqə kəsildi. Yenidən cəhd edilir…';

  @override
  String get cantReachCore => 'Nüvəyə qoşulmaq mümkün deyil';

  @override
  String get startingCore => 'Nüvə işə salınır…';

  @override
  String get retry => 'Yenidən cəhd et';

  @override
  String errNoCore(String path) {
    return 'Nüvə proqramı tətbiqin yanında tapılmadı ($path).';
  }

  @override
  String errCoreExited(String detail) {
    return 'Nüvə dayandı: $detail';
  }

  @override
  String get errNotAnswering => 'Nüvə cavab vermir.';

  @override
  String get errRefused =>
      'Nüvə tətbiqi qəbul etmədi; ola bilsin ki, o, tətbiqin başqa nüsxəsinə aiddir.';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get sectionGeneral => 'Ümumi';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Sistem dili';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açıq';

  @override
  String get themeDark => 'Tünd';

  @override
  String get closeBehavior => 'Pəncərə bağlananda';

  @override
  String get closeAsk => 'Hər dəfə soruş';

  @override
  String get closeTray => 'Saatın yanında gizlət';

  @override
  String get closeQuit => 'Tətbiqdən çıx';

  @override
  String get sectionConnection => 'Bağlantı';

  @override
  String get localProxy => 'Lokal proksi';

  @override
  String get systemProxy => 'Sistem proksisi';

  @override
  String get sectionRouting => 'Marşrutlaşdırma';

  @override
  String get routingDirect => 'Yerli saytlar üçün birbaşa bağlantı';

  @override
  String get routingDirectHint =>
      'Seçilmiş ölkənin saytları və IP-ləri VPN-dən keçmir: daha sürətli açılır və trafikə qənaət olunur.';

  @override
  String get region => 'Ölkə';

  @override
  String get regionIr => 'İran';

  @override
  String get regionCn => 'Çin';

  @override
  String get regionRu => 'Rusiya';

  @override
  String get regionAf => 'Əfqanıstan';

  @override
  String get regionTr => 'Türkiyə';

  @override
  String get regionId => 'İndoneziya';

  @override
  String get regionBr => 'Braziliya';

  @override
  String get regionNone => 'Heç biri';

  @override
  String get saved => 'Saxlanıldı';

  @override
  String get dataFolder => 'Məlumat qovluğu';

  @override
  String get openFolder => 'Qovluğu aç';

  @override
  String get unofficialNote =>
      'Qeyri-rəsmi tətbiq. Mozilla ilə əlaqəsi yoxdur.';

  @override
  String get closeTitle => 'Pəncərə bağlansın?';

  @override
  String get closeBody =>
      'Saatın yanında gizlədiləndə VPN qoşulu qalır. Tətbiqdən çıxanda isə VPN söndürülür.';

  @override
  String get rememberChoice => 'Seçimimi yadda saxla';

  @override
  String get minimizeToTray => 'Saatın yanında gizlət';

  @override
  String get quit => 'Çıx';

  @override
  String get trayOpen => 'Aç';

  @override
  String get trayQuit => 'Çıx';

  @override
  String get trayProxyOnly => 'Yalnız proksi xidməti';

  @override
  String get traySetSystemProxy => 'Sistem proksisini qur';

  @override
  String errPortInUse(String port) {
    return '$port portu başqa proqram tərəfindən istifadə olunur, buna görə tətbiq nüvəyə qoşula bilmir.';
  }

  @override
  String proxyPortInUse(String port) {
    return '$port portu başqa proqram tərəfindən istifadə olunur, buna görə proksi işə düşə bilmir.';
  }

  @override
  String get changePort => 'Portu dəyiş';

  @override
  String get portDialogTitle => 'Port seçin';

  @override
  String portDialogBody(String port) {
    return '$port portu məşğuldur. Aşağıda boş port təklif olunur; başqasını da yaza bilərsiniz.';
  }

  @override
  String get portChangeBody =>
      'Tətbiqlər bu porta qoşulur. 1024 ilə 65535 arasında bir port seçin.';

  @override
  String get portLabel => 'Port';

  @override
  String get portInvalid => '1024-dən 65535-ə qədər port daxil edin';

  @override
  String get portBusy => 'Bu port da məşğuldur';

  @override
  String get portInUse => 'Bu portdan başqa proqram istifadə edir';

  @override
  String get save => 'Saxla';

  @override
  String get proxyPort => 'Proksi portu';

  @override
  String get appPort => 'Tətbiq portu';

  @override
  String get welcomeTitle => 'Xoş gəlmisiniz';

  @override
  String get welcomeBody =>
      'Dilinizi və ölkənizi seçin. Ölkənizin saytları VPN olmadan birbaşa açılır: bu, daha sürətlidir və trafikə qənaət edir.';

  @override
  String get start => 'Başla';

  @override
  String routingSuggestTitle(String country) {
    return '$country saytları birbaşa açılsın?';
  }

  @override
  String routingSuggestBody(String country) {
    return '$country saytları və IP-ləri VPN olmadan birbaşa açılacaq. Bunu Marşrutlaşdırma bölməsində dəyişə bilərsiniz.';
  }

  @override
  String get yes => 'Bəli';

  @override
  String get notNow => 'İndi yox';

  @override
  String get navServers => 'Serverlər';

  @override
  String get navLogs => 'Loglar';

  @override
  String get realDelay => 'Real gecikmə';

  @override
  String noticePort(String port) {
    return 'Mozilla-nın proksisi $port portuna qoşulmur. Yalnız 80, 443, 8080 və 8443 portları VPN-dən keçir.';
  }

  @override
  String get noticeCommand =>
      'Bir tətbiq UDP istifadə etmək istədi (oyunlar, səsli və görüntülü zənglər). Mozilla-nın proksisi yalnız TCP ötürür, ona görə bu trafik keçə bilmir.';

  @override
  String noticeTimes(int count, String time) {
    return '$count dəfə, sonuncu: $time';
  }

  @override
  String get dismiss => 'Bağla';

  @override
  String get modeRecommended => 'Tövsiyə olunan';

  @override
  String get modeFastest => 'Ən sürətli';

  @override
  String get modeRecommendedHint => 'Məkanı Mozilla sizin üçün seçir.';

  @override
  String get modeFastestHint => 'Hər qoşulanda ən az gecikməli məkan seçilir.';

  @override
  String get testDelay => 'Real gecikməni yoxla';

  @override
  String get testingDelay => 'Yoxlanılır… bu bir dəqiqə çəkə bilər';

  @override
  String get search => 'Axtar';

  @override
  String get noAnswer => 'Cavab yoxdur';

  @override
  String testedAgo(String ago) {
    return 'Yoxlanıb: $ago';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$total serverdən $answered cavab verdi';
  }

  @override
  String get noServers =>
      'Hələ server yoxdur. Nüvə Mozilla-ya qoşulandan sonra görünəcək.';

  @override
  String get levelAll => 'Hamısı';

  @override
  String get filter => 'Filtr';

  @override
  String get follow => 'Avtomatik sürüşdürmə';

  @override
  String get clear => 'Təmizlə';

  @override
  String get copyAll => 'Kopyala';

  @override
  String get logsCopied => 'Loglar kopyalandı';

  @override
  String get noLogs => 'Hələ log yoxdur.';

  @override
  String get sectionAccounts => 'Avtomatik hesab dəyişmə';

  @override
  String get switchThreshold => 'Hesab dəyişmə həddi';

  @override
  String get switchThresholdHint =>
      'Trafikin bu qədəri istifadə olunanda növbəti hesaba keçilir.';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'DNS serverləri';

  @override
  String get dnsSystem => 'Sistem';

  @override
  String get dnsAuto => 'Avtomatik (Cloudflare, Google, Quad9)';

  @override
  String get dnsCustom => 'Fərdi';

  @override
  String get dnsCustomHint =>
      'Hər sətirdə bir: https://…/dns-query, tls://… və ya IP ünvanı.';

  @override
  String get dnsFallback => 'Lazım olsa sistem DNS-inə keç';

  @override
  String get testDns => 'DNS-i yoxla';

  @override
  String get transport => 'Protokol';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'Birbaşa';

  @override
  String get directRulesHint =>
      'Bu siyahıdakı saytlar və ünvanlar VPN olmadan, birbaşa öz internetinizlə açılır. Seçdiyiniz ölkənin qaydaları artıq buradadır: sətir əlavə edə, dəyişə və ya silə bilərsiniz. Başqa ölkə seçmək onları həmin ölkənin qaydaları ilə əvəz edir.';

  @override
  String get restoreRegionRules => 'Ölkə qaydalarını bərpa et';

  @override
  String get blockRules => 'Blokla';

  @override
  String get blockRulesHint =>
      'Bu siyahıdakı saytlar və ünvanlar ümumiyyətlə açılmır — nə birbaşa, nə də VPN ilə: reklamlar və ya heç vaxt açılmasını istəmədiyiniz saytlar üçün.';

  @override
  String get rulesTitle => 'Qaydalar';

  @override
  String get ruleSyntaxTitle => 'Qayda necə yazılır';

  @override
  String get resolveDomains => 'IP qaydalarını domenlərə də tətbiq et';

  @override
  String get routingLists => 'Geo faylları';

  @override
  String get listSource => 'Siyahı mənbəyi';

  @override
  String get listSourceCustom => 'Əl ilə təyin edilib';

  @override
  String listsUpdatedAgo(String ago) {
    return 'Yeniləndi: $ago';
  }

  @override
  String get updateLists => 'Geo fayllarını yenilə';

  @override
  String get listsUpdated => 'Geo faylları yeniləndi.';

  @override
  String get testDestination => 'Marşrutu yoxla';

  @override
  String get destinationHint => 'Sayt adı, IP ünvanı və ya URL';

  @override
  String get check => 'Yoxla';

  @override
  String get routeDirect => 'Birbaşa qoşulur';

  @override
  String get routeProxy => 'VPN-dən keçir';

  @override
  String get routeBlock => 'Bloklanıb';

  @override
  String ruleMatched(String rule) {
    return 'Qayda: $rule';
  }

  @override
  String get portRefusedNote => 'Mozilla-nın proksisi bu porta qoşulmur.';

  @override
  String get sectionAdvanced => 'Əlavə';

  @override
  String get listenAddress => 'Proksiyə kim qoşula bilər';

  @override
  String get listenLocal => '127.0.0.1 · yalnız bu cihaz';

  @override
  String get listenAll => '0.0.0.0 · bütün şəbəkələr (LAN)';

  @override
  String get proxyUsername => 'Proksi istifadəçi adı';

  @override
  String get proxyPassword => 'Proksi parolu';

  @override
  String get proxyLoginHint =>
      'Tətbiqlər proksiyə bu ad və parolla qoşulmalıdır. Parolsuz istifadə üçün hər ikisini boş qoyun.';

  @override
  String get loginBothOrNone =>
      'Hər ikisini doldurun və ya hər ikisini boş qoyun.';

  @override
  String get proxyLogin => 'Proksi adı və parolu';

  @override
  String get idleSleep => 'Trafik olmayanda yuxu rejimi';

  @override
  String get sleepNever => 'Heç vaxt';

  @override
  String sleepMinutes(int count) {
    return '$count dəqiqə';
  }

  @override
  String get sleepHour => '1 saat';

  @override
  String get showPublicIp => 'Xarici IP-ni göstər';

  @override
  String get speedInNotification => 'Bildirişdə sürəti göstər';

  @override
  String get liveTraffic => 'Canlı trafik';

  @override
  String get totalTraffic => 'Ümumi trafik';

  @override
  String get verboseLogs => 'Ətraflı loglar';

  @override
  String get webDashboard => 'Veb panel';

  @override
  String get webDashboardOpen => 'Aç';

  @override
  String get webDashboardHint => 'Qabaqcıl ayarlar və daha çox alət';

  @override
  String numberInvalid(int min, int max) {
    return '$min ilə $max arasında rəqəm daxil edin';
  }

  @override
  String get notifySwitchedTitle => 'Hesab dəyişdi';

  @override
  String notifySwitchedBody(String name) {
    return 'İndi $name istifadə olunur.';
  }

  @override
  String get notifySignInTitle => 'Giriş lazımdır';

  @override
  String get notifySignInBody =>
      'Hesablar səhifəsində bir hesaba yenidən daxil olmaq lazımdır.';

  @override
  String get navAbout => 'Haqqında';

  @override
  String get appVersionLabel => 'Tətbiq versiyası';

  @override
  String get coreVersionLabel => 'Nüvə versiyası';

  @override
  String get checkUpdates => 'Yeniləmələri yoxla';

  @override
  String get checkingUpdates => 'Yoxlanılır…';

  @override
  String get upToDate => 'Ən son versiyadan istifadə edirsiniz.';

  @override
  String updateAvailable(String version) {
    return '$version versiyası mövcuddur.';
  }

  @override
  String get download => 'Yüklə';

  @override
  String updateCheckFailed(String error) {
    return 'Yeniləmələri yoxlamaq mümkün olmadı: $error';
  }

  @override
  String get repoNotSet => 'GitHub repozitoriyası hələ təyin edilməyib.';

  @override
  String get sourceCode => 'Mənbə kodu';

  @override
  String get tapToConnect => 'Qoşulmaq üçün klikləyin';

  @override
  String get tapToDisconnect => 'Bağlantını kəsmək üçün klikləyin';

  @override
  String get startOnBoot => 'Sistem açılanda başlat';

  @override
  String get connectOnStartup => 'Açılışda avtomatik qoşul';

  @override
  String get proxyServiceActive => 'Proksi xidməti aktivdir';

  @override
  String get navHome => 'Ana səhifə';

  @override
  String get groupApp => 'Tətbiq';

  @override
  String get stateOff => 'Qoşulmayıb';

  @override
  String get tapToConnectPhone => 'Qoşulmaq üçün toxunun';

  @override
  String get tapToDisconnectPhone => 'Bağlantını kəsmək üçün toxunun';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'Tövsiyə olunan məkan';

  @override
  String dataLeftOf(String limit) {
    return '/ $limit';
  }

  @override
  String get homeLocation => 'Məkan';

  @override
  String get connectedTo => 'Qoşulub:';

  @override
  String get vpnNotAllowed =>
      'VPN-in işləməsi üçün icazə lazımdır. Düyməyə yenidən toxunun və icazə verin.';

  @override
  String get dataUsedTitle => 'İstifadə olunan trafik';

  @override
  String get bypassApps => 'Tətbiqlər üzrə proksi';

  @override
  String get connectRetrying => 'Qoşulmaq alınmadı. İnterneti yoxlayın.';

  @override
  String get failUnreachable =>
      'Mozilla serverləri bu internetdə bloklanıb. Başqa internet bağlantısını sınayın.';

  @override
  String get failRefused =>
      'Mozilla serveri bağlantını rədd etdi. Bir neçə dəqiqədən sonra yenidən cəhd edin.';

  @override
  String get failLocationRefused =>
      'Bu ölkə hesabınız üçün açıq deyil. Başqa ölkə seçin.';

  @override
  String get useRecommendedLocation => 'Tövsiyə olunan məkandan istifadə et';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'Seçdiyiniz ölkə: $chosen, IP ünvanınızın ölkəsi: $exit.';
  }

  @override
  String get failSignIn =>
      'Bu hesabın girişinin müddəti bitib. Hesablar səhifəsində yenidən daxil olun.';

  @override
  String get failQuota => 'Bu ayın trafiki bitib. Başqa hesab əlavə edin.';

  @override
  String get failNotEntitled =>
      'Mozilla bu hesaba VPN-dən istifadə etməyə icazə vermir. Başqa hesab əlavə edin.';

  @override
  String get failRegion => 'Mozilla ölkənizdə xidmət göstərmir.';

  @override
  String get failServer =>
      'Mozilla xidmətində müvəqqəti problem var. Proqram özü yenidən cəhd edir.';

  @override
  String get failNoAccount => 'Hazır hesab yoxdur. Hesablar səhifəsini açın.';

  @override
  String get failTestSite =>
      'Serverə qoşuldu, amma saytlar açılmır. Başqa ölkəni sınayın.';

  @override
  String get failOther => 'Qoşulmaq alınmadı. Yenidən cəhd edin.';

  @override
  String get failNoInternet =>
      'İnternet yoxdur. Wi-Fi və ya mobil interneti yoxlayın.';

  @override
  String get waitingForNetwork => 'İnternet bağlantısı gözlənilir…';

  @override
  String proxyStartFailed(String port) {
    return 'Proksi $port portunda işə düşmədi. Başqa port seçin.';
  }

  @override
  String get connectionSettings => 'Bağlantı ayarları';

  @override
  String get appModeExclude => 'Seçilmiş tətbiqlər VPN-siz';

  @override
  String get appModeInclude => 'Yalnız seçilmiş tətbiqlər VPN ilə';

  @override
  String get appModeExcludeHint =>
      'Seçilmiş tətbiqlər VPN-siz, birbaşa qoşulur: məsələn, xarici IP-ləri qəbul etməyən bank tətbiqləri.';

  @override
  String get appModeIncludeHint =>
      'Yalnız seçilmiş tətbiqlər VPN-dən keçir; digərləri birbaşa qoşulur.';

  @override
  String fromRegionList(String region) {
    return 'Təklif: $region siyahısından';
  }

  @override
  String get modeProxy => 'Proksi';

  @override
  String get connectionMode => 'Bağlantı rejimi';

  @override
  String get modeProxyHint =>
      'Yalnız proksi ayarlanmış tətbiqlər ondan keçir; Windows ayarları dəyişmir.';

  @override
  String get modeSystemProxyHint =>
      'Windows və əksər tətbiqlər proksidən keçir.';

  @override
  String get modeProxyHintOther =>
      'Yalnız proksi ayarlanmış tətbiqlər ondan keçir; sistem ayarları dəyişmir.';

  @override
  String get modeSystemProxyHintOther =>
      'Brauzerlər və əksər tətbiqlər proksidən keçir.';

  @override
  String get suggestedApps => 'Təklif olunan tətbiqlər';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count təklif olunan tətbiq seçildi',
      one: '1 təklif olunan tətbiq seçildi',
      zero: 'Təklif olunan tətbiqlər artıq seçilib',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'Avtomatik';

  @override
  String get locationsSection => 'Məkanlar';

  @override
  String get dnsSummaryOk => 'Şifrəli DNS işləyir';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count domen üçün cavab alınmadı',
      one: '1 domen üçün cavab alınmadı',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return '$server vasitəsilə';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Şəbəkənizin DNS-i $count domen üçün filtr ünvanı qaytardı. Bu tətbiq həmin domenlər üçün o DNS-dən istifadə etmir.',
      one: 'Şəbəkənizin DNS-i 1 domen üçün filtr ünvanı qaytardı. Bu tətbiq həmin domen üçün o DNS-dən istifadə etmir.',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'Cavab:';

  @override
  String get dnsNetworkAnswer => 'Şəbəkə DNS-i:';

  @override
  String get dnsFiltered => 'filtrlənib';

  @override
  String get rulesSyntaxTitle => 'Hər sətirdə bir qayda';

  @override
  String get ruleDomain => 'Sayt və onun subdomenləri';

  @override
  String get ruleFull => 'Yalnız bu domen';

  @override
  String get ruleKeyword => 'Bu sözü daxil edən domenlər';

  @override
  String get ruleGeosite => 'Geo fayllarında teqə aid saytlar';

  @override
  String get ruleGeoip => 'Geo fayllarında ölkəyə aid IP-lər';

  @override
  String get ruleIp => 'IP ünvanı və ya şəbəkə';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'Yalnız proksi';

  @override
  String get noNetwork =>
      'İnternet bağlantısı yoxdur. Wi-Fi və ya mobil datanı yandırın.';

  @override
  String get blockAds => 'Reklamları blokla';

  @override
  String systemProxyTakenBy(String address) {
    return 'Başqa proqram sistem proksisini $address ünvanına qoydu, ona görə trafik VPN-dən keçmir.';
  }

  @override
  String get systemProxyTakenOff =>
      'Başqa proqram sistem proksisini söndürdü, ona görə trafik VPN-dən keçmir.';

  @override
  String get setSystemProxyAgain => 'Yenidən qur';
}
