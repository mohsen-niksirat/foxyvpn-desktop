// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => 'Обзор';

  @override
  String get navAccounts => 'Аккаунты';

  @override
  String get navSettings => 'Настройки';

  @override
  String get stateConnected => 'Подключено';

  @override
  String get stateConnecting => 'Подключение…';

  @override
  String get stateWaiting => 'Ожидание';

  @override
  String get waitingForAccount =>
      'Добавьте аккаунт Firefox на странице «Аккаунты», чтобы подключиться.';

  @override
  String get waitingForEnabledAccount =>
      'Все аккаунты выключены. Включите один на странице «Аккаунты».';

  @override
  String get stateError => 'Ошибка';

  @override
  String get stateUnknown => 'Неизвестно';

  @override
  String get restartProxy => 'Перезапустить прокси';

  @override
  String copied(String value) {
    return 'Скопировано: $value';
  }

  @override
  String get activeAccount => 'Активный аккаунт';

  @override
  String get noActiveAccount => 'Нет активного аккаунта';

  @override
  String get quotaNotRead => 'Остаток трафика ещё неизвестен';

  @override
  String get unlimited => 'Без ограничений';

  @override
  String usedOf(String used, String limit) {
    return 'использовано $used из $limit';
  }

  @override
  String resets(String date) {
    return 'обнулится $date';
  }

  @override
  String switchAt(int percent) {
    return 'Смена аккаунта при $percent%';
  }

  @override
  String get publicIp => 'Публичный IP';

  @override
  String get testConnection => 'Проверить';

  @override
  String get testing => 'Проверка…';

  @override
  String get testFailed => 'Ошибка';

  @override
  String milliseconds(int value) {
    return '$value мс';
  }

  @override
  String get justNow => 'только что';

  @override
  String minutesAgo(int n) {
    return '$n мин назад';
  }

  @override
  String hoursAgo(int n) {
    return '$n ч назад';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней назад',
      few: '$count дня назад',
      one: '$count день назад',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return 'в $time';
  }

  @override
  String durationDays(int d, int h) {
    return '$d д $h ч';
  }

  @override
  String durationHours(int h, int m) {
    return '$h ч $m мин';
  }

  @override
  String durationMinutes(int m, int s) {
    return '$m мин $s с';
  }

  @override
  String durationSeconds(int s) {
    return '$s с';
  }

  @override
  String accountsGuide(String size) {
    return 'У каждого Firefox Account $size трафика в месяц. Можно добавить несколько: когда один закончится, приложение само перейдёт к следующему.';
  }

  @override
  String accountsOrderNote(int percent) {
    return 'В порядке этого списка: каждый до $percent%, последний — пока не кончится трафик.';
  }

  @override
  String get addAccount => 'Добавить аккаунт';

  @override
  String lowQuotaNotice(String left, String size) {
    return 'Трафик текущего аккаунта заканчивается (осталось $left). Добавьте ещё один аккаунт — это ещё $size.';
  }

  @override
  String get noAccounts => 'Аккаунтов пока нет';

  @override
  String get noAccountsHint => 'Добавьте аккаунт Firefox, чтобы подключиться.';

  @override
  String get createAccountTitle => 'Нет Firefox Account?';

  @override
  String get createAccountHint =>
      'Создайте его бесплатно на accounts.firefox.com, затем вернитесь и нажмите «Добавить аккаунт».';

  @override
  String get moveUp => 'Вверх';

  @override
  String get moveDown => 'Вниз';

  @override
  String get statusActive => 'Активен';

  @override
  String get statusReady => 'Готов';

  @override
  String get statusNeedsSignIn => 'Нужен вход';

  @override
  String get statusReserved => 'В резерве';

  @override
  String get statusUnavailable => 'Недоступен';

  @override
  String statusUnavailableUntil(String date) {
    return 'Недоступен до $date';
  }

  @override
  String get statusDisabled => 'Отключён';

  @override
  String get statusEnabled => 'Включён';

  @override
  String get useNow => 'Использовать';

  @override
  String get signInAgain => 'Войти снова';

  @override
  String reasonQuotaThreshold(int percent) {
    return 'Аккаунт израсходовал $percent% трафика, поэтому подключился следующий.';
  }

  @override
  String get reasonQuotaExhausted =>
      'Трафик на этот месяц закончился; аккаунт снова используется после обнуления.';

  @override
  String get reasonSignInRequired =>
      'Войдите снова, чтобы использовать этот аккаунт.';

  @override
  String get reasonSignInConfirm =>
      'Mozilla просит подтвердить вход: нажмите «Войти снова» (нужен только код).';

  @override
  String reasonSignInFailed(String detail) {
    return 'Автоматический вход не удался ($detail). Войдите снова.';
  }

  @override
  String reasonSignInWait(String time) {
    return 'Последний автоматический вход вскоре перестал работать; следующая попытка в $time.';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return 'Автоматический вход не завершился ($detail); повтор в $time.';
  }

  @override
  String get reasonNotEntitled =>
      'Mozilla отклонила этот аккаунт; повторим позже.';

  @override
  String get more => 'Ещё';

  @override
  String get refreshQuota => 'Проверить остаток трафика';

  @override
  String get remove => 'Удалить';

  @override
  String get removeTitle => 'Удалить аккаунт?';

  @override
  String removeBody(String name) {
    return '$name и сохранённые данные входа будут удалены с этого компьютера. Позже его можно добавить снова.';
  }

  @override
  String get unlimitedQuota => 'Безлимитный трафик';

  @override
  String get signInTitle => 'Вход';

  @override
  String get signInIntro => 'Войдите в аккаунт Firefox.';

  @override
  String get email => 'Эл. почта';

  @override
  String get emailInvalid => 'Введите почту аккаунта';

  @override
  String get password => 'Пароль';

  @override
  String get passwordEmpty => 'Введите пароль';

  @override
  String get show => 'Показать';

  @override
  String get hide => 'Скрыть';

  @override
  String get signIn => 'Войти';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get done => 'Готово';

  @override
  String get close => 'Закрыть';

  @override
  String get cancel => 'Отмена';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get signingIn => 'Вход…';

  @override
  String get accountReady => 'Аккаунт готов';

  @override
  String get accountReadyHint => 'Он добавлен в конец списка аккаунтов.';

  @override
  String get captchaLabel => 'Символы на картинке';

  @override
  String get codeLabel => 'Код';

  @override
  String get captchaBroken => 'Не удалось показать CAPTCHA.';

  @override
  String stepEmailCode(String email) {
    return 'Mozilla отправила код на $email. Введите его здесь.';
  }

  @override
  String get stepTotp => 'Введите код из приложения-аутентификатора.';

  @override
  String stepUnblockCode(String email) {
    return 'Mozilla сочла этот вход подозрительным и отправила код разблокировки на $email. Введите его здесь.';
  }

  @override
  String get stepCaptcha => 'Введите символы с картинки.';

  @override
  String stepEmailLink(String email) {
    return 'Откройте ссылку подтверждения, которую Mozilla отправила на $email. Дальше вход продолжится автоматически.';
  }

  @override
  String get signInFailed => 'Аккаунт не добавлен.';

  @override
  String get signInCancelled => 'Вход отменён.';

  @override
  String get signInNoAccount => 'Firefox Account с этой почтой не существует.';

  @override
  String get signInNoAccountHint =>
      'Проверьте адрес или создайте с ним бесплатный Firefox Account на сайте Mozilla, подтвердите его из письма, а затем добавьте здесь.';

  @override
  String get createAccountButton => 'Создать Firefox Account';

  @override
  String get signInWrongPassword => 'Неверный пароль.';

  @override
  String get signInNoPassword =>
      'У этого аккаунта нет пароля: он создан через вход с Google или Apple. Задайте пароль, а затем войдите с ним здесь.';

  @override
  String get setPasswordButton => 'Задать пароль';

  @override
  String get signInTooManyAttempts =>
      'Слишком много попыток. Подождите немного и попробуйте снова.';

  @override
  String get signInUnblockRejected =>
      'Код разблокировки не принят. Используйте код из последнего письма Mozilla.';

  @override
  String get signInWrongCode =>
      'Неверный или просроченный код. Используйте код из последнего письма Mozilla; старый код перестаёт работать, когда приходит новый.';

  @override
  String get signInWrongTotp =>
      'Неверный код. Введите код, который сейчас показывает приложение-аутентификатор.';

  @override
  String get signInTooManyCodes =>
      'Слишком много неверных кодов. Начните вход заново.';

  @override
  String get signInTimedOut =>
      'Вход занял слишком много времени. Начните заново.';

  @override
  String get signInNetwork =>
      'Не удалось связаться с Mozilla. Проверьте интернет и попробуйте снова.';

  @override
  String get coreConnecting => 'Подключение к ядру…';

  @override
  String get coreLost => 'Связь с ядром потеряна. Повторная попытка…';

  @override
  String get cantReachCore => 'Нет связи с ядром';

  @override
  String get startingCore => 'Запуск ядра…';

  @override
  String get retry => 'Повторить';

  @override
  String errNoCore(String path) {
    return 'Файл ядра не найден рядом с приложением ($path).';
  }

  @override
  String errCoreExited(String detail) {
    return 'Ядро остановилось: $detail';
  }

  @override
  String get errNotAnswering => 'Ядро не отвечает.';

  @override
  String get errRefused =>
      'Ядро отклонило подключение приложения: возможно, оно принадлежит другой копии.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get sectionGeneral => 'Общие';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get closeBehavior => 'При закрытии окна';

  @override
  String get closeAsk => 'Спрашивать каждый раз';

  @override
  String get closeTray => 'Свернуть в трей';

  @override
  String get closeQuit => 'Выйти из приложения';

  @override
  String get sectionConnection => 'Подключение';

  @override
  String get localProxy => 'Локальный прокси';

  @override
  String get systemProxy => 'Системный прокси';

  @override
  String get sectionRouting => 'Маршрутизация';

  @override
  String get routingDirect => 'Прямое подключение к местным сайтам';

  @override
  String get routingDirectHint =>
      'Сайты и IP выбранной страны открываются напрямую, мимо VPN: быстрее и без расхода трафика.';

  @override
  String get region => 'Страна';

  @override
  String get regionIr => 'Иран';

  @override
  String get regionCn => 'Китай';

  @override
  String get regionRu => 'Россия';

  @override
  String get regionAf => 'Афганистан';

  @override
  String get regionTr => 'Турция';

  @override
  String get regionId => 'Индонезия';

  @override
  String get regionBr => 'Бразилия';

  @override
  String get regionNone => 'Нет';

  @override
  String get saved => 'Сохранено';

  @override
  String get dataFolder => 'Папка данных';

  @override
  String get openFolder => 'Открыть папку';

  @override
  String get unofficialNote => 'Неофициальный клиент. Не связан с Mozilla.';

  @override
  String get closeTitle => 'Закрыть окно?';

  @override
  String get closeBody =>
      'Если свернуть окно в трей, VPN останется включённым. При выходе он отключится.';

  @override
  String get rememberChoice => 'Запомнить выбор';

  @override
  String get minimizeToTray => 'Свернуть в трей';

  @override
  String get quit => 'Выйти';

  @override
  String get trayOpen => 'Открыть';

  @override
  String get trayQuit => 'Выйти';

  @override
  String get trayProxyOnly => 'Только прокси-сервис';

  @override
  String get traySetSystemProxy => 'Включить системный прокси';

  @override
  String errPortInUse(String port) {
    return 'Порт $port занят другой программой, и приложение не может связаться с ядром.';
  }

  @override
  String proxyPortInUse(String port) {
    return 'Порт $port занят другой программой, и прокси не может запуститься.';
  }

  @override
  String get changePort => 'Сменить порт';

  @override
  String get portDialogTitle => 'Выбор порта';

  @override
  String portDialogBody(String port) {
    return 'Порт $port занят. Ниже предложен свободный порт; можно ввести другой.';
  }

  @override
  String get portChangeBody =>
      'Приложения подключаются к этому порту. Выберите порт от 1024 до 65535.';

  @override
  String get portLabel => 'Порт';

  @override
  String get portInvalid => 'Введите порт от 1024 до 65535';

  @override
  String get portBusy => 'Этот порт тоже занят';

  @override
  String get portInUse => 'Этот порт занят другой программой';

  @override
  String get save => 'Сохранить';

  @override
  String get proxyPort => 'Порт прокси';

  @override
  String get appPort => 'Порт приложения';

  @override
  String get welcomeTitle => 'Добро пожаловать';

  @override
  String get welcomeBody =>
      'Выберите язык и страну. Сайты вашей страны будут открываться напрямую, без VPN: так быстрее и не расходуется трафик.';

  @override
  String get start => 'Начать';

  @override
  String routingSuggestTitle(String country) {
    return 'Прямое подключение: $country?';
  }

  @override
  String routingSuggestBody(String country) {
    return 'Сайты и IP страны «$country» будут открываться напрямую, без VPN. Это можно изменить в разделе «Маршрутизация».';
  }

  @override
  String get yes => 'Да';

  @override
  String get notNow => 'Не сейчас';

  @override
  String get navServers => 'Серверы';

  @override
  String get navLogs => 'Логи';

  @override
  String get realDelay => 'Реальная задержка';

  @override
  String noticePort(String port) {
    return 'Прокси Mozilla не подключается к порту $port. Через VPN идут только порты 80, 443, 8080 и 8443.';
  }

  @override
  String get noticeCommand =>
      'Приложение запросило UDP (игры, голосовые и видеозвонки). Прокси Mozilla передаёт только TCP, поэтому такой трафик не проходит.';

  @override
  String noticeTimes(int count, String time) {
    return 'Раз: $count, последний — $time';
  }

  @override
  String get dismiss => 'Скрыть';

  @override
  String get modeRecommended => 'Рекомендуемый';

  @override
  String get modeFastest => 'Самый быстрый';

  @override
  String get modeRecommendedHint => 'Mozilla выбирает локацию за вас.';

  @override
  String get modeFastestHint =>
      'При каждом подключении выбирается локация с наименьшей задержкой.';

  @override
  String get testDelay => 'Проверить задержку';

  @override
  String get testingDelay => 'Проверка… это может занять до минуты';

  @override
  String get search => 'Поиск';

  @override
  String get noAnswer => 'Нет ответа';

  @override
  String testedAgo(String ago) {
    return 'Проверено $ago';
  }

  @override
  String delaySummary(int answered, int total) {
    return 'Ответили $answered из $total';
  }

  @override
  String get noServers =>
      'Серверов пока нет. Они появятся, когда ядро свяжется с Mozilla.';

  @override
  String get levelAll => 'Все';

  @override
  String get filter => 'Фильтр';

  @override
  String get follow => 'Автопрокрутка';

  @override
  String get clear => 'Очистить';

  @override
  String get copyAll => 'Копировать всё';

  @override
  String get logsCopied => 'Логи скопированы';

  @override
  String get noLogs => 'Логов пока нет.';

  @override
  String get sectionAccounts => 'Автосмена аккаунтов';

  @override
  String get switchThreshold => 'Менять аккаунт при';

  @override
  String get switchThresholdHint =>
      'Когда израсходована эта доля трафика, включается следующий аккаунт.';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'DNS-серверы';

  @override
  String get dnsSystem => 'Системные';

  @override
  String get dnsAuto => 'Авто (Cloudflare, Google, Quad9)';

  @override
  String get dnsCustom => 'Свои';

  @override
  String get dnsCustomHint =>
      'По одному на строку: https://…/dns-query, tls://… или IP-адрес.';

  @override
  String get dnsFallback => 'Системный DNS как запасной';

  @override
  String get testDns => 'Проверить DNS';

  @override
  String get transport => 'Протокол';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => 'Напрямую';

  @override
  String get directRulesHint =>
      'Сайты и адреса из этого списка открываются без VPN, напрямую через ваш интернет. Правила выбранной страны уже здесь: добавляйте, меняйте или удаляйте строки. Выбор другой страны заменит их её правилами.';

  @override
  String get restoreRegionRules => 'Вернуть правила страны';

  @override
  String get blockRules => 'Блокировать';

  @override
  String get blockRulesHint =>
      'Сайты и адреса из этого списка не открываются вообще — ни напрямую, ни через VPN: для рекламы или сайтов, которые не должны открываться никогда.';

  @override
  String get rulesTitle => 'Правила';

  @override
  String get ruleSyntaxTitle => 'Как написать правило';

  @override
  String get resolveDomains => 'Применять IP-правила к доменам';

  @override
  String get routingLists => 'Geo-файлы';

  @override
  String get listSource => 'Источник списков';

  @override
  String get listSourceCustom => 'Задано вручную';

  @override
  String listsUpdatedAgo(String ago) {
    return 'Обновлено $ago';
  }

  @override
  String get updateLists => 'Обновить geo-файлы';

  @override
  String get listsUpdated => 'Geo-файлы обновлены.';

  @override
  String get testDestination => 'Проверить маршрут';

  @override
  String get destinationHint => 'Домен, IP-адрес или URL';

  @override
  String get check => 'Проверить';

  @override
  String get routeDirect => 'Напрямую';

  @override
  String get routeProxy => 'Через VPN';

  @override
  String get routeBlock => 'Заблокировано';

  @override
  String ruleMatched(String rule) {
    return 'Правило: $rule';
  }

  @override
  String get portRefusedNote => 'Прокси Mozilla не подключается к этому порту.';

  @override
  String get sectionAdvanced => 'Дополнительно';

  @override
  String get listenAddress => 'Доступ к прокси';

  @override
  String get listenLocal => '127.0.0.1 · только это устройство';

  @override
  String get listenAll => '0.0.0.0 · все сети (LAN)';

  @override
  String get proxyUsername => 'Имя пользователя прокси';

  @override
  String get proxyPassword => 'Пароль прокси';

  @override
  String get proxyLoginHint =>
      'Приложениям нужно будет указать эти данные. Оставьте оба поля пустыми, чтобы прокси работал без пароля.';

  @override
  String get loginBothOrNone => 'Заполните оба поля или оставьте оба пустыми.';

  @override
  String get proxyLogin => 'Логин и пароль прокси';

  @override
  String get idleSleep => 'Спящий режим после простоя';

  @override
  String get sleepNever => 'Никогда';

  @override
  String sleepMinutes(int count) {
    return '$count мин';
  }

  @override
  String get sleepHour => '1 час';

  @override
  String get showPublicIp => 'Показывать публичный IP';

  @override
  String get speedInNotification => 'Показывать скорость в уведомлении';

  @override
  String get liveTraffic => 'Текущий трафик';

  @override
  String get totalTraffic => 'Всего трафика';

  @override
  String get verboseLogs => 'Подробные логи';

  @override
  String get webDashboard => 'Веб-панель';

  @override
  String get webDashboardOpen => 'Открыть';

  @override
  String get webDashboardHint => 'Расширенные настройки и другие инструменты';

  @override
  String numberInvalid(int min, int max) {
    return 'Введите число от $min до $max';
  }

  @override
  String get notifySwitchedTitle => 'Аккаунт сменён';

  @override
  String notifySwitchedBody(String name) {
    return 'Теперь используется $name.';
  }

  @override
  String get notifySignInTitle => 'Нужен вход';

  @override
  String get notifySignInBody =>
      'Войдите снова в один из аккаунтов на странице «Аккаунты».';

  @override
  String get navAbout => 'О программе';

  @override
  String get appVersionLabel => 'Версия приложения';

  @override
  String get coreVersionLabel => 'Версия ядра';

  @override
  String get checkUpdates => 'Проверить обновления';

  @override
  String get checkingUpdates => 'Проверка…';

  @override
  String get upToDate => 'У вас последняя версия.';

  @override
  String updateAvailable(String version) {
    return 'Доступна версия $version.';
  }

  @override
  String get download => 'Скачать';

  @override
  String updateCheckFailed(String error) {
    return 'Не удалось проверить обновления: $error';
  }

  @override
  String get repoNotSet => 'Репозиторий GitHub ещё не указан.';

  @override
  String get sourceCode => 'Исходный код';

  @override
  String get tapToConnect => 'Нажмите, чтобы подключиться';

  @override
  String get tapToDisconnect => 'Нажмите, чтобы отключиться';

  @override
  String get startOnBoot => 'Запускать при включении';

  @override
  String get connectOnStartup => 'Подключаться при включении';

  @override
  String get proxyServiceActive => 'Прокси-служба работает';

  @override
  String get navHome => 'Главная';

  @override
  String get groupApp => 'Приложение';

  @override
  String get stateOff => 'Отключено';

  @override
  String get tapToConnectPhone => 'Нажмите, чтобы подключиться';

  @override
  String get tapToDisconnectPhone => 'Нажмите, чтобы отключиться';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => 'Рекомендуемая локация';

  @override
  String dataLeftOf(String limit) {
    return 'из $limit';
  }

  @override
  String get homeLocation => 'Локация';

  @override
  String get connectedTo => 'Подключено к';

  @override
  String get vpnNotAllowed =>
      'Для VPN нужно ваше разрешение. Нажмите кнопку ещё раз и разрешите подключение.';

  @override
  String get dataUsedTitle => 'Использовано';

  @override
  String get bypassApps => 'Раздельное туннелирование';

  @override
  String get connectRetrying => 'Не удалось подключиться. Проверьте интернет.';

  @override
  String get failUnreachable =>
      'Серверы Mozilla заблокированы в этой сети. Попробуйте другое подключение к интернету.';

  @override
  String get failRefused =>
      'Сервер Mozilla отклонил подключение. Попробуйте снова через несколько минут.';

  @override
  String get failLocationRefused =>
      'Эта страна недоступна для вашего аккаунта. Выберите другую страну.';

  @override
  String get useRecommendedLocation => 'Использовать рекомендуемую локацию';

  @override
  String exitMismatch(String exit, String chosen) {
    return 'Выбрано: $chosen, но ваш IP определяется как $exit.';
  }

  @override
  String get failSignIn =>
      'Сеанс этого аккаунта истёк. Войдите снова на странице «Аккаунты».';

  @override
  String get failQuota =>
      'Трафик этого месяца исчерпан. Добавьте другой аккаунт.';

  @override
  String get failNotEntitled =>
      'Mozilla не разрешает этому аккаунту пользоваться VPN. Добавьте другой аккаунт.';

  @override
  String get failRegion => 'Mozilla не предоставляет сервис в вашей стране.';

  @override
  String get failServer =>
      'Временная проблема в сервисе Mozilla. Приложение само попробует снова.';

  @override
  String get failNoAccount =>
      'Нет готового аккаунта. Откройте страницу «Аккаунты».';

  @override
  String get failTestSite =>
      'Подключено к серверу, но сайты не открываются. Попробуйте другую страну.';

  @override
  String get failOther => 'Не удалось подключиться. Попробуйте снова.';

  @override
  String get failNoInternet =>
      'Нет интернета. Проверьте Wi-Fi или мобильный интернет.';

  @override
  String get waitingForNetwork => 'Ожидание подключения к интернету…';

  @override
  String proxyStartFailed(String port) {
    return 'Прокси не удалось запустить на порту $port. Выберите другой порт.';
  }

  @override
  String get connectionSettings => 'Настройки подключения';

  @override
  String get appModeExclude => 'Выбранные приложения — напрямую';

  @override
  String get appModeInclude => 'Только выбранные — через VPN';

  @override
  String get appModeExcludeHint =>
      'Выбранные приложения подключаются напрямую, не через VPN: например, банковские, которые не пускают с зарубежных IP.';

  @override
  String get appModeIncludeHint =>
      'Через VPN идут только выбранные приложения; остальные подключаются напрямую.';

  @override
  String fromRegionList(String region) {
    return 'Рекомендуется: есть в списке «$region»';
  }

  @override
  String get modeProxy => 'Прокси';

  @override
  String get connectionMode => 'Режим подключения';

  @override
  String get modeProxyHint =>
      'Через прокси идут только приложения, в которых он настроен; настройки Windows не меняются.';

  @override
  String get modeSystemProxyHint =>
      'Через прокси идут Windows и большинство приложений.';

  @override
  String get modeProxyHintOther =>
      'Через прокси идут только приложения, в которых он настроен; настройки системы не меняются.';

  @override
  String get modeSystemProxyHintOther =>
      'Через прокси идут браузеры и большинство приложений.';

  @override
  String get suggestedApps => 'Рекомендуемые приложения';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count рекомендуемых приложений',
      few: 'Выбрано $count рекомендуемых приложения',
      one: 'Выбрано $count рекомендуемое приложение',
      zero: 'Рекомендуемые приложения уже выбраны',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => 'Автоматически';

  @override
  String get locationsSection => 'Локации';

  @override
  String get dnsSummaryOk => 'Шифрованный DNS работает';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не удалось разрешить $count имён',
      few: 'Не удалось разрешить $count имени',
      one: 'Не удалось разрешить $count имя',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return 'через $server';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'DNS вашей сети вернул адрес фильтра для $count имён. Приложение такие ответы не использует.',
      one:
          'DNS вашей сети вернул адрес фильтра для $count имени. Приложение такие ответы не использует.',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => 'Ответ:';

  @override
  String get dnsNetworkAnswer => 'DNS сети:';

  @override
  String get dnsFiltered => 'фильтруется';

  @override
  String get rulesSyntaxTitle => 'По одному правилу в строке';

  @override
  String get ruleDomain => 'Сайт и его поддомены';

  @override
  String get ruleFull => 'Только этот домен';

  @override
  String get ruleKeyword => 'Домены, содержащие слово';

  @override
  String get ruleGeosite => 'Сайты с тегом из geo-файлов';

  @override
  String get ruleGeoip => 'IP-адреса страны из geo-файлов';

  @override
  String get ruleIp => 'IP-адрес или подсеть';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => 'Только прокси';

  @override
  String get noNetwork =>
      'Нет подключения к интернету. Включите Wi-Fi или мобильные данные.';

  @override
  String get blockAds => 'Блокировать рекламу';

  @override
  String systemProxyTakenBy(String address) {
    return 'Другая программа переключила системный прокси на $address, поэтому трафик идёт не через VPN.';
  }

  @override
  String get systemProxyTakenOff =>
      'Другая программа выключила системный прокси, поэтому трафик идёт не через VPN.';

  @override
  String get setSystemProxyAgain => 'Настроить снова';
}
