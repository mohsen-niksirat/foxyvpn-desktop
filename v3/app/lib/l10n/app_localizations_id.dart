// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'Ringkasan';

  @override
  String get navAccounts => 'Akun';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String get stateConnected => 'Terhubung';

  @override
  String get stateConnecting => 'Menghubungkan…';

  @override
  String get stateWaiting => 'Menunggu';

  @override
  String get waitingForAccount =>
      'Tambahkan Firefox Account di halaman Akun untuk terhubung.';

  @override
  String get waitingForEnabledAccount =>
      'Semua akun dinonaktifkan. Aktifkan salah satu di halaman Akun.';

  @override
  String get stateError => 'Error';

  @override
  String get stateUnknown => 'Tidak diketahui';

  @override
  String get restartProxy => 'Mulai ulang proxy';

  @override
  String copied(String value) {
    return '$value disalin';
  }

  @override
  String get activeAccount => 'Akun aktif';

  @override
  String get noActiveAccount => 'Tidak ada akun aktif';

  @override
  String get quotaNotRead => 'Kuota belum dicek';

  @override
  String get unlimited => 'Tanpa batas';

  @override
  String usedOf(String used, String limit) {
    return '$used dari $limit terpakai';
  }

  @override
  String resets(String date) {
    return 'reset $date';
  }

  @override
  String switchAt(int percent) {
    return 'Ganti akun pada $percent%';
  }

  @override
  String get publicIp => 'IP publik';

  @override
  String get testConnection => 'Uji koneksi';

  @override
  String get testing => 'Menguji…';

  @override
  String get testFailed => 'Gagal';

  @override
  String milliseconds(int value) {
    return '$value ms';
  }

  @override
  String get justNow => 'baru saja';

  @override
  String minutesAgo(int n) {
    return '$n menit lalu';
  }

  @override
  String hoursAgo(int n) {
    return '$n jam lalu';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hari lalu',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return 'pukul $time';
  }

  @override
  String durationDays(int d, int h) {
    return '${d}h ${h}j';
  }

  @override
  String durationHours(int h, int m) {
    return '${h}j ${m}m';
  }

  @override
  String durationMinutes(int m, int s) {
    return '${m}m ${s}d';
  }

  @override
  String durationSeconds(int s) {
    return '${s}d';
  }

  @override
  String accountsGuide(String size) {
    return 'Setiap Firefox Account punya kuota $size per bulan. Anda bisa menambahkan beberapa akun: saat satu habis, aplikasi otomatis pindah ke akun berikutnya.';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'Sesuai urutan daftar ini: masing-masing sampai $percent%, yang terakhir sampai datanya habis.';
  }

  @override
  String get addAccount => 'Tambah akun';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'Kuota akun saat ini hampir habis (sisa $left). Tambahkan akun lain untuk mendapat $size lagi.';
  }

  @override
  String get noAccounts => 'Belum ada akun';

  @override
  String get noAccountsHint => 'Tambahkan Firefox Account untuk terhubung.';

  @override
  String get createAccountTitle => 'Belum punya Firefox Account?';

  @override
  String get createAccountHint =>
      'Buat gratis di accounts.firefox.com, lalu kembali dan tekan Tambah akun.';

  @override
  String get moveUp => 'Naikkan';

  @override
  String get moveDown => 'Turunkan';

  @override
  String get statusActive => 'Aktif';

  @override
  String get statusReady => 'Siap';

  @override
  String get statusNeedsSignIn => 'Perlu masuk';

  @override
  String get statusReserved => 'Cadangan';

  @override
  String get statusUnavailable => 'Tidak tersedia';

  @override
  String statusUnavailableUntil(String date) {
    return 'Tidak tersedia hingga $date';
  }

  @override
  String get statusDisabled => 'Nonaktif';

  @override
  String get statusEnabled => 'Aktif';

  @override
  String get useNow => 'Gunakan sekarang';

  @override
  String get signInAgain => 'Masuk lagi';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'Akun ini telah memakai $percent% datanya, jadi akun berikutnya mengambil alih.';
  }

  @override
  String get reasonQuotaExhausted =>
      'Kuota bulan ini habis; dipakai lagi setelah reset bulanan.';

  @override
  String get reasonSignInRequired => 'Masuk lagi untuk memakai akun ini.';

  @override
  String get reasonSignInConfirm =>
      'Mozilla meminta konfirmasi masuk: tekan Masuk lagi (hanya perlu kode).';

  @override
  String reasonSignInFailed(String detail) {
    return 'Masuk otomatis gagal ($detail). Masuk lagi.';
  }

  @override
  String reasonSignInWait(String time) {
    return 'Masuk otomatis terakhir segera berhenti berfungsi; percobaan berikutnya pukul $time.';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'Masuk otomatis tidak selesai ($detail); dicoba lagi pukul $time.';
  }

  @override
  String get reasonNotEntitled =>
      'Mozilla menolak akun ini; akan dicoba lagi nanti.';

  @override
  String get more => 'Lainnya';

  @override
  String get refreshQuota => 'Perbarui kuota';

  @override
  String get remove => 'Hapus';

  @override
  String get removeTitle => 'Hapus akun?';

  @override
  String removeBody(String name) {
    return '$name dan data login yang tersimpan akan dihapus dari komputer ini. Anda bisa menambahkannya lagi nanti.';
  }

  @override
  String get unlimitedQuota => 'Kuota tanpa batas';

  @override
  String get signInTitle => 'Masuk';

  @override
  String get signInIntro => 'Masuk dengan Firefox Account.';

  @override
  String get email => 'Email';

  @override
  String get emailInvalid => 'Masukkan email akun';

  @override
  String get password => 'Kata sandi';

  @override
  String get passwordEmpty => 'Masukkan kata sandi';

  @override
  String get show => 'Tampilkan';

  @override
  String get hide => 'Sembunyikan';

  @override
  String get signIn => 'Masuk';

  @override
  String get continueLabel => 'Lanjutkan';

  @override
  String get done => 'Selesai';

  @override
  String get close => 'Tutup';

  @override
  String get cancel => 'Batal';

  @override
  String get tryAgain => 'Coba lagi';

  @override
  String get signingIn => 'Sedang masuk…';

  @override
  String get accountReady => 'Akun siap';

  @override
  String get accountReadyHint => 'Akun ditambahkan di urutan terakhir.';

  @override
  String get captchaLabel => 'Teks pada gambar';

  @override
  String get codeLabel => 'Kode';

  @override
  String get captchaBroken => 'Gambar CAPTCHA tidak dapat ditampilkan.';

  @override
  String stepEmailCode(String email) {
    return 'Mozilla mengirim kode ke $email. Masukkan di sini.';
  }

  @override
  String get stepTotp => 'Masukkan kode dari aplikasi autentikator Anda.';

  @override
  String stepUnblockCode(String email) {
    return 'Mozilla menganggap upaya masuk ini tidak biasa dan mengirim kode buka blokir ke $email. Masukkan di sini.';
  }

  @override
  String get stepCaptcha => 'Ketik teks pada gambar.';

  @override
  String stepEmailLink(String email) {
    return 'Buka tautan konfirmasi yang dikirim Mozilla ke $email. Proses akan berlanjut otomatis.';
  }

  @override
  String get signInFailed => 'Akun tidak ditambahkan.';

  @override
  String get signInCancelled => 'Masuk dibatalkan.';

  @override
  String get signInNoAccount => 'Tidak ada Firefox Account dengan email ini.';

  @override
  String get signInNoAccountHint =>
      'Periksa emailnya, atau buat Firefox Account gratis dengan email ini di situs Mozilla, konfirmasi dari kotak masuk Anda, lalu tambahkan di sini.';

  @override
  String get createAccountButton => 'Buat Firefox Account';

  @override
  String get signInWrongPassword => 'Kata sandi salah.';

  @override
  String get signInNoPassword =>
      'Akun ini tidak punya kata sandi: dibuat dengan masuk lewat Google atau Apple. Atur kata sandi, lalu masuk di sini dengannya.';

  @override
  String get setPasswordButton => 'Atur kata sandi';

  @override
  String get signInTooManyAttempts =>
      'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';

  @override
  String get signInUnblockRejected =>
      'Kode pembuka blokir tidak diterima. Gunakan kode dari email terbaru Mozilla.';

  @override
  String get signInWrongCode =>
      'Kode salah atau kedaluwarsa. Gunakan kode dari email terbaru Mozilla; kode lama tidak berlaku lagi saat kode baru dikirim.';

  @override
  String get signInWrongTotp =>
      'Kode salah. Masukkan kode yang ditampilkan aplikasi autentikator sekarang.';

  @override
  String get signInTooManyCodes =>
      'Terlalu banyak kode salah. Mulai masuk dari awal.';

  @override
  String get signInTimedOut => 'Proses masuk terlalu lama. Mulai lagi.';

  @override
  String get signInNetwork =>
      'Mozilla tidak dapat dihubungi. Periksa internet Anda lalu coba lagi.';

  @override
  String get coreConnecting => 'Menghubungkan ke core…';

  @override
  String get coreLost => 'Koneksi ke core terputus. Mencoba lagi…';

  @override
  String get cantReachCore => 'Tidak dapat terhubung ke core';

  @override
  String get startingCore => 'Memulai core…';

  @override
  String get retry => 'Coba lagi';

  @override
  String errNoCore(String path) {
    return 'Program core tidak ditemukan di samping aplikasi ($path).';
  }

  @override
  String errCoreExited(String detail) {
    return 'Core berhenti: $detail';
  }

  @override
  String get errNotAnswering => 'Core tidak merespons.';

  @override
  String get errRefused =>
      'Core menolak aplikasi; mungkin core ini milik salinan aplikasi lain.';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get sectionGeneral => 'Umum';

  @override
  String get language => 'Bahasa';

  @override
  String get languageSystem => 'Bawaan sistem';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeDark => 'Gelap';

  @override
  String get closeBehavior => 'Saat menutup jendela';

  @override
  String get closeAsk => 'Selalu tanya';

  @override
  String get closeTray => 'Minimalkan ke tray';

  @override
  String get closeQuit => 'Keluar dari aplikasi';

  @override
  String get sectionConnection => 'Koneksi';

  @override
  String get localProxy => 'Proxy lokal';

  @override
  String get systemProxy => 'Proxy sistem';

  @override
  String get sectionRouting => 'Perutean';

  @override
  String get routingDirect => 'Koneksi langsung untuk situs lokal';

  @override
  String get routingDirectHint =>
      'Situs dan IP dari negara yang dipilih tidak lewat VPN, jadi lebih cepat dibuka dan hemat kuota.';

  @override
  String get region => 'Negara';

  @override
  String get regionIr => 'Iran';

  @override
  String get regionCn => 'Tiongkok';

  @override
  String get regionRu => 'Rusia';

  @override
  String get regionAf => 'Afganistan';

  @override
  String get regionTr => 'Turki';

  @override
  String get regionId => 'Indonesia';

  @override
  String get regionBr => 'Brasil';

  @override
  String get regionNone => 'Tidak ada';

  @override
  String get saved => 'Tersimpan';

  @override
  String get dataFolder => 'Folder data';

  @override
  String get openFolder => 'Buka folder';

  @override
  String get unofficialNote =>
      'Klien tidak resmi. Tidak berafiliasi dengan Mozilla.';

  @override
  String get closeTitle => 'Tutup jendela?';

  @override
  String get closeBody =>
      'Saat di tray, VPN tetap terhubung. Keluar akan memutus VPN.';

  @override
  String get rememberChoice => 'Ingat pilihan saya';

  @override
  String get minimizeToTray => 'Minimalkan ke tray';

  @override
  String get quit => 'Keluar';

  @override
  String get trayOpen => 'Buka';

  @override
  String get trayQuit => 'Keluar';

  @override
  String get trayProxyOnly => 'Hanya layanan proxy';

  @override
  String get traySetSystemProxy => 'Atur proxy sistem';

  @override
  String errPortInUse(String port) {
    return 'Port $port dipakai program lain, sehingga aplikasi tidak dapat terhubung ke core.';
  }

  @override
  String proxyPortInUse(String port) {
    return 'Port $port dipakai program lain, sehingga proxy tidak dapat dimulai.';
  }

  @override
  String get changePort => 'Ganti port';

  @override
  String get portDialogTitle => 'Pilih port';

  @override
  String portDialogBody(String port) {
    return 'Port $port sudah dipakai. Berikut port yang masih kosong; Anda juga bisa mengetik port lain.';
  }

  @override
  String get portChangeBody =>
      'Aplikasi terhubung ke port ini. Pilih antara 1024 dan 65535.';

  @override
  String get portLabel => 'Port';

  @override
  String get portInvalid => 'Masukkan port dari 1024 hingga 65535';

  @override
  String get portBusy => 'Port ini juga sedang dipakai';

  @override
  String get portInUse => 'Program lain memakai port ini';

  @override
  String get save => 'Simpan';

  @override
  String get proxyPort => 'Port proxy';

  @override
  String get appPort => 'Port aplikasi';

  @override
  String get welcomeTitle => 'Selamat datang';

  @override
  String get welcomeBody =>
      'Pilih bahasa dan negara Anda. Situs dari negara Anda dibuka langsung tanpa VPN, jadi lebih cepat dan hemat kuota.';

  @override
  String get start => 'Mulai';

  @override
  String routingSuggestTitle(String country) {
    return 'Buka situs $country secara langsung?';
  }

  @override
  String routingSuggestBody(String country) {
    return 'Situs dan IP $country akan dibuka langsung tanpa VPN. Anda bisa mengubahnya di Perutean.';
  }

  @override
  String get yes => 'Ya';

  @override
  String get notNow => 'Nanti saja';

  @override
  String get navServers => 'Server';

  @override
  String get navLogs => 'Log';

  @override
  String get realDelay => 'Ping asli';

  @override
  String noticePort(String port) {
    return 'Proxy Mozilla tidak bisa terhubung ke port $port. Hanya port 80, 443, 8080, dan 8443 yang bisa lewat VPN.';
  }

  @override
  String get noticeCommand =>
      'Sebuah aplikasi mencoba memakai UDP (game, panggilan suara dan video). Proxy Mozilla hanya mendukung TCP, jadi koneksi ini tidak bisa lewat.';

  @override
  String noticeTimes(int count, String time) {
    return '$count kali, terakhir $time';
  }

  @override
  String get dismiss => 'Tutup';

  @override
  String get modeRecommended => 'Disarankan';

  @override
  String get modeFastest => 'Tercepat';

  @override
  String get modeRecommendedHint => 'Mozilla memilihkan lokasi untuk Anda.';

  @override
  String get modeFastestHint =>
      'Lokasi dengan ping terendah, dipilih di setiap koneksi.';

  @override
  String get testDelay => 'Uji ping asli';

  @override
  String get testingDelay => 'Menguji… bisa sampai satu menit';

  @override
  String get search => 'Cari';

  @override
  String get noAnswer => 'Tidak merespons';

  @override
  String testedAgo(String ago) {
    return 'Diuji $ago';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$answered dari $total merespons';
  }

  @override
  String get noServers =>
      'Belum ada server. Server akan muncul setelah core terhubung ke Mozilla.';

  @override
  String get levelAll => 'Semua';

  @override
  String get filter => 'Filter';

  @override
  String get follow => 'Gulir otomatis';

  @override
  String get clear => 'Bersihkan';

  @override
  String get copyAll => 'Salin';

  @override
  String get logsCopied => 'Log disalin';

  @override
  String get noLogs => 'Belum ada baris log.';

  @override
  String get sectionAccounts => 'Ganti akun otomatis';

  @override
  String get switchThreshold => 'Ganti akun pada';

  @override
  String get switchThresholdHint =>
      'Pindah ke akun berikutnya saat kuota sudah terpakai sebanyak ini.';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'Server DNS';

  @override
  String get dnsSystem => 'Sistem';

  @override
  String get dnsAuto => 'Otomatis (Cloudflare, Google, Quad9)';

  @override
  String get dnsCustom => 'Kustom';

  @override
  String get dnsCustomHint =>
      'Satu per baris: https://…/dns-query, tls://…, atau alamat IP.';

  @override
  String get dnsFallback => 'Gunakan DNS sistem sebagai cadangan';

  @override
  String get testDns => 'Uji DNS';

  @override
  String get transport => 'Protokol';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'Langsung';

  @override
  String get directRulesHint =>
      'Situs dan alamat dalam daftar ini dibuka tanpa VPN, langsung lewat internet Anda sendiri. Aturan negara yang dipilih sudah ada di sini: tambah, ubah, atau hapus baris. Memilih negara lain menggantinya dengan aturan negara itu.';

  @override
  String get restoreRegionRules => 'Pulihkan aturan negara';

  @override
  String get blockRules => 'Blokir';

  @override
  String get blockRulesHint =>
      'Situs dan alamat dalam daftar ini tidak bisa dibuka sama sekali, baik langsung maupun lewat VPN: untuk iklan atau situs yang tidak pernah ingin Anda buka.';

  @override
  String get rulesTitle => 'Aturan';

  @override
  String get ruleSyntaxTitle => 'Cara menulis aturan';

  @override
  String get resolveDomains => 'Terapkan aturan IP ke domain';

  @override
  String get routingLists => 'File geo';

  @override
  String get listSource => 'Sumber daftar';

  @override
  String get listSourceCustom => 'Diatur manual';

  @override
  String listsUpdatedAgo(String ago) {
    return 'Diperbarui $ago';
  }

  @override
  String get updateLists => 'Perbarui file geo';

  @override
  String get listsUpdated => 'File geo telah diperbarui.';

  @override
  String get testDestination => 'Uji tujuan';

  @override
  String get destinationHint => 'Domain, alamat IP, atau URL';

  @override
  String get check => 'Periksa';

  @override
  String get routeDirect => 'Langsung';

  @override
  String get routeProxy => 'Melalui VPN';

  @override
  String get routeBlock => 'Diblokir';

  @override
  String ruleMatched(String rule) {
    return 'Aturan: $rule';
  }

  @override
  String get portRefusedNote =>
      'Proxy Mozilla tidak bisa terhubung ke port ini.';

  @override
  String get sectionAdvanced => 'Lanjutan';

  @override
  String get listenAddress => 'Akses proxy';

  @override
  String get listenLocal => '127.0.0.1 · hanya perangkat ini';

  @override
  String get listenAll => '0.0.0.0 · semua jaringan (LAN)';

  @override
  String get proxyUsername => 'Nama pengguna proxy';

  @override
  String get proxyPassword => 'Kata sandi proxy';

  @override
  String get proxyLoginHint =>
      'Aplikasi harus login dengan data ini. Kosongkan keduanya jika tidak perlu login.';

  @override
  String get loginBothOrNone => 'Isi keduanya, atau biarkan keduanya kosong.';

  @override
  String get proxyLogin => 'Login proxy';

  @override
  String get idleSleep => 'Tidur jika tidak aktif selama';

  @override
  String get sleepNever => 'Tidak pernah';

  @override
  String sleepMinutes(int count) {
    return '$count menit';
  }

  @override
  String get sleepHour => '1 jam';

  @override
  String get showPublicIp => 'Tampilkan IP publik';

  @override
  String get speedInNotification => 'Tampilkan kecepatan di notifikasi';

  @override
  String get liveTraffic => 'Lalu lintas langsung';

  @override
  String get totalTraffic => 'Total lalu lintas';

  @override
  String get verboseLogs => 'Log terperinci';

  @override
  String get webDashboard => 'Dasbor web';

  @override
  String get webDashboardOpen => 'Buka';

  @override
  String get webDashboardHint => 'Pengaturan lanjutan dan alat lainnya';

  @override
  String numberInvalid(int min, int max) {
    return 'Masukkan angka dari $min hingga $max';
  }

  @override
  String get notifySwitchedTitle => 'Akun diganti';

  @override
  String notifySwitchedBody(String name) {
    return 'Sekarang menggunakan $name.';
  }

  @override
  String get notifySignInTitle => 'Perlu masuk';

  @override
  String get notifySignInBody =>
      'Sebuah akun harus masuk lagi di halaman Akun.';

  @override
  String get navAbout => 'Tentang';

  @override
  String get appVersionLabel => 'Versi aplikasi';

  @override
  String get coreVersionLabel => 'Versi core';

  @override
  String get checkUpdates => 'Periksa pembaruan';

  @override
  String get checkingUpdates => 'Memeriksa…';

  @override
  String get upToDate => 'Anda memiliki versi terbaru.';

  @override
  String updateAvailable(String version) {
    return 'Versi $version tersedia.';
  }

  @override
  String get download => 'Unduh';

  @override
  String updateCheckFailed(String error) {
    return 'Tidak dapat memeriksa pembaruan: $error';
  }

  @override
  String get repoNotSet => 'Repositori GitHub belum diatur.';

  @override
  String get sourceCode => 'Kode sumber';

  @override
  String get tapToConnect => 'Klik untuk terhubung';

  @override
  String get tapToDisconnect => 'Klik untuk memutus koneksi';

  @override
  String get startOnBoot => 'Mulai saat sistem menyala';

  @override
  String get connectOnStartup => 'Sambungkan saat sistem menyala';

  @override
  String get proxyServiceActive => 'Layanan proxy aktif';

  @override
  String get navHome => 'Beranda';

  @override
  String get groupApp => 'Aplikasi';

  @override
  String get stateOff => 'Tidak terhubung';

  @override
  String get tapToConnectPhone => 'Ketuk untuk terhubung';

  @override
  String get tapToDisconnectPhone => 'Ketuk untuk memutus koneksi';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'Lokasi yang disarankan';

  @override
  String dataLeftOf(String limit) {
    return 'dari $limit';
  }

  @override
  String get homeLocation => 'Lokasi';

  @override
  String get connectedTo => 'Terhubung ke';

  @override
  String get vpnNotAllowed =>
      'VPN memerlukan izin Anda. Ketuk tombol lagi dan izinkan.';

  @override
  String get dataUsedTitle => 'Data terpakai';

  @override
  String get bypassApps => 'Proxy per aplikasi';

  @override
  String get connectRetrying => 'Tidak dapat terhubung. Periksa internet Anda.';

  @override
  String get failUnreachable =>
      'Server Mozilla diblokir di internet ini. Coba koneksi internet lain.';

  @override
  String get failRefused =>
      'Server Mozilla menolak koneksi. Coba lagi dalam beberapa menit.';

  @override
  String get failLocationRefused =>
      'Negara ini tidak terbuka untuk akun Anda. Pilih negara lain.';

  @override
  String get useRecommendedLocation => 'Gunakan lokasi yang disarankan';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'Anda memilih $chosen, tetapi IP Anda berada di $exit.';
  }

  @override
  String get failSignIn =>
      'Sesi masuk akun ini sudah kedaluwarsa. Masuk lagi di halaman Akun.';

  @override
  String get failQuota => 'Kuota bulan ini habis. Tambahkan akun lain.';

  @override
  String get failNotEntitled =>
      'Mozilla tidak mengizinkan akun ini memakai VPN. Tambahkan akun lain.';

  @override
  String get failRegion =>
      'Mozilla tidak menyediakan layanannya di negara Anda.';

  @override
  String get failServer =>
      'Layanan Mozilla sedang bermasalah sementara. Aplikasi akan mencoba lagi sendiri.';

  @override
  String get failNoAccount => 'Tidak ada akun yang siap. Buka halaman Akun.';

  @override
  String get failTestSite =>
      'Terhubung ke server, tetapi situs tidak terbuka. Coba negara lain.';

  @override
  String get failOther => 'Tidak dapat terhubung. Coba lagi.';

  @override
  String get failNoInternet =>
      'Tidak ada internet. Periksa Wi-Fi atau data seluler.';

  @override
  String get waitingForNetwork => 'Menunggu koneksi internet…';

  @override
  String proxyStartFailed(String port) {
    return 'Proxy tidak dapat dimulai di port $port. Pilih port lain.';
  }

  @override
  String get connectionSettings => 'Pengaturan koneksi';

  @override
  String get appModeExclude => 'Kecualikan aplikasi terpilih';

  @override
  String get appModeInclude => 'Hanya aplikasi terpilih';

  @override
  String get appModeExcludeHint =>
      'Aplikasi terpilih terhubung langsung, tidak lewat VPN; misalnya aplikasi bank yang menolak IP luar negeri.';

  @override
  String get appModeIncludeHint =>
      'Hanya aplikasi terpilih yang lewat VPN; aplikasi lain terhubung langsung.';

  @override
  String fromRegionList(String region) {
    return 'Disarankan: ada di daftar $region';
  }

  @override
  String get modeProxy => 'Proxy';

  @override
  String get connectionMode => 'Mode koneksi';

  @override
  String get modeProxyHint =>
      'Hanya aplikasi yang diatur memakai proxy yang lewat proxy; pengaturan Windows tidak diubah.';

  @override
  String get modeSystemProxyHint =>
      'Windows dan sebagian besar aplikasi lewat proxy.';

  @override
  String get modeProxyHintOther =>
      'Hanya aplikasi yang diatur memakai proxy yang lewat proxy; pengaturan sistem tidak diubah.';

  @override
  String get modeSystemProxyHintOther =>
      'Browser dan sebagian besar aplikasi lewat proxy.';

  @override
  String get suggestedApps => 'Aplikasi yang disarankan';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aplikasi yang disarankan dipilih',
      one: '1 aplikasi yang disarankan dipilih',
      zero: 'Aplikasi yang disarankan sudah dipilih',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'Otomatis';

  @override
  String get locationsSection => 'Lokasi';

  @override
  String get dnsSummaryOk => 'DNS terenkripsi berfungsi';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nama tidak dapat di-resolve',
      one: '1 nama tidak dapat di-resolve',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return 'melalui $server';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'DNS jaringan Anda menjawab $count nama dengan alamat pemblokiran. Aplikasi ini tidak memakai jawaban tersebut.',
      one: 'DNS jaringan Anda menjawab 1 nama dengan alamat pemblokiran. Aplikasi ini tidak memakai jawaban tersebut.',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'Jawaban:';

  @override
  String get dnsNetworkAnswer => 'DNS jaringan:';

  @override
  String get dnsFiltered => 'diblokir';

  @override
  String get rulesSyntaxTitle => 'Satu aturan per baris';

  @override
  String get ruleDomain => 'Situs dan subdomainnya';

  @override
  String get ruleFull => 'Persis nama ini';

  @override
  String get ruleKeyword => 'Nama yang mengandung kata ini';

  @override
  String get ruleGeosite => 'Situs dari sebuah tag di file geo';

  @override
  String get ruleGeoip => 'Alamat dari sebuah negara di file geo';

  @override
  String get ruleIp => 'Alamat atau jaringan';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'Hanya proxy';

  @override
  String get noNetwork =>
      'Tidak ada koneksi internet. Nyalakan Wi-Fi atau data seluler.';

  @override
  String get blockAds => 'Blokir iklan';

  @override
  String systemProxyTakenBy(String address) {
    return 'Program lain mengubah proxy sistem ke $address, jadi lalu lintas tidak melewati VPN.';
  }

  @override
  String get systemProxyTakenOff =>
      'Program lain mematikan proxy sistem, jadi lalu lintas tidak melewati VPN.';

  @override
  String get setSystemProxyAgain => 'Atur lagi';
}
