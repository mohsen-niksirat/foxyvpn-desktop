// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'Genel bakış';

  @override
  String get navAccounts => 'Hesaplar';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get stateConnected => 'Bağlı';

  @override
  String get stateConnecting => 'Bağlanıyor…';

  @override
  String get stateWaiting => 'Beklemede';

  @override
  String get waitingForAccount =>
      'Bağlanmak için Hesaplar sayfasından bir Firefox Account ekleyin.';

  @override
  String get waitingForEnabledAccount =>
      'Tüm hesaplar kapalı. Hesaplar sayfasından birini açın.';

  @override
  String get stateError => 'Hata';

  @override
  String get stateUnknown => 'Bilinmiyor';

  @override
  String get restartProxy => 'Proxy\'yi yeniden başlat';

  @override
  String copied(String value) {
    return '$value kopyalandı';
  }

  @override
  String get activeAccount => 'Etkin hesap';

  @override
  String get noActiveAccount => 'Etkin hesap yok';

  @override
  String get quotaNotRead => 'Kota bilgisi henüz alınmadı';

  @override
  String get unlimited => 'Sınırsız';

  @override
  String usedOf(String used, String limit) {
    return '$used / $limit kullanıldı';
  }

  @override
  String resets(String date) {
    return '$date tarihinde sıfırlanır';
  }

  @override
  String switchAt(int percent) {
    return 'Kota %$percent dolunca hesap değişir';
  }

  @override
  String get publicIp => 'Genel IP';

  @override
  String get testConnection => 'Bağlantıyı test et';

  @override
  String get testing => 'Test ediliyor…';

  @override
  String get testFailed => 'Başarısız';

  @override
  String milliseconds(int value) {
    return '$value ms';
  }

  @override
  String get justNow => 'az önce';

  @override
  String minutesAgo(int n) {
    return '$n dk önce';
  }

  @override
  String hoursAgo(int n) {
    return '$n sa önce';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün önce',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return 'saat $time';
  }

  @override
  String durationDays(int d, int h) {
    return '${d}g ${h}sa';
  }

  @override
  String durationHours(int h, int m) {
    return '${h}sa ${m}dk';
  }

  @override
  String durationMinutes(int m, int s) {
    return '${m}dk ${s}sn';
  }

  @override
  String durationSeconds(int s) {
    return '${s}sn';
  }

  @override
  String accountsGuide(String size) {
    return 'Her Firefox Account\'un ayda $size kotası var. Birden fazla hesap ekleyebilirsiniz: biri bitince uygulama kendiliğinden sıradakine geçer.';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'Bu listedeki sırayla: her biri %$percent oranına kadar, sonuncusu verisi bitene kadar.';
  }

  @override
  String get addAccount => 'Hesap ekle';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'Geçerli hesabın kotası bitmek üzere ($left kaldı). Bir hesap daha ekleyerek $size daha kazanın.';
  }

  @override
  String get noAccounts => 'Henüz hesap yok';

  @override
  String get noAccountsHint => 'Bağlanmak için bir Firefox Account ekleyin.';

  @override
  String get createAccountTitle => 'Firefox Account\'unuz yok mu?';

  @override
  String get createAccountHint =>
      'accounts.firefox.com adresinden ücretsiz bir hesap oluşturun, ardından buraya dönüp Hesap ekle\'ye basın.';

  @override
  String get moveUp => 'Yukarı taşı';

  @override
  String get moveDown => 'Aşağı taşı';

  @override
  String get statusActive => 'Kullanımda';

  @override
  String get statusReady => 'Hazır';

  @override
  String get statusNeedsSignIn => 'Oturum açılmalı';

  @override
  String get statusReserved => 'Yedekte';

  @override
  String get statusUnavailable => 'Kullanılamıyor';

  @override
  String statusUnavailableUntil(String date) {
    return '$date tarihine kadar kullanılamaz';
  }

  @override
  String get statusDisabled => 'Devre dışı';

  @override
  String get statusEnabled => 'Etkin';

  @override
  String get useNow => 'Şimdi kullan';

  @override
  String get signInAgain => 'Yeniden oturum aç';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'Bu hesap verisinin %$percent kadarını kullandı; sıradaki hesap devreye girdi.';
  }

  @override
  String get reasonQuotaExhausted =>
      'Bu ayın kotası bitti; aylık sıfırlamadan sonra yeniden kullanılır.';

  @override
  String get reasonSignInRequired =>
      'Bu hesabı kullanmak için yeniden giriş yapın.';

  @override
  String get reasonSignInConfirm =>
      'Mozilla girişin onaylanmasını istiyor: «Yeniden oturum aç» düğmesine basın (yalnızca kod gerekir).';

  @override
  String reasonSignInFailed(String detail) {
    return 'Otomatik giriş başarısız oldu ($detail). Yeniden giriş yapın.';
  }

  @override
  String reasonSignInWait(String time) {
    return 'Son otomatik giriş kısa süre sonra çalışmayı bıraktı; sonraki deneme $time.';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'Otomatik giriş tamamlanamadı ($detail); $time saatinde yeniden denenecek.';
  }

  @override
  String get reasonNotEntitled =>
      'Mozilla bu hesabı reddetti; daha sonra yeniden denenecek.';

  @override
  String get more => 'Daha fazla';

  @override
  String get refreshQuota => 'Kotayı yenile';

  @override
  String get remove => 'Kaldır';

  @override
  String get removeTitle => 'Hesap kaldırılsın mı?';

  @override
  String removeBody(String name) {
    return '$name ve kayıtlı oturumu bu bilgisayardan kaldırılacak. Daha sonra yeniden ekleyebilirsiniz.';
  }

  @override
  String get unlimitedQuota => 'Sınırsız kota';

  @override
  String get signInTitle => 'Oturum aç';

  @override
  String get signInIntro => 'Bir Firefox Account ile oturum açın.';

  @override
  String get email => 'E-posta';

  @override
  String get emailInvalid => 'Hesabın e-posta adresini girin';

  @override
  String get password => 'Parola';

  @override
  String get passwordEmpty => 'Parolayı girin';

  @override
  String get show => 'Göster';

  @override
  String get hide => 'Gizle';

  @override
  String get signIn => 'Oturum aç';

  @override
  String get continueLabel => 'Devam';

  @override
  String get done => 'Tamam';

  @override
  String get close => 'Kapat';

  @override
  String get cancel => 'İptal';

  @override
  String get tryAgain => 'Tekrar dene';

  @override
  String get signingIn => 'Oturum açılıyor…';

  @override
  String get accountReady => 'Hesap hazır';

  @override
  String get accountReadyHint => 'Hesap sırasının sonuna eklendi.';

  @override
  String get captchaLabel => 'Resimdeki karakterler';

  @override
  String get codeLabel => 'Kod';

  @override
  String get captchaBroken => 'CAPTCHA resmi gösterilemedi.';

  @override
  String stepEmailCode(String email) {
    return 'Mozilla, $email adresine bir kod gönderdi. Kodu buraya girin.';
  }

  @override
  String get stepTotp => 'Kimlik doğrulama uygulamanızdaki kodu girin.';

  @override
  String stepUnblockCode(String email) {
    return 'Mozilla bu oturum açma girişimini olağan dışı buldu ve $email adresine bir engel kaldırma kodu gönderdi. Kodu buraya girin.';
  }

  @override
  String get stepCaptcha => 'Resimdeki karakterleri yazın.';

  @override
  String stepEmailLink(String email) {
    return 'Mozilla\'nın $email adresine gönderdiği onay bağlantısını açın. İşlem kendiliğinden devam eder.';
  }

  @override
  String get signInFailed => 'Hesap eklenmedi.';

  @override
  String get signInCancelled => 'Oturum açma iptal edildi.';

  @override
  String get signInNoAccount => 'Bu e-postayla bir Firefox Account yok.';

  @override
  String get signInNoAccountHint =>
      'E-postayı kontrol edin ya da bu e-postayla Mozilla\'nın sitesinde ücretsiz bir Firefox Account oluşturun, gelen kutunuzdan onaylayın ve buraya ekleyin.';

  @override
  String get createAccountButton => 'Firefox Account oluştur';

  @override
  String get signInWrongPassword => 'Parola yanlış.';

  @override
  String get signInNoPassword =>
      'Bu hesabın parolası yok: Google veya Apple ile oturum açılarak oluşturulmuş. Bir parola belirleyin, ardından onunla burada oturum açın.';

  @override
  String get setPasswordButton => 'Parola belirle';

  @override
  String get signInTooManyAttempts =>
      'Çok fazla deneme yapıldı. Biraz bekleyip yeniden deneyin.';

  @override
  String get signInUnblockRejected =>
      'Engel kaldırma kodu kabul edilmedi. Mozilla\'nın son e-postasındaki kodu kullanın.';

  @override
  String get signInWrongCode =>
      'Kod yanlış veya süresi dolmuş. Mozilla\'nın son e-postasındaki kodu kullanın; yeni kod gönderilince eskisi çalışmaz.';

  @override
  String get signInWrongTotp =>
      'Kod yanlış. Kimlik doğrulama uygulamasının şu an gösterdiği kodu girin.';

  @override
  String get signInTooManyCodes =>
      'Çok fazla yanlış kod girildi. Oturum açmaya baştan başlayın.';

  @override
  String get signInTimedOut => 'Oturum açma çok uzun sürdü. Yeniden başlayın.';

  @override
  String get signInNetwork =>
      'Mozilla\'ya ulaşılamadı. İnternetinizi kontrol edip yeniden deneyin.';

  @override
  String get coreConnecting => 'Çekirdeğe bağlanılıyor…';

  @override
  String get coreLost => 'Çekirdekle bağlantı koptu. Yeniden deneniyor…';

  @override
  String get cantReachCore => 'Çekirdeğe ulaşılamıyor';

  @override
  String get startingCore => 'Çekirdek başlatılıyor…';

  @override
  String get retry => 'Yeniden dene';

  @override
  String errNoCore(String path) {
    return 'Çekirdek programı uygulamanın yanında bulunamadı ($path).';
  }

  @override
  String errCoreExited(String detail) {
    return 'Çekirdek durdu: $detail';
  }

  @override
  String get errNotAnswering => 'Çekirdek yanıt vermiyor.';

  @override
  String get errRefused =>
      'Çekirdek uygulamayı reddetti; başka bir kopyaya ait olabilir.';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get sectionGeneral => 'Genel';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Sistem varsayılanı';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get closeBehavior => 'Pencere kapatılırken';

  @override
  String get closeAsk => 'Her seferinde sor';

  @override
  String get closeTray => 'Sistem tepsisine küçült';

  @override
  String get closeQuit => 'Uygulamadan çık';

  @override
  String get sectionConnection => 'Bağlantı';

  @override
  String get localProxy => 'Yerel proxy';

  @override
  String get systemProxy => 'Sistem proxy\'si';

  @override
  String get sectionRouting => 'Yönlendirme';

  @override
  String get routingDirect => 'Yerel siteler için doğrudan bağlantı';

  @override
  String get routingDirectHint =>
      'Seçilen ülkenin siteleri ve IP\'leri VPN kullanmadan açılır: daha hızlı yüklenir ve kotanızı harcamaz.';

  @override
  String get region => 'Ülke';

  @override
  String get regionIr => 'İran';

  @override
  String get regionCn => 'Çin';

  @override
  String get regionRu => 'Rusya';

  @override
  String get regionAf => 'Afganistan';

  @override
  String get regionTr => 'Türkiye';

  @override
  String get regionId => 'Endonezya';

  @override
  String get regionBr => 'Brezilya';

  @override
  String get regionNone => 'Hiçbiri';

  @override
  String get saved => 'Kaydedildi';

  @override
  String get dataFolder => 'Veri klasörü';

  @override
  String get openFolder => 'Klasörü aç';

  @override
  String get unofficialNote =>
      'Resmî olmayan istemci. Mozilla ile bir ilişkisi yoktur.';

  @override
  String get closeTitle => 'Pencere kapatılsın mı?';

  @override
  String get closeBody =>
      'Tepsiye küçültülünce VPN bağlı kalır. Çıkarsanız bağlantı kesilir.';

  @override
  String get rememberChoice => 'Seçimimi hatırla';

  @override
  String get minimizeToTray => 'Tepsiye küçült';

  @override
  String get quit => 'Çık';

  @override
  String get trayOpen => 'Aç';

  @override
  String get trayQuit => 'Çık';

  @override
  String get trayProxyOnly => 'Yalnızca proxy hizmeti';

  @override
  String get traySetSystemProxy => 'Sistem proxy\'sini ayarla';

  @override
  String errPortInUse(String port) {
    return '$port portu başka bir program tarafından kullanılıyor, bu yüzden uygulama çekirdeğine ulaşamıyor.';
  }

  @override
  String proxyPortInUse(String port) {
    return '$port portu başka bir program tarafından kullanılıyor, bu yüzden proxy başlatılamıyor.';
  }

  @override
  String get changePort => 'Portu değiştir';

  @override
  String get portDialogTitle => 'Port seçin';

  @override
  String portDialogBody(String port) {
    return '$port portu kullanımda. Aşağıda boş bir port önerildi; isterseniz başka bir port yazabilirsiniz.';
  }

  @override
  String get portChangeBody =>
      'Uygulamalar bu porta bağlanır. 1024 ile 65535 arasında bir port seçin.';

  @override
  String get portLabel => 'Port';

  @override
  String get portInvalid => '1024 ile 65535 arasında bir port girin';

  @override
  String get portBusy => 'Bu port da kullanımda';

  @override
  String get portInUse => 'Bu portu başka bir program kullanıyor';

  @override
  String get save => 'Kaydet';

  @override
  String get proxyPort => 'Proxy portu';

  @override
  String get appPort => 'Uygulama portu';

  @override
  String get welcomeTitle => 'Hoş geldiniz';

  @override
  String get welcomeBody =>
      'Dilinizi ve ülkenizi seçin. Ülkenizin siteleri VPN olmadan doğrudan açılır; böylece daha hızlı yüklenir ve kotanızı harcamaz.';

  @override
  String get start => 'Başla';

  @override
  String routingSuggestTitle(String country) {
    return '$country siteleri doğrudan açılsın mı?';
  }

  @override
  String routingSuggestBody(String country) {
    return '$country siteleri ve IP\'leri VPN olmadan doğrudan açılır. Bunu Yönlendirme bölümünden değiştirebilirsiniz.';
  }

  @override
  String get yes => 'Evet';

  @override
  String get notNow => 'Şimdi değil';

  @override
  String get navServers => 'Sunucular';

  @override
  String get navLogs => 'Günlükler';

  @override
  String get realDelay => 'Gerçek gecikme';

  @override
  String noticePort(String port) {
    return 'Mozilla\'nın proxy\'si $port portuna bağlanmaz. Yalnızca 80, 443, 8080 ve 8443 portları VPN üzerinden geçer.';
  }

  @override
  String get noticeCommand =>
      'Bir uygulama UDP istedi (oyunlar, sesli ve görüntülü aramalar). Mozilla\'nın proxy\'si yalnızca TCP taşıdığı için bu trafik geçemez.';

  @override
  String noticeTimes(int count, String time) {
    return '$count kez, son: $time';
  }

  @override
  String get dismiss => 'Kapat';

  @override
  String get modeRecommended => 'Önerilen';

  @override
  String get modeFastest => 'En hızlı';

  @override
  String get modeRecommendedHint => 'Konumu Mozilla sizin için seçer.';

  @override
  String get modeFastestHint => 'Her bağlantıda en düşük gecikmeli konum.';

  @override
  String get testDelay => 'Gerçek gecikmeyi test et';

  @override
  String get testingDelay => 'Test ediliyor… bu bir dakika sürebilir';

  @override
  String get search => 'Ara';

  @override
  String get noAnswer => 'Yanıt yok';

  @override
  String testedAgo(String ago) {
    return '$ago test edildi';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$total konumdan $answered tanesi yanıt verdi';
  }

  @override
  String get noServers =>
      'Henüz sunucu yok. Çekirdek Mozilla\'ya ulaşınca burada görünür.';

  @override
  String get levelAll => 'Tümü';

  @override
  String get filter => 'Filtre';

  @override
  String get follow => 'Otomatik kaydır';

  @override
  String get clear => 'Temizle';

  @override
  String get copyAll => 'Kopyala';

  @override
  String get logsCopied => 'Günlükler kopyalandı';

  @override
  String get noLogs => 'Henüz günlük satırı yok.';

  @override
  String get sectionAccounts => 'Otomatik hesap değiştirme';

  @override
  String get switchThreshold => 'Hesap değiştirme eşiği';

  @override
  String get switchThresholdHint =>
      'Kotanın bu kadarı dolunca sıradaki hesaba geçilir.';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'DNS sunucuları';

  @override
  String get dnsSystem => 'Sistem';

  @override
  String get dnsAuto => 'Otomatik (Cloudflare, Google, Quad9)';

  @override
  String get dnsCustom => 'Özel';

  @override
  String get dnsCustomHint =>
      'Her satıra bir tane: https://…/dns-query, tls://… veya bir IP adresi.';

  @override
  String get dnsFallback => 'Gerekirse sistem DNS\'ine geri dön';

  @override
  String get testDns => 'DNS\'i test et';

  @override
  String get transport => 'Protokol';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'Doğrudan';

  @override
  String get directRulesHint =>
      'Bu listedeki siteler ve adresler VPN olmadan, doğrudan kendi internetinizle açılır. Seçilen ülkenin kuralları zaten burada: satır ekleyebilir, değiştirebilir veya silebilirsiniz. Başka bir ülke seçmek bunları o ülkenin kurallarıyla değiştirir.';

  @override
  String get restoreRegionRules => 'Ülke kurallarını geri yükle';

  @override
  String get blockRules => 'Engelle';

  @override
  String get blockRulesHint =>
      'Bu listedeki siteler ve adresler hiç açılmaz; ne doğrudan ne de VPN üzerinden: reklamlar veya asla açılmasını istemediğiniz siteler için.';

  @override
  String get rulesTitle => 'Kurallar';

  @override
  String get ruleSyntaxTitle => 'Kural nasıl yazılır';

  @override
  String get resolveDomains => 'IP kurallarını alan adlarına da uygula';

  @override
  String get routingLists => 'Geo dosyaları';

  @override
  String get listSource => 'Liste kaynağı';

  @override
  String get listSourceCustom => 'Elle ayarlandı';

  @override
  String listsUpdatedAgo(String ago) {
    return 'Güncellendi: $ago';
  }

  @override
  String get updateLists => 'Geo dosyalarını güncelle';

  @override
  String get listsUpdated => 'Geo dosyaları güncellendi.';

  @override
  String get testDestination => 'Bir sitenin rotasını test et';

  @override
  String get destinationHint => 'Alan adı, IP adresi veya URL';

  @override
  String get check => 'Kontrol et';

  @override
  String get routeDirect => 'Doğrudan gider';

  @override
  String get routeProxy => 'VPN üzerinden gider';

  @override
  String get routeBlock => 'Engellendi';

  @override
  String ruleMatched(String rule) {
    return 'Kural: $rule';
  }

  @override
  String get portRefusedNote => 'Mozilla\'nın proxy\'si bu porta bağlanmaz.';

  @override
  String get sectionAdvanced => 'Gelişmiş';

  @override
  String get listenAddress => 'Proxy erişimi';

  @override
  String get listenLocal => '127.0.0.1 · yalnızca bu cihaz';

  @override
  String get listenAll => '0.0.0.0 · tüm ağlar (LAN)';

  @override
  String get proxyUsername => 'Proxy kullanıcı adı';

  @override
  String get proxyPassword => 'Proxy parolası';

  @override
  String get proxyLoginHint =>
      'Uygulamalar bu bilgilerle bağlanmalıdır. Parolasız kullanım için ikisini de boş bırakın.';

  @override
  String get loginBothOrNone =>
      'İkisini de doldurun ya da ikisini de boş bırakın.';

  @override
  String get proxyLogin => 'Proxy kullanıcı adı ve parolası';

  @override
  String get idleSleep => 'Boşta kalınca uykuya geç';

  @override
  String get sleepNever => 'Asla';

  @override
  String sleepMinutes(int count) {
    return '$count dakika';
  }

  @override
  String get sleepHour => '1 saat';

  @override
  String get showPublicIp => 'Genel IP\'yi göster';

  @override
  String get speedInNotification => 'Bildirimde hızı göster';

  @override
  String get liveTraffic => 'Anlık trafik';

  @override
  String get totalTraffic => 'Toplam trafik';

  @override
  String get verboseLogs => 'Ayrıntılı günlükler';

  @override
  String get webDashboard => 'Web paneli';

  @override
  String get webDashboardOpen => 'Aç';

  @override
  String get webDashboardHint => 'Gelişmiş ayarlar ve daha fazla araç';

  @override
  String numberInvalid(int min, int max) {
    return '$min ile $max arasında bir sayı girin';
  }

  @override
  String get notifySwitchedTitle => 'Hesap değiştirildi';

  @override
  String notifySwitchedBody(String name) {
    return 'Şu an $name kullanılıyor.';
  }

  @override
  String get notifySignInTitle => 'Oturum açmanız gerekiyor';

  @override
  String get notifySignInBody =>
      'Hesaplar sayfasından bir hesapta yeniden oturum açın.';

  @override
  String get navAbout => 'Hakkında';

  @override
  String get appVersionLabel => 'Uygulama sürümü';

  @override
  String get coreVersionLabel => 'Çekirdek sürümü';

  @override
  String get checkUpdates => 'Güncellemeleri kontrol et';

  @override
  String get checkingUpdates => 'Kontrol ediliyor…';

  @override
  String get upToDate => 'En son sürümü kullanıyorsunuz.';

  @override
  String updateAvailable(String version) {
    return '$version sürümü mevcut.';
  }

  @override
  String get download => 'İndir';

  @override
  String updateCheckFailed(String error) {
    return 'Güncellemeler kontrol edilemedi: $error';
  }

  @override
  String get repoNotSet => 'GitHub deposu henüz ayarlanmadı.';

  @override
  String get sourceCode => 'Kaynak kodu';

  @override
  String get tapToConnect => 'Bağlanmak için tıklayın';

  @override
  String get tapToDisconnect => 'Bağlantıyı kesmek için tıklayın';

  @override
  String get startOnBoot => 'Açılışta başlat';

  @override
  String get connectOnStartup => 'Açılışta bağlan';

  @override
  String get proxyServiceActive => 'Proxy hizmeti etkin';

  @override
  String get navHome => 'Ana sayfa';

  @override
  String get groupApp => 'Uygulama';

  @override
  String get stateOff => 'Bağlı değil';

  @override
  String get tapToConnectPhone => 'Bağlanmak için dokunun';

  @override
  String get tapToDisconnectPhone => 'Bağlantıyı kesmek için dokunun';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'Önerilen konum';

  @override
  String dataLeftOf(String limit) {
    return '/ $limit';
  }

  @override
  String get homeLocation => 'Konum';

  @override
  String get connectedTo => 'Bağlı konum';

  @override
  String get vpnNotAllowed =>
      'VPN için izniniz gerekiyor. Düğmeye tekrar dokunun ve izin verin.';

  @override
  String get dataUsedTitle => 'Kullanılan veri';

  @override
  String get bypassApps => 'Uygulama bazlı proxy';

  @override
  String get connectRetrying => 'Bağlanılamadı. İnternetinizi kontrol edin.';

  @override
  String get failUnreachable =>
      'Mozilla sunucuları bu internette engelli. Başka bir internet bağlantısı deneyin.';

  @override
  String get failRefused =>
      'Mozilla sunucusu bağlantıyı reddetti. Birkaç dakika sonra tekrar deneyin.';

  @override
  String get failLocationRefused =>
      'Bu ülke hesabınıza açık değil. Başka bir ülke seçin.';

  @override
  String get useRecommendedLocation => 'Önerilen konumu kullan';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'Seçtiğiniz ülke: $chosen; IP adresinizin ülkesi: $exit.';
  }

  @override
  String get failSignIn =>
      'Bu hesabın oturumu sona erdi. Hesaplar sayfasından yeniden giriş yapın.';

  @override
  String get failQuota => 'Bu ayın verisi bitti. Başka bir hesap ekleyin.';

  @override
  String get failNotEntitled =>
      'Mozilla bu hesabın VPN kullanmasına izin vermiyor. Başka bir hesap ekleyin.';

  @override
  String get failRegion => 'Mozilla ülkenizde hizmet vermiyor.';

  @override
  String get failServer =>
      'Mozilla hizmetinde geçici bir sorun var. Uygulama kendisi tekrar deneyecek.';

  @override
  String get failNoAccount => 'Hazır hesap yok. Hesaplar sayfasını açın.';

  @override
  String get failTestSite =>
      'Sunucuya bağlandı ama siteler açılmıyor. Başka bir ülke deneyin.';

  @override
  String get failOther => 'Bağlanılamadı. Tekrar deneyin.';

  @override
  String get failNoInternet =>
      'İnternet yok. Wi-Fi\'yi veya mobil veriyi kontrol edin.';

  @override
  String get waitingForNetwork => 'İnternet bağlantısı bekleniyor…';

  @override
  String proxyStartFailed(String port) {
    return 'Proxy $port portunda başlatılamadı. Başka bir port seçin.';
  }

  @override
  String get connectionSettings => 'Bağlantı ayarları';

  @override
  String get appModeExclude => 'Seçili uygulamaları hariç tut';

  @override
  String get appModeInclude => 'Yalnızca seçili uygulamalar';

  @override
  String get appModeExcludeHint =>
      'Seçili uygulamalar VPN yerine doğrudan bağlanır: örneğin yabancı adresleri reddeden bankacılık uygulamaları.';

  @override
  String get appModeIncludeHint =>
      'Yalnızca seçili uygulamalar VPN üzerinden gider; diğerleri doğrudan bağlanır.';

  @override
  String fromRegionList(String region) {
    return 'Önerilen: $region listesinde';
  }

  @override
  String get modeProxy => 'Proxy';

  @override
  String get connectionMode => 'Bağlantı modu';

  @override
  String get modeProxyHint =>
      'Yalnızca proxy ayarı yapılmış uygulamalar proxy\'den geçer; Windows ayarlarına dokunulmaz.';

  @override
  String get modeSystemProxyHint =>
      'Windows ve çoğu uygulama proxy üzerinden geçer.';

  @override
  String get modeProxyHintOther =>
      'Yalnızca proxy ayarı yapılmış uygulamalar proxy\'den geçer; sistem ayarlarına dokunulmaz.';

  @override
  String get modeSystemProxyHintOther =>
      'Tarayıcılar ve çoğu uygulama proxy üzerinden geçer.';

  @override
  String get suggestedApps => 'Önerilen uygulamalar';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count önerilen uygulama seçildi',
      one: '1 önerilen uygulama seçildi',
      zero: 'Önerilen uygulamalar zaten seçili',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'Otomatik';

  @override
  String get locationsSection => 'Konumlar';

  @override
  String get dnsSummaryOk => 'Şifreli DNS çalışıyor';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alan adı çözümlenemedi',
      one: '1 alan adı çözümlenemedi',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return '$server üzerinden';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ağınızın DNS\'i $count alan adı için filtreleme adresi döndürdü. Bu uygulama bu yanıtları kullanmaz.',
      one: 'Ağınızın DNS\'i 1 alan adı için filtreleme adresi döndürdü. Bu uygulama o yanıtı kullanmaz.',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'Yanıt:';

  @override
  String get dnsNetworkAnswer => 'Ağ DNS\'i:';

  @override
  String get dnsFiltered => 'filtrelendi';

  @override
  String get rulesSyntaxTitle => 'Her satıra bir kural';

  @override
  String get ruleDomain => 'Site ve alt alan adları';

  @override
  String get ruleFull => 'Yalnızca bu alan adı';

  @override
  String get ruleKeyword => 'Bu kelimeyi içeren alan adları';

  @override
  String get ruleGeosite => 'Geo dosyalarında bir etiketteki siteler';

  @override
  String get ruleGeoip => 'Geo dosyalarında bir ülkenin IP adresleri';

  @override
  String get ruleIp => 'Bir IP adresi veya ağ';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'Yalnızca proxy';

  @override
  String get noNetwork =>
      'İnternet bağlantısı yok. Wi-Fi\'yi veya mobil veriyi açın.';

  @override
  String get blockAds => 'Reklamları engelle';

  @override
  String systemProxyTakenBy(String address) {
    return 'Başka bir program sistem proxy\'sini $address olarak değiştirdi, bu yüzden trafik VPN\'den geçmiyor.';
  }

  @override
  String get systemProxyTakenOff =>
      'Başka bir program sistem proxy\'sini kapattı, bu yüzden trafik VPN\'den geçmiyor.';

  @override
  String get setSystemProxyAgain => 'Yeniden ayarla';
}
