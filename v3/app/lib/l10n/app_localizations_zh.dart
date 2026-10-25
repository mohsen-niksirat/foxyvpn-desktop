// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => '概览';

  @override
  String get navAccounts => '账户';

  @override
  String get navSettings => '设置';

  @override
  String get stateConnected => '已连接';

  @override
  String get stateConnecting => '正在连接…';

  @override
  String get stateWaiting => '等待中';

  @override
  String get waitingForAccount => '在“账户”页添加 Firefox 账户后即可连接。';

  @override
  String get waitingForEnabledAccount => '所有账户都已关闭。请在“账户”页启用一个。';

  @override
  String get stateError => '错误';

  @override
  String get stateUnknown => '未知';

  @override
  String get restartProxy => '重启代理';

  @override
  String copied(String value) {
    return '已复制 $value';
  }

  @override
  String get activeAccount => '当前账户';

  @override
  String get noActiveAccount => '暂无使用中的账户';

  @override
  String get quotaNotRead => '尚未获取流量信息';

  @override
  String get unlimited => '不限量';

  @override
  String usedOf(String used, String limit) {
    return '已用 $used / $limit';
  }

  @override
  String resets(String date) {
    return '$date 重置';
  }

  @override
  String switchAt(int percent) {
    return '流量用到 $percent% 时切换账户';
  }

  @override
  String get publicIp => '公网 IP';

  @override
  String get testConnection => '测试连接';

  @override
  String get testing => '正在测试…';

  @override
  String get testFailed => '失败';

  @override
  String milliseconds(int value) {
    return '$value ms';
  }

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String hoursAgo(int n) {
    return '$n 小时前';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return '$time';
  }

  @override
  String durationDays(int d, int h) {
    return '$d 天 $h 小时';
  }

  @override
  String durationHours(int h, int m) {
    return '$h 小时 $m 分';
  }

  @override
  String durationMinutes(int m, int s) {
    return '$m 分 $s 秒';
  }

  @override
  String durationSeconds(int s) {
    return '$s 秒';
  }

  @override
  String accountsGuide(String size) {
    return '每个 Firefox 账户每月有 $size 流量。你可以添加多个账户：一个用完后，应用会自动切换到下一个。';
  }

  @override
  String accountsOrderNote(int percent) {
    return '按此列表顺序使用：每个账户用到 $percent%，最后一个用到流量耗尽。';
  }

  @override
  String get addAccount => '添加账户';

  @override
  String lowQuotaNotice(String left, String size) {
    return '当前账户的流量快用完了（剩余 $left）。再添加一个账户，可再获得 $size。';
  }

  @override
  String get noAccounts => '还没有账户';

  @override
  String get noAccountsHint => '添加 Firefox 账户即可连接。';

  @override
  String get createAccountTitle => '还没有 Firefox 账户？';

  @override
  String get createAccountHint =>
      '可在 accounts.firefox.com 免费注册，然后回到这里点击“添加账户”。';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get statusActive => '使用中';

  @override
  String get statusReady => '可用';

  @override
  String get statusNeedsSignIn => '需要登录';

  @override
  String get statusReserved => '备用';

  @override
  String get statusUnavailable => '不可用';

  @override
  String statusUnavailableUntil(String date) {
    return '$date 前不可用';
  }

  @override
  String get statusDisabled => '已停用';

  @override
  String get statusEnabled => '已启用';

  @override
  String get useNow => '立即使用';

  @override
  String get signInAgain => '重新登录';

  @override
  String reasonQuotaThreshold(int percent) {
    return '此账户已用掉 $percent% 的流量，已切换到下一个账户。';
  }

  @override
  String get reasonQuotaExhausted => '本月流量已用完；每月重置后会再次使用。';

  @override
  String get reasonSignInRequired => '请重新登录以使用此账户。';

  @override
  String get reasonSignInConfirm => 'Mozilla 要求确认登录：请点“重新登录”（只需验证码）。';

  @override
  String reasonSignInFailed(String detail) {
    return '自动登录失败（$detail）。请重新登录。';
  }

  @override
  String reasonSignInWait(String time) {
    return '上次自动登录后不久就失效了；下次尝试时间为 $time。';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return '自动登录未能完成（$detail）；将在 $time 重试。';
  }

  @override
  String get reasonNotEntitled => 'Mozilla 拒绝了此账户；稍后会重试。';

  @override
  String get more => '更多';

  @override
  String get refreshQuota => '刷新流量';

  @override
  String get remove => '删除';

  @override
  String get removeTitle => '删除账户？';

  @override
  String removeBody(String name) {
    return '$name 及其保存的登录信息将从这台电脑上删除。之后可以重新添加。';
  }

  @override
  String get unlimitedQuota => '不限流量';

  @override
  String get signInTitle => '登录';

  @override
  String get signInIntro => '使用 Firefox 账户登录。';

  @override
  String get email => '邮箱';

  @override
  String get emailInvalid => '请输入账户邮箱';

  @override
  String get password => '密码';

  @override
  String get passwordEmpty => '请输入密码';

  @override
  String get show => '显示';

  @override
  String get hide => '隐藏';

  @override
  String get signIn => '登录';

  @override
  String get continueLabel => '继续';

  @override
  String get done => '完成';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get tryAgain => '重试';

  @override
  String get signingIn => '正在登录…';

  @override
  String get accountReady => '账户已就绪';

  @override
  String get accountReadyHint => '已添加到账户列表末尾。';

  @override
  String get captchaLabel => '图片中的字符';

  @override
  String get codeLabel => '验证码';

  @override
  String get captchaBroken => '无法显示验证码图片。';

  @override
  String stepEmailCode(String email) {
    return 'Mozilla 已向 $email 发送验证码，请在此输入。';
  }

  @override
  String get stepTotp => '请输入身份验证器应用中的验证码。';

  @override
  String stepUnblockCode(String email) {
    return 'Mozilla 检测到此次登录异常，已向 $email 发送解锁码，请在此输入。';
  }

  @override
  String get stepCaptcha => '请输入图片中的字符。';

  @override
  String stepEmailLink(String email) {
    return '请打开 Mozilla 发送到 $email 的确认链接，确认后将自动继续。';
  }

  @override
  String get signInFailed => '未能添加账户。';

  @override
  String get signInCancelled => '登录已取消。';

  @override
  String get signInNoAccount => '此邮箱没有 Firefox 账户。';

  @override
  String get signInNoAccountHint =>
      '请检查邮箱地址，或用它在 Mozilla 网站免费创建一个 Firefox 账户，在邮箱中确认后再在此添加。';

  @override
  String get createAccountButton => '创建 Firefox 账户';

  @override
  String get signInWrongPassword => '密码错误。';

  @override
  String get signInNoPassword =>
      '此账户没有密码：它是通过 Google 或 Apple 登录创建的。请先设置密码，然后在此用该密码登录。';

  @override
  String get setPasswordButton => '设置密码';

  @override
  String get signInTooManyAttempts => '尝试次数过多。请稍候再试。';

  @override
  String get signInUnblockRejected => '解锁码未被接受。请使用 Mozilla 最新邮件中的验证码。';

  @override
  String get signInWrongCode =>
      '验证码错误或已过期。请使用 Mozilla 最新邮件中的验证码；发送新验证码后，旧的即失效。';

  @override
  String get signInWrongTotp => '验证码错误。请输入身份验证器应用当前显示的验证码。';

  @override
  String get signInTooManyCodes => '错误的验证码过多。请重新开始登录。';

  @override
  String get signInTimedOut => '登录耗时过长。请重新开始。';

  @override
  String get signInNetwork => '无法连接 Mozilla。请检查网络后重试。';

  @override
  String get coreConnecting => '正在连接核心…';

  @override
  String get coreLost => '与核心的连接已断开，正在重试…';

  @override
  String get cantReachCore => '无法连接到核心';

  @override
  String get startingCore => '正在启动核心…';

  @override
  String get retry => '重试';

  @override
  String errNoCore(String path) {
    return '在应用旁边找不到核心程序（$path）。';
  }

  @override
  String errCoreExited(String detail) {
    return '核心已停止：$detail';
  }

  @override
  String get errNotAnswering => '核心没有响应。';

  @override
  String get errRefused => '核心拒绝了本应用的连接，它可能属于另一个正在运行的副本。';

  @override
  String get settingsTitle => '设置';

  @override
  String get sectionGeneral => '常规';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get closeBehavior => '关闭窗口时';

  @override
  String get closeAsk => '每次询问';

  @override
  String get closeTray => '最小化到托盘';

  @override
  String get closeQuit => '退出应用';

  @override
  String get sectionConnection => '连接';

  @override
  String get localProxy => '本地代理';

  @override
  String get systemProxy => '系统代理';

  @override
  String get sectionRouting => '分流';

  @override
  String get routingDirect => '本地网站直连';

  @override
  String get routingDirectHint => '所选国家的网站和 IP 不走 VPN，打开更快，也节省流量。';

  @override
  String get region => '国家';

  @override
  String get regionIr => '伊朗';

  @override
  String get regionCn => '中国';

  @override
  String get regionRu => '俄罗斯';

  @override
  String get regionAf => '阿富汗';

  @override
  String get regionTr => '土耳其';

  @override
  String get regionId => '印度尼西亚';

  @override
  String get regionBr => '巴西';

  @override
  String get regionNone => '无';

  @override
  String get saved => '已保存';

  @override
  String get dataFolder => '数据文件夹';

  @override
  String get openFolder => '打开文件夹';

  @override
  String get unofficialNote => '非官方客户端，与 Mozilla 无关。';

  @override
  String get closeTitle => '关闭窗口？';

  @override
  String get closeBody => '最小化到托盘后 VPN 保持连接；退出则会断开。';

  @override
  String get rememberChoice => '记住我的选择';

  @override
  String get minimizeToTray => '最小化到托盘';

  @override
  String get quit => '退出';

  @override
  String get trayOpen => '打开';

  @override
  String get trayQuit => '退出';

  @override
  String get trayProxyOnly => '仅代理服务';

  @override
  String get traySetSystemProxy => '设置系统代理';

  @override
  String errPortInUse(String port) {
    return '端口 $port 被其他程序占用，应用无法连接到核心。';
  }

  @override
  String proxyPortInUse(String port) {
    return '端口 $port 被其他程序占用，代理无法启动。';
  }

  @override
  String get changePort => '更改端口';

  @override
  String get portDialogTitle => '选择端口';

  @override
  String portDialogBody(String port) {
    return '端口 $port 已被占用。下方已推荐一个空闲端口，你也可以输入其他端口。';
  }

  @override
  String get portChangeBody => '其他应用通过此端口连接。请选择 1024 到 65535 之间的端口。';

  @override
  String get portLabel => '端口';

  @override
  String get portInvalid => '请输入 1024 到 65535 之间的端口';

  @override
  String get portBusy => '此端口也已被占用';

  @override
  String get portInUse => '其他程序正在使用此端口';

  @override
  String get save => '保存';

  @override
  String get proxyPort => '代理端口';

  @override
  String get appPort => '应用端口';

  @override
  String get welcomeTitle => '欢迎';

  @override
  String get welcomeBody => '请选择语言和所在国家。本国网站将直连访问，不走 VPN，速度更快，也节省流量。';

  @override
  String get start => '开始';

  @override
  String routingSuggestTitle(String country) {
    return '$country网站直连？';
  }

  @override
  String routingSuggestBody(String country) {
    return '$country的网站和 IP 将直连访问，不走 VPN。可在“分流”中更改。';
  }

  @override
  String get yes => '是';

  @override
  String get notNow => '暂不';

  @override
  String get navServers => '服务器';

  @override
  String get navLogs => '日志';

  @override
  String get realDelay => '真实延迟';

  @override
  String noticePort(String port) {
    return 'Mozilla 代理不支持端口 $port，只有 80、443、8080 和 8443 端口可以走 VPN。';
  }

  @override
  String get noticeCommand =>
      '有应用使用了 UDP（游戏、语音和视频通话等）。Mozilla 代理仅支持 TCP，因此无法通过。';

  @override
  String noticeTimes(int count, String time) {
    return '$count 次，最近一次 $time';
  }

  @override
  String get dismiss => '忽略';

  @override
  String get modeRecommended => '推荐';

  @override
  String get modeFastest => '最快';

  @override
  String get modeRecommendedHint => '由 Mozilla 为你选择节点。';

  @override
  String get modeFastestHint => '每次连接时自动选择延迟最低的节点。';

  @override
  String get testDelay => '测试真实延迟';

  @override
  String get testingDelay => '正在测试…可能需要一分钟';

  @override
  String get search => '搜索';

  @override
  String get noAnswer => '无响应';

  @override
  String testedAgo(String ago) {
    return '$ago测试';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$answered/$total 个节点有响应';
  }

  @override
  String get noServers => '暂无服务器。核心连接到 Mozilla 后即会显示。';

  @override
  String get levelAll => '全部';

  @override
  String get filter => '筛选';

  @override
  String get follow => '自动滚动';

  @override
  String get clear => '清空';

  @override
  String get copyAll => '复制';

  @override
  String get logsCopied => '日志已复制';

  @override
  String get noLogs => '暂无日志。';

  @override
  String get sectionAccounts => '自动切换账户';

  @override
  String get switchThreshold => '切换阈值';

  @override
  String get switchThresholdHint => '流量用到此比例时，自动切换到下一个账户。';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'DNS 服务器';

  @override
  String get dnsSystem => '系统';

  @override
  String get dnsAuto => '自动（Cloudflare、Google、Quad9）';

  @override
  String get dnsCustom => '自定义';

  @override
  String get dnsCustomHint => '每行一个：https://…/dns-query、tls://… 或 IP 地址。';

  @override
  String get dnsFallback => '回退到系统 DNS';

  @override
  String get testDns => '测试 DNS';

  @override
  String get transport => '协议';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => '直连';

  @override
  String get directRulesHint =>
      '此列表中的网站和地址不经过 VPN，直接通过你自己的网络打开。所选国家的规则已在此处：可以添加、修改或删除。选择其他国家会替换为该国的规则。';

  @override
  String get restoreRegionRules => '恢复该国家的默认规则';

  @override
  String get blockRules => '拦截';

  @override
  String get blockRulesHint =>
      '此列表中的网站和地址完全无法打开，无论直连还是通过 VPN：适用于广告或你永远不想访问的网站。';

  @override
  String get rulesTitle => '规则';

  @override
  String get ruleSyntaxTitle => '如何编写规则';

  @override
  String get resolveDomains => 'IP 规则也应用于域名';

  @override
  String get routingLists => 'Geo 文件';

  @override
  String get listSource => '列表来源';

  @override
  String get listSourceCustom => '手动设置';

  @override
  String listsUpdatedAgo(String ago) {
    return '更新于 $ago';
  }

  @override
  String get updateLists => '更新 Geo 文件';

  @override
  String get listsUpdated => 'Geo 文件已更新。';

  @override
  String get testDestination => '测试分流';

  @override
  String get destinationHint => '域名、IP 或网址';

  @override
  String get check => '检查';

  @override
  String get routeDirect => '直连';

  @override
  String get routeProxy => '走 VPN';

  @override
  String get routeBlock => '已拦截';

  @override
  String ruleMatched(String rule) {
    return '规则：$rule';
  }

  @override
  String get portRefusedNote => 'Mozilla 代理不支持此端口。';

  @override
  String get sectionAdvanced => '高级';

  @override
  String get listenAddress => '允许连接的设备';

  @override
  String get listenLocal => '127.0.0.1 · 仅本设备';

  @override
  String get listenAll => '0.0.0.0 · 所有网络（LAN）';

  @override
  String get proxyUsername => '代理用户名';

  @override
  String get proxyPassword => '代理密码';

  @override
  String get proxyLoginHint => '应用连接代理时需填写这些信息。两项都留空则无需验证。';

  @override
  String get loginBothOrNone => '请同时填写两项，或都留空。';

  @override
  String get proxyLogin => '代理认证';

  @override
  String get idleSleep => '空闲后休眠';

  @override
  String get sleepNever => '从不';

  @override
  String sleepMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get sleepHour => '1 小时';

  @override
  String get showPublicIp => '显示公网 IP';

  @override
  String get speedInNotification => '在通知中显示速度';

  @override
  String get liveTraffic => '实时流量';

  @override
  String get totalTraffic => '总流量';

  @override
  String get verboseLogs => '详细日志';

  @override
  String get webDashboard => '网页控制面板';

  @override
  String get webDashboardOpen => '打开';

  @override
  String get webDashboardHint => '高级设置和更多工具';

  @override
  String numberInvalid(int min, int max) {
    return '请输入 $min 到 $max 之间的数字';
  }

  @override
  String get notifySwitchedTitle => '已切换账户';

  @override
  String notifySwitchedBody(String name) {
    return '现在使用 $name。';
  }

  @override
  String get notifySignInTitle => '需要登录';

  @override
  String get notifySignInBody => '有账户需要在“账户”页面重新登录。';

  @override
  String get navAbout => '关于';

  @override
  String get appVersionLabel => '应用版本';

  @override
  String get coreVersionLabel => '核心版本';

  @override
  String get checkUpdates => '检查更新';

  @override
  String get checkingUpdates => '正在检查…';

  @override
  String get upToDate => '已是最新版本。';

  @override
  String updateAvailable(String version) {
    return '新版本 $version 已发布。';
  }

  @override
  String get download => '下载';

  @override
  String updateCheckFailed(String error) {
    return '无法检查更新：$error';
  }

  @override
  String get repoNotSet => '尚未设置 GitHub 仓库。';

  @override
  String get sourceCode => '源代码';

  @override
  String get tapToConnect => '点击连接';

  @override
  String get tapToDisconnect => '点击断开';

  @override
  String get startOnBoot => '开机启动';

  @override
  String get connectOnStartup => '开机自动连接';

  @override
  String get proxyServiceActive => '代理服务运行中';

  @override
  String get navHome => '首页';

  @override
  String get groupApp => '应用';

  @override
  String get stateOff => '已断开';

  @override
  String get tapToConnectPhone => '点击连接';

  @override
  String get tapToDisconnectPhone => '点击断开';

  @override
  String lanAddress(String address) {
    return '局域网 $address';
  }

  @override
  String get recommendedLocation => '推荐节点';

  @override
  String dataLeftOf(String limit) {
    return '共 $limit';
  }

  @override
  String get homeLocation => '节点';

  @override
  String get connectedTo => '已连接到';

  @override
  String get vpnNotAllowed => 'VPN 需要你的授权。请再次点击按钮并允许。';

  @override
  String get dataUsedTitle => '已用流量';

  @override
  String get bypassApps => '分应用代理';

  @override
  String get connectRetrying => '无法连接。请检查网络。';

  @override
  String get failUnreachable => 'Mozilla 服务器在此网络上被屏蔽。请换一个网络连接试试。';

  @override
  String get failRefused => 'Mozilla 服务器拒绝了连接。请几分钟后再试。';

  @override
  String get failLocationRefused => '这个国家不对你的账户开放。请选择其他国家。';

  @override
  String get useRecommendedLocation => '使用推荐节点';

  @override
  String exitMismatch(String exit, String chosen) {
    return '你选择了$chosen，但你的 IP 在$exit。';
  }

  @override
  String get failSignIn => '此账户的登录已过期。请在“账户”页重新登录。';

  @override
  String get failQuota => '本月流量已用完。请添加另一个账户。';

  @override
  String get failNotEntitled => 'Mozilla 不允许此账户使用 VPN。请添加另一个账户。';

  @override
  String get failRegion => 'Mozilla 不在你所在的国家提供服务。';

  @override
  String get failServer => 'Mozilla 服务暂时出现问题。应用会自动重试。';

  @override
  String get failNoAccount => '没有可用的账户。请打开“账户”页。';

  @override
  String get failTestSite => '已连接服务器，但网站打不开。请换一个国家试试。';

  @override
  String get failOther => '无法连接。请重试。';

  @override
  String get failNoInternet => '无网络连接。请检查 Wi-Fi 或移动数据。';

  @override
  String get waitingForNetwork => '正在等待网络连接…';

  @override
  String proxyStartFailed(String port) {
    return '代理无法在端口 $port 上启动。请选择其他端口。';
  }

  @override
  String get connectionSettings => '连接设置';

  @override
  String get appModeExclude => '绕行所选应用';

  @override
  String get appModeInclude => '仅代理所选应用';

  @override
  String get appModeExcludeHint => '所选应用直连，不走 VPN，例如拒绝境外 IP 的银行应用。';

  @override
  String get appModeIncludeHint => '仅所选应用走 VPN，其他应用直连。';

  @override
  String fromRegionList(String region) {
    return '推荐（$region列表）';
  }

  @override
  String get modeProxy => '代理';

  @override
  String get connectionMode => '连接模式';

  @override
  String get modeProxyHint => '仅对已设置代理的应用生效，不更改 Windows 设置。';

  @override
  String get modeSystemProxyHint => 'Windows 和大多数应用都走代理。';

  @override
  String get modeProxyHintOther => '仅对已设置代理的应用生效，不更改系统设置。';

  @override
  String get modeSystemProxyHintOther => '浏览器和大多数应用都走代理。';

  @override
  String get suggestedApps => '推荐应用';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选中 $count 个推荐应用',
      zero: '推荐应用已全部选中',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => '自动';

  @override
  String get locationsSection => '节点';

  @override
  String get dnsSummaryOk => '加密 DNS 工作正常';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个域名解析失败',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return '经由 $server';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '当前网络的 DNS 对 $count 个域名返回了过滤地址，本应用不会采用这些结果。',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => '结果：';

  @override
  String get dnsNetworkAnswer => '网络 DNS：';

  @override
  String get dnsFiltered => '被过滤';

  @override
  String get rulesSyntaxTitle => '每行一条规则';

  @override
  String get ruleDomain => '该网站及其子域名';

  @override
  String get ruleFull => '仅匹配此域名';

  @override
  String get ruleKeyword => '包含此关键词的域名';

  @override
  String get ruleGeosite => 'Geo 文件中指定标签的网站';

  @override
  String get ruleGeoip => 'Geo 文件中指定国家的 IP';

  @override
  String get ruleIp => '单个 IP 或网段';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => '仅代理';

  @override
  String get noNetwork => '无网络连接。请打开 Wi-Fi 或移动数据。';

  @override
  String get blockAds => '拦截广告';

  @override
  String systemProxyTakenBy(String address) {
    return '另一个程序将系统代理改为 $address，流量不再经过 VPN。';
  }

  @override
  String get systemProxyTakenOff => '另一个程序关闭了系统代理，流量不再经过 VPN。';

  @override
  String get setSystemProxyAgain => '重新设置';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'Firefox VPN';

  @override
  String get navOverview => '總覽';

  @override
  String get navAccounts => '帳號';

  @override
  String get navSettings => '設定';

  @override
  String get stateConnected => '已連線';

  @override
  String get stateConnecting => '正在連線…';

  @override
  String get stateWaiting => '等待中';

  @override
  String get waitingForAccount => '請在「帳號」頁面新增 Firefox Account 以連線。';

  @override
  String get waitingForEnabledAccount => '所有帳號都已關閉。請在「帳號」頁面啟用一個。';

  @override
  String get stateError => '錯誤';

  @override
  String get stateUnknown => '未知';

  @override
  String get restartProxy => '重新啟動代理';

  @override
  String copied(String value) {
    return '已複製 $value';
  }

  @override
  String get activeAccount => '目前帳號';

  @override
  String get noActiveAccount => '沒有使用中的帳號';

  @override
  String get quotaNotRead => '尚未取得流量資訊';

  @override
  String get unlimited => '無限制';

  @override
  String usedOf(String used, String limit) {
    return '已用 $used / $limit';
  }

  @override
  String resets(String date) {
    return '$date 重新計算';
  }

  @override
  String switchAt(int percent) {
    return '達到 $percent% 時切換帳號';
  }

  @override
  String get publicIp => '公用 IP';

  @override
  String get testConnection => '測試連線';

  @override
  String get testing => '正在測試…';

  @override
  String get testFailed => '失敗';

  @override
  String milliseconds(int value) {
    return '$value 毫秒';
  }

  @override
  String get justNow => '剛剛';

  @override
  String minutesAgo(int n) {
    return '$n 分鐘前';
  }

  @override
  String hoursAgo(int n) {
    return '$n 小時前';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String atTime(String time) {
    return '於 $time';
  }

  @override
  String durationDays(int d, int h) {
    return '$d 天 $h 小時';
  }

  @override
  String durationHours(int h, int m) {
    return '$h 小時 $m 分';
  }

  @override
  String durationMinutes(int m, int s) {
    return '$m 分 $s 秒';
  }

  @override
  String durationSeconds(int s) {
    return '$s 秒';
  }

  @override
  String accountsGuide(String size) {
    return '每個 Firefox 帳號每月有 $size 流量。你可以新增多個帳號：一個用完後，應用程式會自動切換到下一個。';
  }

  @override
  String accountsOrderNote(int percent) {
    return '依此清單順序使用：每個帳戶用到 $percent%，最後一個用到流量用完。';
  }

  @override
  String get addAccount => '新增帳號';

  @override
  String lowQuotaNotice(String left, String size) {
    return '目前帳號的流量快用完了（剩餘 $left）。再新增一個帳號，可再獲得 $size。';
  }

  @override
  String get noAccounts => '尚無帳號';

  @override
  String get noAccountsHint => '新增一個 Firefox Account 以連線。';

  @override
  String get createAccountTitle => '還沒有 Firefox Account？';

  @override
  String get createAccountHint => '可在 accounts.firefox.com 免費註冊，再回來點選「新增帳號」。';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get statusActive => '使用中';

  @override
  String get statusReady => '可用';

  @override
  String get statusNeedsSignIn => '需要登入';

  @override
  String get statusReserved => '已保留';

  @override
  String get statusUnavailable => '無法使用';

  @override
  String statusUnavailableUntil(String date) {
    return '$date 前無法使用';
  }

  @override
  String get statusDisabled => '已停用';

  @override
  String get statusEnabled => '已啟用';

  @override
  String get useNow => '立即使用';

  @override
  String get signInAgain => '重新登入';

  @override
  String reasonQuotaThreshold(int percent) {
    return '此帳號已用掉 $percent% 的流量，已切換到下一個帳號。';
  }

  @override
  String get reasonQuotaExhausted => '本月流量已用完；每月重設後會再次使用。';

  @override
  String get reasonSignInRequired => '請重新登入以使用此帳號。';

  @override
  String get reasonSignInConfirm => 'Mozilla 要求確認登入：請按「重新登入」（只需驗證碼）。';

  @override
  String reasonSignInFailed(String detail) {
    return '自動登入失敗（$detail）。請重新登入。';
  }

  @override
  String reasonSignInWait(String time) {
    return '上次自動登入後不久就失效了；下次嘗試時間為 $time。';
  }

  @override
  String reasonSignInRetry(String detail, String time) {
    return '自動登入未能完成（$detail）；將在 $time 重試。';
  }

  @override
  String get reasonNotEntitled => 'Mozilla 拒絕了此帳號；稍後會重試。';

  @override
  String get more => '更多';

  @override
  String get refreshQuota => '重新整理流量';

  @override
  String get remove => '移除';

  @override
  String get removeTitle => '要移除帳號嗎？';

  @override
  String removeBody(String name) {
    return '$name 及其儲存的登入資訊將從這台電腦上移除。之後可以重新新增。';
  }

  @override
  String get unlimitedQuota => '無限流量';

  @override
  String get signInTitle => '登入';

  @override
  String get signInIntro => '使用 Firefox Account 登入。';

  @override
  String get email => '電子郵件';

  @override
  String get emailInvalid => '請輸入帳號的電子郵件';

  @override
  String get password => '密碼';

  @override
  String get passwordEmpty => '請輸入密碼';

  @override
  String get show => '顯示';

  @override
  String get hide => '隱藏';

  @override
  String get signIn => '登入';

  @override
  String get continueLabel => '繼續';

  @override
  String get done => '完成';

  @override
  String get close => '關閉';

  @override
  String get cancel => '取消';

  @override
  String get tryAgain => '再試一次';

  @override
  String get signingIn => '正在登入…';

  @override
  String get accountReady => '帳號已就緒';

  @override
  String get accountReadyHint => '已排在帳號清單的最後。';

  @override
  String get captchaLabel => '圖片中的字元';

  @override
  String get codeLabel => '驗證碼';

  @override
  String get captchaBroken => '無法顯示 CAPTCHA 圖片。';

  @override
  String stepEmailCode(String email) {
    return 'Mozilla 已將驗證碼寄到 $email，請在此輸入。';
  }

  @override
  String get stepTotp => '請輸入驗證器應用程式中的驗證碼。';

  @override
  String stepUnblockCode(String email) {
    return 'Mozilla 認為這次登入異常，已將解除封鎖碼寄到 $email，請在此輸入。';
  }

  @override
  String get stepCaptcha => '請輸入圖片中的字元。';

  @override
  String stepEmailLink(String email) {
    return '請開啟 Mozilla 寄到 $email 的確認連結，之後會自動繼續。';
  }

  @override
  String get signInFailed => '未能新增帳號。';

  @override
  String get signInCancelled => '已取消登入。';

  @override
  String get signInNoAccount => '此電子郵件沒有 Firefox Account。';

  @override
  String get signInNoAccountHint =>
      '請檢查電子郵件地址，或用它在 Mozilla 網站免費建立 Firefox Account，從信箱確認後再在此新增。';

  @override
  String get createAccountButton => '建立 Firefox Account';

  @override
  String get signInWrongPassword => '密碼錯誤。';

  @override
  String get signInNoPassword =>
      '此帳號沒有密碼：它是透過 Google 或 Apple 登入建立的。請先設定密碼，再於此用該密碼登入。';

  @override
  String get setPasswordButton => '設定密碼';

  @override
  String get signInTooManyAttempts => '嘗試次數過多。請稍候再試。';

  @override
  String get signInUnblockRejected => '解除封鎖碼未被接受。請使用 Mozilla 最新郵件中的代碼。';

  @override
  String get signInWrongCode =>
      '驗證碼錯誤或已過期。請使用 Mozilla 最新郵件中的驗證碼；寄出新驗證碼後，舊的即失效。';

  @override
  String get signInWrongTotp => '驗證碼錯誤。請輸入驗證器應用程式目前顯示的驗證碼。';

  @override
  String get signInTooManyCodes => '錯誤的驗證碼過多。請重新開始登入。';

  @override
  String get signInTimedOut => '登入耗時過長。請重新開始。';

  @override
  String get signInNetwork => '無法連線到 Mozilla。請檢查網路後再試。';

  @override
  String get coreConnecting => '正在連線到核心…';

  @override
  String get coreLost => '與核心的連線已中斷，正在重試…';

  @override
  String get cantReachCore => '無法連線到核心';

  @override
  String get startingCore => '正在啟動核心…';

  @override
  String get retry => '重試';

  @override
  String errNoCore(String path) {
    return '在應用程式旁找不到核心程式（$path）。';
  }

  @override
  String errCoreExited(String detail) {
    return '核心已停止：$detail';
  }

  @override
  String get errNotAnswering => '核心沒有回應。';

  @override
  String get errRefused => '核心拒絕連線，可能屬於另一個正在執行的副本。';

  @override
  String get settingsTitle => '設定';

  @override
  String get sectionGeneral => '一般';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '系統預設';

  @override
  String get theme => '主題';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get closeBehavior => '關閉視窗時';

  @override
  String get closeAsk => '每次詢問';

  @override
  String get closeTray => '最小化到系統匣';

  @override
  String get closeQuit => '結束應用程式';

  @override
  String get sectionConnection => '連線';

  @override
  String get localProxy => '本機代理';

  @override
  String get systemProxy => '系統代理';

  @override
  String get sectionRouting => '分流';

  @override
  String get routingDirect => '本地網站直接連線';

  @override
  String get routingDirectHint => '所選國家的網站和 IP 不經過 VPN，開啟更快，也更省流量。';

  @override
  String get region => '國家';

  @override
  String get regionIr => '伊朗';

  @override
  String get regionCn => '中國';

  @override
  String get regionRu => '俄羅斯';

  @override
  String get regionAf => '阿富汗';

  @override
  String get regionTr => '土耳其';

  @override
  String get regionId => '印尼';

  @override
  String get regionBr => '巴西';

  @override
  String get regionNone => '無';

  @override
  String get saved => '已儲存';

  @override
  String get dataFolder => '資料儲存位置';

  @override
  String get openFolder => '開啟資料夾';

  @override
  String get unofficialNote => '非官方用戶端，與 Mozilla 無關。';

  @override
  String get closeTitle => '要關閉視窗嗎？';

  @override
  String get closeBody => '最小化到系統匣時，VPN 會保持連線；結束則會中斷連線。';

  @override
  String get rememberChoice => '記住我的選擇';

  @override
  String get minimizeToTray => '最小化到系統匣';

  @override
  String get quit => '結束';

  @override
  String get trayOpen => '開啟';

  @override
  String get trayQuit => '結束';

  @override
  String get trayProxyOnly => '僅代理服務';

  @override
  String get traySetSystemProxy => '設定系統代理';

  @override
  String errPortInUse(String port) {
    return '連接埠 $port 已被其他程式使用，應用程式無法連線到核心。';
  }

  @override
  String proxyPortInUse(String port) {
    return '連接埠 $port 已被其他程式使用，代理無法啟動。';
  }

  @override
  String get changePort => '變更連接埠';

  @override
  String get portDialogTitle => '選擇連接埠';

  @override
  String portDialogBody(String port) {
    return '連接埠 $port 已被佔用。下方已建議一個可用的連接埠，您也可以輸入其他連接埠。';
  }

  @override
  String get portChangeBody => '應用程式會連線到此連接埠。請選擇 1024 到 65535 之間的連接埠。';

  @override
  String get portLabel => '連接埠';

  @override
  String get portInvalid => '請輸入 1024 到 65535 之間的連接埠';

  @override
  String get portBusy => '這個連接埠也在使用中';

  @override
  String get portInUse => '其他程式正在使用此連接埠';

  @override
  String get save => '儲存';

  @override
  String get proxyPort => '代理連接埠';

  @override
  String get appPort => '應用程式連接埠';

  @override
  String get welcomeTitle => '歡迎';

  @override
  String get welcomeBody => '請選擇語言和國家。您所在國家的網站會直接開啟，不經過 VPN，速度更快，也更省流量。';

  @override
  String get start => '開始';

  @override
  String routingSuggestTitle(String country) {
    return '$country網站直接連線？';
  }

  @override
  String routingSuggestBody(String country) {
    return '$country的網站和 IP 將直接開啟，不經過 VPN。您可以在「分流」中變更。';
  }

  @override
  String get yes => '是';

  @override
  String get notNow => '暫時不要';

  @override
  String get navServers => '伺服器';

  @override
  String get navLogs => '記錄';

  @override
  String get realDelay => '真實延遲';

  @override
  String noticePort(String port) {
    return 'Mozilla 的代理不會連線到連接埠 $port。只有 80、443、8080 和 8443 連接埠會經過 VPN。';
  }

  @override
  String get noticeCommand =>
      '有應用程式要求使用 UDP（遊戲、語音和視訊通話）。Mozilla 的代理只傳輸 TCP，因此無法通過。';

  @override
  String noticeTimes(int count, String time) {
    return '$count 次，最近一次 $time';
  }

  @override
  String get dismiss => '知道了';

  @override
  String get modeRecommended => '推薦';

  @override
  String get modeFastest => '最快';

  @override
  String get modeRecommendedHint => '由 Mozilla 為您選擇位置。';

  @override
  String get modeFastestHint => '每次連線時自動選擇延遲最低的位置。';

  @override
  String get testDelay => '測試真實延遲';

  @override
  String get testingDelay => '正在測試…可能需要一分鐘';

  @override
  String get search => '搜尋';

  @override
  String get noAnswer => '無回應';

  @override
  String testedAgo(String ago) {
    return '測試於 $ago';
  }

  @override
  String delaySummary(int answered, int total) {
    return '$total 個中有 $answered 個回應';
  }

  @override
  String get noServers => '尚無伺服器。核心連上 Mozilla 後就會顯示。';

  @override
  String get levelAll => '全部';

  @override
  String get filter => '篩選';

  @override
  String get follow => '自動捲動';

  @override
  String get clear => '清除';

  @override
  String get copyAll => '複製';

  @override
  String get logsCopied => '記錄已複製';

  @override
  String get noLogs => '尚無記錄。';

  @override
  String get sectionAccounts => '自動切換帳號';

  @override
  String get switchThreshold => '切換帳號門檻';

  @override
  String get switchThresholdHint => '流量用到此比例時，自動換下一個帳號。';

  @override
  String get sectionDns => 'DNS';

  @override
  String get dnsPreset => 'DNS 伺服器';

  @override
  String get dnsSystem => '系統';

  @override
  String get dnsAuto => '自動（Cloudflare、Google、Quad9）';

  @override
  String get dnsCustom => '自訂';

  @override
  String get dnsCustomHint => '每行一個：https://…/dns-query、tls://… 或 IP 位址。';

  @override
  String get dnsFallback => '失敗時改用系統 DNS';

  @override
  String get testDns => '測試 DNS';

  @override
  String get transport => '通訊協定';

  @override
  String get transportH3 => 'HTTP/3 (QUIC)';

  @override
  String get transportH2 => 'HTTP/2 (TCP)';

  @override
  String get directRules => '直接連線';

  @override
  String get directRulesHint =>
      '此清單中的網站和位址不經過 VPN，直接透過你自己的網路開啟。所選國家的規則已在此處：可以新增、修改或刪除。選擇其他國家會換成該國的規則。';

  @override
  String get restoreRegionRules => '還原該地區的規則';

  @override
  String get blockRules => '封鎖';

  @override
  String get blockRulesHint => '此清單中的網站和位址完全無法開啟，無論直連或透過 VPN：適用於廣告或你永遠不想連上的網站。';

  @override
  String get rulesTitle => '規則';

  @override
  String get ruleSyntaxTitle => '如何撰寫規則';

  @override
  String get resolveDomains => 'IP 規則也套用於網域';

  @override
  String get routingLists => 'Geo 檔案';

  @override
  String get listSource => '清單來源';

  @override
  String get listSourceCustom => '手動設定';

  @override
  String listsUpdatedAgo(String ago) {
    return '更新於 $ago';
  }

  @override
  String get updateLists => '更新 Geo 檔案';

  @override
  String get listsUpdated => 'Geo 檔案已更新。';

  @override
  String get testDestination => '測試路由';

  @override
  String get destinationHint => '網域、IP 或網址';

  @override
  String get check => '檢查';

  @override
  String get routeDirect => '直接連線';

  @override
  String get routeProxy => '經過 VPN';

  @override
  String get routeBlock => '已封鎖';

  @override
  String ruleMatched(String rule) {
    return '規則：$rule';
  }

  @override
  String get portRefusedNote => 'Mozilla 的代理不會連線到此連接埠。';

  @override
  String get sectionAdvanced => '進階';

  @override
  String get listenAddress => '允許連線的裝置';

  @override
  String get listenLocal => '127.0.0.1 · 僅本裝置';

  @override
  String get listenAll => '0.0.0.0 · 所有網路（LAN）';

  @override
  String get proxyUsername => '代理使用者名稱';

  @override
  String get proxyPassword => '代理密碼';

  @override
  String get proxyLoginHint => '應用程式需使用這組帳密連線到代理。兩者都留空則不需驗證。';

  @override
  String get loginBothOrNone => '請同時填寫兩項，或都留空。';

  @override
  String get proxyLogin => '代理驗證';

  @override
  String get idleSleep => '閒置多久後休眠';

  @override
  String get sleepNever => '從不';

  @override
  String sleepMinutes(int count) {
    return '$count 分鐘';
  }

  @override
  String get sleepHour => '1 小時';

  @override
  String get showPublicIp => '顯示公用 IP';

  @override
  String get speedInNotification => '在通知中顯示速度';

  @override
  String get liveTraffic => '即時流量';

  @override
  String get totalTraffic => '總流量';

  @override
  String get verboseLogs => '詳細記錄';

  @override
  String get webDashboard => '網頁控制台';

  @override
  String get webDashboardOpen => '開啟';

  @override
  String get webDashboardHint => '進階設定和更多工具';

  @override
  String numberInvalid(int min, int max) {
    return '請輸入 $min 到 $max 之間的數字';
  }

  @override
  String get notifySwitchedTitle => '已切換帳號';

  @override
  String notifySwitchedBody(String name) {
    return '現在使用 $name。';
  }

  @override
  String get notifySignInTitle => '需要登入';

  @override
  String get notifySignInBody => '有帳號需要在「帳號」頁面重新登入。';

  @override
  String get navAbout => '關於';

  @override
  String get appVersionLabel => '應用程式版本';

  @override
  String get coreVersionLabel => '核心版本';

  @override
  String get checkUpdates => '檢查更新';

  @override
  String get checkingUpdates => '正在檢查…';

  @override
  String get upToDate => '已是最新版本。';

  @override
  String updateAvailable(String version) {
    return '已有新版本 $version。';
  }

  @override
  String get download => '下載';

  @override
  String updateCheckFailed(String error) {
    return '無法檢查更新：$error';
  }

  @override
  String get repoNotSet => '尚未設定 GitHub 儲存庫。';

  @override
  String get sourceCode => '原始碼';

  @override
  String get tapToConnect => '按一下以連線';

  @override
  String get tapToDisconnect => '按一下以中斷連線';

  @override
  String get startOnBoot => '開機啟動';

  @override
  String get connectOnStartup => '開機自動連線';

  @override
  String get proxyServiceActive => '代理服務執行中';

  @override
  String get navHome => '首頁';

  @override
  String get groupApp => '應用程式';

  @override
  String get stateOff => '未連線';

  @override
  String get tapToConnectPhone => '輕觸以連線';

  @override
  String get tapToDisconnectPhone => '輕觸以中斷連線';

  @override
  String lanAddress(String address) {
    return 'LAN $address';
  }

  @override
  String get recommendedLocation => '推薦位置';

  @override
  String dataLeftOf(String limit) {
    return '共 $limit';
  }

  @override
  String get homeLocation => '位置';

  @override
  String get connectedTo => '已連線到';

  @override
  String get vpnNotAllowed => 'VPN 需要您的許可。請再次輕觸按鈕並允許。';

  @override
  String get dataUsedTitle => '已用流量';

  @override
  String get bypassApps => '個別應用程式代理';

  @override
  String get connectRetrying => '無法連線。請檢查網路。';

  @override
  String get failUnreachable => 'Mozilla 伺服器在此網路上遭封鎖。請改用其他網路連線。';

  @override
  String get failRefused => 'Mozilla 伺服器拒絕了連線。請幾分鐘後再試。';

  @override
  String get failLocationRefused => '這個國家未對您的帳號開放。請選擇其他國家。';

  @override
  String get useRecommendedLocation => '使用推薦位置';

  @override
  String exitMismatch(String exit, String chosen) {
    return '您選擇了$chosen，但您的 IP 位於$exit。';
  }

  @override
  String get failSignIn => '此帳號的登入已過期。請在「帳號」頁面重新登入。';

  @override
  String get failQuota => '本月流量已用完。請新增另一個帳號。';

  @override
  String get failNotEntitled => 'Mozilla 不允許此帳號使用 VPN。請新增另一個帳號。';

  @override
  String get failRegion => 'Mozilla 不在您所在的國家提供服務。';

  @override
  String get failServer => 'Mozilla 服務暫時發生問題。應用程式會自動重試。';

  @override
  String get failNoAccount => '沒有可用的帳號。請開啟「帳號」頁面。';

  @override
  String get failTestSite => '已連線伺服器，但網站打不開。請換個國家試試。';

  @override
  String get failOther => '無法連線。請再試一次。';

  @override
  String get failNoInternet => '無網路連線。請檢查 Wi-Fi 或行動數據。';

  @override
  String get waitingForNetwork => '正在等待網路連線…';

  @override
  String proxyStartFailed(String port) {
    return '代理無法在連接埠 $port 上啟動。請選擇其他連接埠。';
  }

  @override
  String get connectionSettings => '連線設定';

  @override
  String get appModeExclude => '排除所選應用程式';

  @override
  String get appModeInclude => '僅代理所選應用程式';

  @override
  String get appModeExcludeHint => '所選應用程式直接連線，不經過 VPN：例如會拒絕境外 IP 的銀行應用程式。';

  @override
  String get appModeIncludeHint => '只有所選應用程式經過 VPN；其他應用程式直接連線。';

  @override
  String fromRegionList(String region) {
    return '推薦：列於$region清單中';
  }

  @override
  String get modeProxy => '代理';

  @override
  String get connectionMode => '連線模式';

  @override
  String get modeProxyHint => '只有已設定使用代理的應用程式會經過代理；不會變更 Windows 設定。';

  @override
  String get modeSystemProxyHint => 'Windows 和大多數應用程式都會經過代理。';

  @override
  String get modeProxyHintOther => '只有已設定使用代理的應用程式會經過代理；不會變更系統設定。';

  @override
  String get modeSystemProxyHintOther => '瀏覽器和大多數應用程式都會經過代理。';

  @override
  String get suggestedApps => '推薦的應用程式';

  @override
  String suggestedAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已選取 $count 個推薦的應用程式',
      one: '已選取 1 個推薦的應用程式',
      zero: '推薦的應用程式都已選取',
    );
    return '$_temp0';
  }

  @override
  String get autoSection => '自動';

  @override
  String get locationsSection => '位置';

  @override
  String get dnsSummaryOk => '加密 DNS 運作正常';

  @override
  String dnsSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個網域無法解析',
      one: '1 個網域無法解析',
    );
    return '$_temp0';
  }

  @override
  String dnsVia(String server) {
    return '透過 $server';
  }

  @override
  String dnsSummaryDiffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '您網路的 DNS 對 $count 個網域回傳了過濾用的位址，本應用程式不會用它解析這些網域。',
      one: '您網路的 DNS 對 1 個網域回傳了過濾用的位址，本應用程式不會用它解析這些網域。',
    );
    return '$_temp0';
  }

  @override
  String get dnsAnswer => '結果：';

  @override
  String get dnsNetworkAnswer => '網路 DNS：';

  @override
  String get dnsFiltered => '已過濾';

  @override
  String get rulesSyntaxTitle => '每行一條規則';

  @override
  String get ruleDomain => '該網站及其子網域';

  @override
  String get ruleFull => '完全符合此網域';

  @override
  String get ruleKeyword => '包含此關鍵字的網域';

  @override
  String get ruleGeosite => 'Geo 檔案中某個標籤的網站';

  @override
  String get ruleGeoip => 'Geo 檔案中某個國家的位址';

  @override
  String get ruleIp => '單一 IP 或網段';

  @override
  String get modeVpn => 'VPN';

  @override
  String get modeProxyOnly => '僅代理';

  @override
  String get noNetwork => '沒有網路連線。請開啟 Wi-Fi 或行動數據。';

  @override
  String get blockAds => '封鎖廣告';

  @override
  String systemProxyTakenBy(String address) {
    return '另一個程式將系統代理改為 $address，流量不再經過 VPN。';
  }

  @override
  String get systemProxyTakenOff => '另一個程式關閉了系統代理，流量不再經過 VPN。';

  @override
  String get setSystemProxyAgain => '重新設定';
}
