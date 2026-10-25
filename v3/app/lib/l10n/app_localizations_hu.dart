// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'Áttekintés';

  @override
  String get navAccounts => 'Fiókok';

  @override
  String get navSettings => 'Beállítások';

  @override
  String get stateConnected => 'Csatlakozva';

  @override
  String get stateConnecting => 'Csatlakozás…';

  @override
  String get stateWaiting => 'Várakozás';

  @override
  String get waitingForAccount =>
      'A csatlakozáshoz adjon hozzá egy Firefox Accountot a Fiókok oldalon.';

  @override
  String get waitingForEnabledAccount =>
      'Minden fiók ki van kapcsolva. Kapcsoljon be egyet a Fiókok oldalon.';

  @override
  String get stateError => 'Hiba';

  @override
  String get stateUnknown => 'Ismeretlen';

  @override
  String get restartProxy => 'Proxy újraindítása';

  @override
  String copied(String value) {
    return 'Másolva: $value';
  }

  @override
  String get activeAccount => 'Aktív fiók';

  @override
  String get noActiveAccount => 'Nincs aktív fiók';

  @override
  String get quotaNotRead => 'Az adatkeret még nincs lekérdezve';

  @override
  String get unlimited => 'Korlátlan';

  @override
  String usedOf(String used, String limit) {
    return '$used / $limit felhasználva';
  }

  @override
  String resets(String date) {
    return 'nullázódik: $date';
  }

  @override
  String switchAt(int percent) {
    return 'Fiókváltás $percent%-nál';
  }

  @override
  String get publicIp => 'Nyilvános IP';

  @override
  String get testConnection => 'Kapcsolat tesztelése';

  @override
  String get testing => 'Tesztelés…';

  @override
  String get testFailed => 'Sikertelen';

  @override
  String milliseconds(int value) {
    return '$value ms';
  }

  @override
  String get justNow => 'épp most';

  @override
  String minutesAgo(int n) {
    return '$n perce';
  }

  @override
  String hoursAgo(int n) {
    return '$n órája';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count napja',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return '$time-kor';
  }

  @override
  String durationDays(int d, int h) {
    return '$d nap $h ó';
  }

  @override
  String durationHours(int h, int m) {
    return '$h ó $m p';
  }

  @override
  String durationMinutes(int m, int s) {
    return '$m p $s mp';
  }

  @override
  String durationSeconds(int s) {
    return '$s mp';
  }

  @override
  String accountsGuide(String size) {
    return 'Minden Firefox Account havi $size adatkerettel rendelkezik. Több fiókot is hozzáadhat: ha az egyik elfogy, az alkalmazás magától a következőre vált.';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'A lista sorrendjében: mindegyik $percent%-ig, az utolsó az adatkerete elfogyásáig.';
  }

  @override
  String get addAccount => 'Fiók hozzáadása';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'Az aktuális fiók adatkerete hamarosan elfogy (maradt $left). Adjon hozzá egy másik fiókot, és $size adatkerettel több lesz.';
  }

  @override
  String get noAccounts => 'Még nincs fiók';

  @override
  String get noAccountsHint =>
      'A csatlakozáshoz adjon hozzá egy Firefox Accountot.';

  @override
  String get createAccountTitle => 'Nincs Firefox Accountja?';

  @override
  String get createAccountHint =>
      'Hozzon létre egyet ingyen az accounts.firefox.com oldalon, majd térjen vissza, és nyomja meg a Fiók hozzáadása gombot.';

  @override
  String get moveUp => 'Feljebb';

  @override
  String get moveDown => 'Lejjebb';

  @override
  String get statusActive => 'Aktív';

  @override
  String get statusReady => 'Használható';

  @override
  String get statusNeedsSignIn => 'Bejelentkezés szükséges';

  @override
  String get statusReserved => 'Tartalék';

  @override
  String get statusUnavailable => 'Nem elérhető';

  @override
  String statusUnavailableUntil(String date) {
    return 'Nem elérhető eddig: $date';
  }

  @override
  String get statusDisabled => 'Letiltva';

  @override
  String get statusEnabled => 'Engedélyezve';

  @override
  String get useNow => 'Váltás erre';

  @override
  String get signInAgain => 'Újbóli bejelentkezés';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'Ez a fiók elérte adatkerete $percent%-át, ezért a következő fiók vette át.';
  }

  @override
  String get reasonQuotaExhausted =>
      'Elfogyott a havi adatkeret; a havi nullázás után újra használatba kerül.';

  @override
  String get reasonSignInRequired =>
      'Jelentkezzen be újra a fiók használatához.';

  @override
  String get reasonSignInConfirm =>
      'A Mozilla a bejelentkezés megerősítését kéri: nyomja meg az „Újbóli bejelentkezés” gombot (csak a kód kell).';

  @override
  String reasonSignInFailed(String detail) {
    return 'Az automatikus bejelentkezés nem sikerült ($detail). Jelentkezzen be újra.';
  }

  @override
  String reasonSignInWait(String time) {
    return 'A legutóbbi automatikus bejelentkezés hamar leállt; a következő próbálkozás $time-kor.';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'Az automatikus bejelentkezés nem fejeződött be ($detail); újrapróbálkozás $time-kor.';
  }

  @override
  String get reasonNotEntitled =>
      'A Mozilla elutasította ezt a fiókot; később újrapróbálkozunk.';

  @override
  String get more => 'Továbbiak';

  @override
  String get refreshQuota => 'Adatkeret frissítése';

  @override
  String get remove => 'Eltávolítás';

  @override
  String get removeTitle => 'Eltávolítja a fiókot?';

  @override
  String removeBody(String name) {
    return '$name és a mentett bejelentkezési adatai törlődnek erről a számítógépről. Később újra hozzáadhatja.';
  }

  @override
  String get unlimitedQuota => 'Korlátlan adatkeret';

  @override
  String get signInTitle => 'Bejelentkezés';

  @override
  String get signInIntro => 'Jelentkezzen be egy Firefox Accounttal.';

  @override
  String get email => 'E-mail';

  @override
  String get emailInvalid => 'Adja meg a fiók e-mail-címét';

  @override
  String get password => 'Jelszó';

  @override
  String get passwordEmpty => 'Adja meg a jelszót';

  @override
  String get show => 'Megjelenítés';

  @override
  String get hide => 'Elrejtés';

  @override
  String get signIn => 'Bejelentkezés';

  @override
  String get continueLabel => 'Tovább';

  @override
  String get done => 'Kész';

  @override
  String get close => 'Bezárás';

  @override
  String get cancel => 'Mégse';

  @override
  String get tryAgain => 'Újra';

  @override
  String get signingIn => 'Bejelentkezés…';

  @override
  String get accountReady => 'A fiók használatra kész';

  @override
  String get accountReadyHint => 'A fióklista végére került.';

  @override
  String get captchaLabel => 'A képen látható karakterek';

  @override
  String get codeLabel => 'Kód';

  @override
  String get captchaBroken => 'A CAPTCHA-kép nem jeleníthető meg.';

  @override
  String stepEmailCode(String email) {
    return 'A Mozilla kódot küldött a(z) $email címre. Írja be ide.';
  }

  @override
  String get stepTotp => 'Írja be a hitelesítő alkalmazásban látható kódot.';

  @override
  String stepUnblockCode(String email) {
    return 'A Mozilla szokatlannak találta ezt a bejelentkezést, és feloldókódot küldött a(z) $email címre. Írja be ide.';
  }

  @override
  String get stepCaptcha => 'Írja be a képen látható karaktereket.';

  @override
  String stepEmailLink(String email) {
    return 'Nyissa meg a megerősítő linket, amelyet a Mozilla a(z) $email címre küldött. Utána minden magától folytatódik.';
  }

  @override
  String get signInFailed => 'A fiók nem lett hozzáadva.';

  @override
  String get signInCancelled => 'A bejelentkezés megszakítva.';

  @override
  String get signInNoAccount =>
      'Ehhez az e-mail-címhez nem tartozik Firefox Account.';

  @override
  String get signInNoAccountHint =>
      'Ellenőrizze a címet, vagy hozzon létre vele ingyenes Firefox Accountot a Mozilla oldalán, erősítse meg a postafiókjából, majd adja hozzá itt.';

  @override
  String get createAccountButton => 'Firefox Account létrehozása';

  @override
  String get signInWrongPassword => 'Hibás jelszó.';

  @override
  String get signInNoPassword =>
      'Ennek a fióknak nincs jelszava: Google- vagy Apple-bejelentkezéssel jött létre. Állítson be jelszót, majd jelentkezzen be vele itt.';

  @override
  String get setPasswordButton => 'Jelszó beállítása';

  @override
  String get signInTooManyAttempts =>
      'Túl sok próbálkozás. Várjon egy kicsit, majd próbálja újra.';

  @override
  String get signInUnblockRejected =>
      'A feloldókódot nem fogadta el. Használja a Mozilla legutóbbi e-mailjében lévő kódot.';

  @override
  String get signInWrongCode =>
      'Hibás vagy lejárt kód. Használja a Mozilla legutóbbi e-mailjében lévő kódot; egy új kód küldésekor a régi már nem működik.';

  @override
  String get signInWrongTotp =>
      'Hibás kód. Írja be a hitelesítő alkalmazásban most látható kódot.';

  @override
  String get signInTooManyCodes =>
      'Túl sok hibás kód. Kezdje elölről a bejelentkezést.';

  @override
  String get signInTimedOut =>
      'A bejelentkezés túl sokáig tartott. Kezdje újra.';

  @override
  String get signInNetwork =>
      'A Mozilla nem érhető el. Ellenőrizze az internetet, és próbálja újra.';

  @override
  String get coreConnecting => 'Csatlakozás a magprogramhoz…';

  @override
  String get coreLost =>
      'Megszakadt a kapcsolat a magprogrammal. Újrapróbálás…';

  @override
  String get cantReachCore => 'A magprogram nem érhető el';

  @override
  String get startingCore => 'A magprogram indítása…';

  @override
  String get retry => 'Újra';

  @override
  String errNoCore(String path) {
    return 'A magprogram nem található az alkalmazás mellett ($path).';
  }

  @override
  String errCoreExited(String detail) {
    return 'A magprogram leállt: $detail';
  }

  @override
  String get errNotAnswering => 'A magprogram nem válaszol.';

  @override
  String get errRefused =>
      'A magprogram elutasította az alkalmazást; lehet, hogy egy másik példányhoz tartozik.';

  @override
  String get settingsTitle => 'Beállítások';

  @override
  String get sectionGeneral => 'Általános';

  @override
  String get language => 'Nyelv';

  @override
  String get languageSystem => 'Rendszer nyelve';

  @override
  String get theme => 'Téma';

  @override
  String get themeSystem => 'Rendszer';

  @override
  String get themeLight => 'Világos';

  @override
  String get themeDark => 'Sötét';

  @override
  String get closeBehavior => 'Az ablak bezárásakor';

  @override
  String get closeAsk => 'Mindig kérdezzen rá';

  @override
  String get closeTray => 'Elrejtés a rendszertálcára';

  @override
  String get closeQuit => 'Kilépés az alkalmazásból';

  @override
  String get sectionConnection => 'Kapcsolat';

  @override
  String get localProxy => 'Helyi proxy';

  @override
  String get systemProxy => 'Rendszerproxy';

  @override
  String get sectionRouting => 'Útválasztás';

  @override
  String get routingDirect => 'Közvetlen kapcsolat a helyi oldalakhoz';

  @override
  String get routingDirectHint =>
      'A kiválasztott ország oldalai és IP-címei a VPN-t megkerülve, közvetlenül nyílnak meg: így gyorsabbak, és nem fogyasztják az adatkeretet.';

  @override
  String get region => 'Ország';

  @override
  String get regionIr => 'Irán';

  @override
  String get regionCn => 'Kína';

  @override
  String get regionRu => 'Oroszország';

  @override
  String get regionAf => 'Afganisztán';

  @override
  String get regionTr => 'Törökország';

  @override
  String get regionId => 'Indonézia';

  @override
  String get regionBr => 'Brazília';

  @override
  String get regionNone => 'Nincs';

  @override
  String get saved => 'Mentve';

  @override
  String get dataFolder => 'Adatmappa';

  @override
  String get openFolder => 'Mappa megnyitása';

  @override
  String get unofficialNote =>
      'Nem hivatalos kliens. Nem áll kapcsolatban a Mozillával.';

  @override
  String get closeTitle => 'Bezárja az ablakot?';

  @override
  String get closeBody =>
      'A rendszertálcára rejtve a VPN csatlakozva marad. Kilépéskor a kapcsolat megszakad.';

  @override
  String get rememberChoice => 'Választás megjegyzése';

  @override
  String get minimizeToTray => 'Rendszertálcára';

  @override
  String get quit => 'Kilépés';

  @override
  String get trayOpen => 'Megnyitás';

  @override
  String get trayQuit => 'Kilépés';

  @override
  String get trayProxyOnly => 'Csak proxyszolgáltatás';

  @override
  String get traySetSystemProxy => 'Rendszerproxy beállítása';

  @override
  String errPortInUse(String port) {
    return 'A(z) $port portot egy másik program használja, ezért az alkalmazás nem éri el a magprogramot.';
  }

  @override
  String proxyPortInUse(String port) {
    return 'A(z) $port portot egy másik program használja, ezért a proxy nem tud elindulni.';
  }

  @override
  String get changePort => 'Port módosítása';

  @override
  String get portDialogTitle => 'Port kiválasztása';

  @override
  String portDialogBody(String port) {
    return 'A(z) $port port foglalt. Alább egy szabad portot javaslunk; megadhat másikat is.';
  }

  @override
  String get portChangeBody =>
      'Az alkalmazások ehhez a porthoz csatlakoznak. Válasszon egyet 1024 és 65535 között.';

  @override
  String get portLabel => 'Port';

  @override
  String get portInvalid => 'Adjon meg egy portot 1024 és 65535 között';

  @override
  String get portBusy => 'Ez a port is foglalt';

  @override
  String get portInUse => 'Ezt a portot egy másik program használja';

  @override
  String get save => 'Mentés';

  @override
  String get proxyPort => 'Proxyport';

  @override
  String get appPort => 'Alkalmazásport';

  @override
  String get welcomeTitle => 'Üdvözöljük';

  @override
  String get welcomeBody =>
      'Válassza ki a nyelvet és az országát. Az országa oldalai közvetlenül, VPN nélkül nyílnak meg: így gyorsabbak, és nem fogyasztják az adatkeretet.';

  @override
  String get start => 'Kezdés';

  @override
  String routingSuggestTitle(String country) {
    return 'Közvetlen kapcsolat: $country?';
  }

  @override
  String routingSuggestBody(String country) {
    return '$country oldalai és IP-címei közvetlenül, VPN nélkül nyílnának meg. Ezt az Útválasztás részben módosíthatja.';
  }

  @override
  String get yes => 'Igen';

  @override
  String get notNow => 'Most nem';

  @override
  String get navServers => 'Szerverek';

  @override
  String get navLogs => 'Naplók';

  @override
  String get realDelay => 'Valós késleltetés';

  @override
  String noticePort(String port) {
    return 'A Mozilla proxyja nem csatlakozik a(z) $port porthoz. Csak a 80-as, 443-as, 8080-as és 8443-as port megy át a VPN-en.';
  }

  @override
  String get noticeCommand =>
      'Egy alkalmazás UDP-t kért (játékok, hang- és videohívások). A Mozilla proxyja csak TCP-forgalmat továbbít, így ez nem jut át.';

  @override
  String noticeTimes(int count, String time) {
    return '$count alkalommal, utoljára $time';
  }

  @override
  String get dismiss => 'Elvetés';

  @override
  String get modeRecommended => 'Ajánlott';

  @override
  String get modeFastest => 'Leggyorsabb';

  @override
  String get modeRecommendedHint => 'A Mozilla választja ki a helyszínt.';

  @override
  String get modeFastestHint =>
      'A legkisebb késleltetésű helyszín minden csatlakozáskor.';

  @override
  String get testDelay => 'Valós késleltetés mérése';

  @override
  String get testingDelay => 'Tesztelés… ez egy percig is eltarthat';

  @override
  String get search => 'Keresés';

  @override
  String get noAnswer => 'Nincs válasz';

  @override
  String testedAgo(String ago) {
    return 'Tesztelve: $ago';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$answered / $total válaszolt';
  }

  @override
  String get noServers =>
      'Még nincsenek szerverek. Akkor jelennek meg, amikor a magprogram eléri a Mozillát.';

  @override
  String get levelAll => 'Összes';

  @override
  String get filter => 'Szűrő';

  @override
  String get follow => 'Automatikus görgetés';

  @override
  String get clear => 'Törlés';

  @override
  String get copyAll => 'Másolás';

  @override
  String get logsCopied => 'Naplók másolva';

  @override
  String get noLogs => 'Még nincsenek naplósorok.';

  @override
  String get sectionAccounts => 'Automatikus fiókváltás';

  @override
  String get switchThreshold => 'Váltási küszöb';

  @override
  String get switchThresholdHint =>
      'A következő fiók akkor veszi át, amikor az adatkeret ekkora része elfogyott.';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'DNS-szerverek';

  @override
  String get dnsSystem => 'Rendszer';

  @override
  String get dnsAuto => 'Automatikus (Cloudflare, Google, Quad9)';

  @override
  String get dnsCustom => 'Egyéni';

  @override
  String get dnsCustomHint =>
      'Soronként egy: https://…/dns-query, tls://… vagy egy IP-cím.';

  @override
  String get dnsFallback => 'Rendszer-DNS használata tartalékként';

  @override
  String get testDns => 'DNS tesztelése';

  @override
  String get transport => 'Protokoll';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'Közvetlen';

  @override
  String get directRulesHint =>
      'A lista webhelyei és címei VPN nélkül, közvetlenül a saját internetkapcsolatán nyílnak meg. A választott ország szabályai már itt vannak: sorokat adhat hozzá, módosíthat vagy törölhet. Másik ország választása lecseréli őket annak szabályaira.';

  @override
  String get restoreRegionRules => 'Az ország szabályainak visszaállítása';

  @override
  String get blockRules => 'Tiltás';

  @override
  String get blockRulesHint =>
      'A lista webhelyei és címei egyáltalán nem nyílnak meg, sem közvetlenül, sem VPN-en keresztül: hirdetésekhez vagy olyan oldalakhoz, amelyeket soha nem akar elérni.';

  @override
  String get rulesTitle => 'Szabályok';

  @override
  String get ruleSyntaxTitle => 'Hogyan írjunk szabályt';

  @override
  String get resolveDomains => 'IP-szabályok alkalmazása domainekre';

  @override
  String get routingLists => 'Geo-fájlok';

  @override
  String get listSource => 'Listák forrása';

  @override
  String get listSourceCustom => 'Kézzel megadva';

  @override
  String listsUpdatedAgo(String ago) {
    return 'Frissítve: $ago';
  }

  @override
  String get updateLists => 'Geo-fájlok frissítése';

  @override
  String get listsUpdated => 'A geo-fájlok frissültek.';

  @override
  String get testDestination => 'Útvonal tesztelése';

  @override
  String get destinationHint => 'Domain, IP-cím vagy URL';

  @override
  String get check => 'Ellenőrzés';

  @override
  String get routeDirect => 'Közvetlenül megy';

  @override
  String get routeProxy => 'A VPN-en át megy';

  @override
  String get routeBlock => 'Tiltva';

  @override
  String ruleMatched(String rule) {
    return 'Szabály: $rule';
  }

  @override
  String get portRefusedNote =>
      'A Mozilla proxyja nem csatlakozik ehhez a porthoz.';

  @override
  String get sectionAdvanced => 'Speciális';

  @override
  String get listenAddress => 'Proxyhozzáférés';

  @override
  String get listenLocal => '127.0.0.1 · csak ez az eszköz';

  @override
  String get listenAll => '0.0.0.0 · minden hálózat (LAN)';

  @override
  String get proxyUsername => 'Proxy-felhasználónév';

  @override
  String get proxyPassword => 'Proxyjelszó';

  @override
  String get proxyLoginHint =>
      'Az alkalmazásoknak ezekkel kell bejelentkezniük. Hagyja mindkettőt üresen, ha nem kell bejelentkezés.';

  @override
  String get loginBothOrNone =>
      'Töltse ki mindkettőt, vagy hagyja üresen mindkettőt.';

  @override
  String get proxyLogin => 'Proxyhitelesítés';

  @override
  String get idleSleep => 'Alvás tétlenség után';

  @override
  String get sleepNever => 'Soha';

  @override
  String sleepMinutes(int count) {
    return '$count perc';
  }

  @override
  String get sleepHour => '1 óra';

  @override
  String get showPublicIp => 'Nyilvános IP megjelenítése';

  @override
  String get speedInNotification => 'Sebesség megjelenítése az értesítésben';

  @override
  String get liveTraffic => 'Élő forgalom';

  @override
  String get totalTraffic => 'Teljes forgalom';

  @override
  String get verboseLogs => 'Részletes naplók';

  @override
  String get webDashboard => 'Webes vezérlőpult';

  @override
  String get webDashboardOpen => 'Megnyitás';

  @override
  String get webDashboardHint => 'Speciális beállítások és további eszközök';

  @override
  String numberInvalid(int min, int max) {
    return 'Adjon meg egy számot $min és $max között';
  }

  @override
  String get notifySwitchedTitle => 'Fiókváltás';

  @override
  String notifySwitchedBody(String name) {
    return 'Aktív fiók: $name.';
  }

  @override
  String get notifySignInTitle => 'Bejelentkezés szükséges';

  @override
  String get notifySignInBody =>
      'Egy fiókba újra be kell jelentkezni a Fiókok oldalon.';

  @override
  String get navAbout => 'Névjegy';

  @override
  String get appVersionLabel => 'Alkalmazás verziója';

  @override
  String get coreVersionLabel => 'Magprogram verziója';

  @override
  String get checkUpdates => 'Frissítések keresése';

  @override
  String get checkingUpdates => 'Keresés…';

  @override
  String get upToDate => 'A legújabb verziót használja.';

  @override
  String updateAvailable(String version) {
    return 'Elérhető a(z) $version verzió.';
  }

  @override
  String get download => 'Letöltés';

  @override
  String updateCheckFailed(String error) {
    return 'Nem sikerült frissítéseket keresni: $error';
  }

  @override
  String get repoNotSet => 'A GitHub-tároló még nincs beállítva.';

  @override
  String get sourceCode => 'Forráskód';

  @override
  String get tapToConnect => 'Kattintson a csatlakozáshoz';

  @override
  String get tapToDisconnect => 'Kattintson a kapcsolat bontásához';

  @override
  String get startOnBoot => 'Indítás rendszerindításkor';

  @override
  String get connectOnStartup => 'Csatlakozás rendszerindításkor';

  @override
  String get proxyServiceActive => 'A proxyszolgáltatás aktív';

  @override
  String get navHome => 'Kezdőlap';

  @override
  String get groupApp => 'Alkalmazás';

  @override
  String get stateOff => 'Nincs csatlakozva';

  @override
  String get tapToConnectPhone => 'Koppintson a csatlakozáshoz';

  @override
  String get tapToDisconnectPhone => 'Koppintson a kapcsolat bontásához';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'Ajánlott helyszín';

  @override
  String dataLeftOf(String limit) {
    return '/ $limit';
  }

  @override
  String get homeLocation => 'Helyszín';

  @override
  String get connectedTo => 'Csatlakozva ide:';

  @override
  String get vpnNotAllowed =>
      'A VPN-hez az Ön engedélye szükséges. Koppintson újra a gombra, és engedélyezze.';

  @override
  String get dataUsedTitle => 'Felhasznált adat';

  @override
  String get bypassApps => 'Alkalmazásonkénti proxy';

  @override
  String get connectRetrying =>
      'Nem sikerült csatlakozni. Ellenőrizze az internetet.';

  @override
  String get failUnreachable =>
      'A Mozilla szerverei blokkolva vannak ezen az interneten. Próbáljon másik internetkapcsolatot.';

  @override
  String get failRefused =>
      'A Mozilla szervere elutasította a kapcsolatot. Próbálja újra néhány perc múlva.';

  @override
  String get failLocationRefused =>
      'Ez az ország nem érhető el a fiókja számára. Válasszon másik országot.';

  @override
  String get useRecommendedLocation => 'Az ajánlott helyszín használata';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'Ezt választotta: $chosen, de az IP-címe ezt mutatja: $exit.';
  }

  @override
  String get failSignIn =>
      'A fiók bejelentkezése lejárt. Jelentkezzen be újra a Fiókok oldalon.';

  @override
  String get failQuota =>
      'Az e havi adatkeret elfogyott. Adjon hozzá egy másik fiókot.';

  @override
  String get failNotEntitled =>
      'A Mozilla nem engedi, hogy ez a fiók használja a VPN-t. Adjon hozzá egy másik fiókot.';

  @override
  String get failRegion =>
      'A Mozilla nem nyújtja szolgáltatását az Ön országában.';

  @override
  String get failServer =>
      'A Mozilla szolgáltatásában átmeneti hiba van. Az alkalmazás magától újrapróbálja.';

  @override
  String get failNoAccount =>
      'Egyik fiók sem áll készen. Nyissa meg a Fiókok oldalt.';

  @override
  String get failTestSite =>
      'Csatlakozott a szerverhez, de az oldalak nem nyílnak meg. Próbáljon másik országot.';

  @override
  String get failOther => 'Nem sikerült csatlakozni. Próbálja újra.';

  @override
  String get failNoInternet =>
      'Nincs internet. Ellenőrizze a Wi-Fit vagy a mobiladatot.';

  @override
  String get waitingForNetwork => 'Várakozás az internetkapcsolatra…';

  @override
  String proxyStartFailed(String port) {
    return 'A proxy nem tudott elindulni a(z) $port porton. Válasszon másik portot.';
  }

  @override
  String get connectionSettings => 'Kapcsolati beállítások';

  @override
  String get appModeExclude => 'Kijelöltek VPN nélkül';

  @override
  String get appModeInclude => 'Csak a kijelöltek VPN-nel';

  @override
  String get appModeExcludeHint =>
      'A kijelölt alkalmazások közvetlenül csatlakoznak, nem a VPN-en át: például a külföldi címeket elutasító banki alkalmazások.';

  @override
  String get appModeIncludeHint =>
      'Csak a kijelölt alkalmazások mennek a VPN-en át; a többiek közvetlenül csatlakoznak.';

  @override
  String fromRegionList(String region) {
    return 'Javasolt: szerepel a(z) $region listán';
  }

  @override
  String get modeProxy => 'Proxy';

  @override
  String get connectionMode => 'Kapcsolati mód';

  @override
  String get modeProxyHint =>
      'Csak a proxy használatára beállított alkalmazások mennek rajta át; a Windows változatlan marad.';

  @override
  String get modeSystemProxyHint =>
      'A Windows és a legtöbb alkalmazás a proxyn át megy.';

  @override
  String get modeProxyHintOther =>
      'Csak a proxy használatára beállított alkalmazások mennek rajta át; a rendszer beállításai nem változnak.';

  @override
  String get modeSystemProxyHintOther =>
      'A böngészők és a legtöbb alkalmazás a proxyn át megy.';

  @override
  String get suggestedApps => 'Javasolt alkalmazások';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count javasolt alkalmazás kijelölve',
      one: '1 javasolt alkalmazás kijelölve',
      zero: 'A javasolt alkalmazások már ki vannak jelölve',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'Automatikus';

  @override
  String get locationsSection => 'Helyszínek';

  @override
  String get dnsSummaryOk => 'A titkosított DNS működik';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nevet nem sikerült feloldani',
      one: '1 nevet nem sikerült feloldani',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return 'ezen át: $server';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A hálózat DNS-e $count névre szűrő címet adott vissza. Ezeknél az alkalmazás nem használja ezt a DNS-t.',
      one: 'A hálózat DNS-e 1 névre szűrő címet adott vissza. Ennél az alkalmazás nem használja ezt a DNS-t.',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'Válasz:';

  @override
  String get dnsNetworkAnswer => 'Hálózati DNS:';

  @override
  String get dnsFiltered => 'szűrt';

  @override
  String get rulesSyntaxTitle => 'Soronként egy szabály';

  @override
  String get ruleDomain => 'Az oldal és aldomainjei';

  @override
  String get ruleFull => 'Pontosan ez a név';

  @override
  String get ruleKeyword => 'A szót tartalmazó nevek';

  @override
  String get ruleGeosite => 'Egy címke oldalai a geo-fájlokban';

  @override
  String get ruleGeoip => 'Egy ország címei a geo-fájlokban';

  @override
  String get ruleIp => 'Egy cím vagy hálózat';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'Csak proxy';

  @override
  String get noNetwork =>
      'Nincs internetkapcsolat. Kapcsolja be a Wi-Fit vagy a mobiladatot.';

  @override
  String get blockAds => 'Hirdetések tiltása';

  @override
  String systemProxyTakenBy(String address) {
    return 'Egy másik program a rendszerproxyt erre állította: $address, így a forgalom nem a VPN-en megy.';
  }

  @override
  String get systemProxyTakenOff =>
      'Egy másik program kikapcsolta a rendszerproxyt, így a forgalom nem a VPN-en megy.';

  @override
  String get setSystemProxyAgain => 'Beállítás újra';
}
