import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../core/ports.dart';
import '../l10n/app_localizations.dart';
import '../platform.dart';
import 'bypass_apps_page.dart';
import 'format.dart';
import 'port_dialog.dart';
import 'widgets.dart';

/// The DNS presets the web dashboard offers (core/internal/service/web/app.js).
const _dnsPresets = <String, List<String>>{
  'system': [],
  'auto': [
    'https://1.1.1.1/dns-query',
    'https://8.8.8.8/dns-query',
    'https://9.9.9.9/dns-query',
  ],
  'cloudflare': ['https://1.1.1.1/dns-query', 'https://1.0.0.1/dns-query'],
  'google': ['https://8.8.8.8/dns-query', 'https://8.8.4.4/dns-query'],
  'quad9': ['https://9.9.9.9/dns-query', 'https://149.112.112.112/dns-query'],
  'cloudflare_dot': ['tls://1.1.1.1', 'tls://1.0.0.1'],
};

/// The app's preferences and the core's settings (config.json, edited
/// through the API so that every field the app does not show is kept).
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.core,
    required this.settings,
    this.section,
    this.opening,
  });

  final CoreController core;
  final AppSettings settings;

  /// The section open at first, with the way back to the list (the
  /// computer's home page opens Connection).
  final SettingsSection? opening;

  /// Shows only this section, on a page of its own (Android's settings).
  final SettingsSection? section;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// The groups of settings, each on its own page.
enum SettingsSection { general, connection, dns, routing, accounts, advanced }

/// Each section's icon and name, in the order the lists show them.
List<(SettingsSection, IconData, String)> settingsSections(
  AppLocalizations l,
) => [
  (SettingsSection.general, Icons.tune_rounded, l.sectionGeneral),
  (SettingsSection.connection, Icons.computer_rounded, l.sectionConnection),
  (SettingsSection.dns, Icons.dns_rounded, l.sectionDns),
  (SettingsSection.routing, Icons.alt_route_rounded, l.sectionRouting),
  (SettingsSection.accounts, Icons.swap_horiz_rounded, l.sectionAccounts),
  // The app's port and the web dashboard: computers only.
  if (!Platform.isAndroid)
    (SettingsSection.advanced, Icons.build_outlined, l.sectionAdvanced),
];

class _SettingsPageState extends State<SettingsPage> {
  /// The section shown; null for the list of sections.
  late SettingsSection? _open = widget.section ?? widget.opening;

  /// The core's config.json as raw JSON; null until read.
  Map<String, Object?>? _config;
  bool _saving = false;
  String? _dnsPreset;

  CoreController get _core => widget.core;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await _core.settings();
      if (mounted) setState(() => _config = config);
    } on CoreApiException catch (e) {
      if (mounted) showError(context, e.message);
    } on CoreUnavailable {
      // The shell shows the problem.
    }
  }

  /// A value at [path] in the config, such as ['proxy', 'transport'].
  Object? _get(List<String> path) {
    Object? node = _config;
    for (final key in path) {
      if (node is! Map<String, Object?>) return null;
      node = node[key];
    }
    return node;
  }

  String _str(List<String> path) => _get(path) as String? ?? '';

  bool _bool(List<String> path) => _get(path) == true;

  List<String> _list(List<String> path) => [
    for (final v in (_get(path) as List<Object?>? ?? const [])) '$v',
  ];

  /// Saves [values] (path → value) through the core and reads the config
  /// again; true when the core accepted it.
  Future<bool> _save(Map<List<String>, Object?> values) async {
    setState(() => _saving = true);
    final ok = await runShowingErrors(
      context,
      () => _core.editSettings((config) {
        values.forEach((path, value) {
          var node = config;
          for (final key in path.take(path.length - 1)) {
            node = switch (node[key]) {
              final Map<String, Object?> m => m,
              _ => node[key] = <String, Object?>{},
            };
          }
          node[path.last] = value;
        });
      }),
    );
    if (!mounted) return ok;
    setState(() => _saving = false);
    if (ok) {
      await _load();
      if (mounted) _toast(AppLocalizations.of(context).saved);
    }
    return ok;
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      width: 320,
      duration: const Duration(seconds: 2),
    ),
  );

  Future<void> _changePort(
    String listen,
    Future<void> Function(int port) apply,
  ) async {
    final port = await showPortDialog(context, current: listen);
    if (port == null || !mounted) return;
    final ok = await runShowingErrors(context, () => apply(port));
    if (!mounted || !ok) return;
    // A moved API answers at its new address after a moment.
    await Future<void>.delayed(const Duration(seconds: 1));
    await _load();
    if (mounted) _toast(AppLocalizations.of(context).saved);
  }

  /// Changes the language, then offers the routing most of its speakers
  /// want (Persian: Iran, Chinese: China, Russian: Russia).
  Future<void> _pickLanguage(String language) async {
    widget.settings.update(language: language);
    final region = AppSettings.regionForLanguage(language);
    if (region == null ||
        (_bool(['routing', 'enabled']) &&
            _str(['routing', 'region']) == region)) {
      return;
    }
    // Let the page rebuild in the new language first.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final country = regionName(l, region);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.alt_route_rounded),
        title: Text(l.routingSuggestTitle(country)),
        content: SizedBox(
          width: 380,
          child: Text(l.routingSuggestBody(country)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.yes),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _save({
        ['routing', 'enabled']: true,
        ['routing', 'region']: region,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = widget.settings;
    final sections = settingsSections(l);
    final open = _open;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        if (open == null) {
          return ListView(
            padding: pagePadding(context),
            children: [
              PageTitle(l.settingsTitle),
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: Icon(sections[i].$2),
                        title: Text(sections[i].$3),
                        // Mirrors itself in right-to-left languages.
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => setState(() => _open = sections[i].$1),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }
        final title = sections.firstWhere((e) => e.$1 == open).$3;
        final fixed = widget.section != null;
        final page = ListView(
          padding: fixed
              ? pagePadding(context)
              : const EdgeInsets.fromLTRB(20, 16, 28, 28),
          children: [
            if (!fixed)
              Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const BackButtonIcon(),
                    onPressed: () => setState(() => _open = null),
                  ),
                  const SizedBox(width: 4),
                  Text(title, style: theme.textTheme.headlineSmall),
                ],
              ),
            if (!fixed) const SizedBox(height: 16),
            if (open == SettingsSection.general)
              _general(l, s)
            else if (_config == null)
              const LinearProgressIndicator()
            else
              switch (open) {
                SettingsSection.connection => _connection(l),
                SettingsSection.routing => _routing(l),
                SettingsSection.dns => _dns(l),
                SettingsSection.accounts => _accounts(l),
                _ => _advanced(l),
              },
          ],
        );
        if (fixed) return page;
        // Esc goes back to the list of sections, like the back arrow.
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                setState(() => _open = null),
          },
          child: Focus(autofocus: true, child: page),
        );
      },
    );
  }

  Widget _general(AppLocalizations l, AppSettings s) => Panel(
    title: l.sectionGeneral,
    icon: Icons.tune_rounded,
    child: Column(
      children: [
        _Choice<String>(
          icon: Icons.translate_rounded,
          title: l.language,
          value: s.language,
          onChanged: _pickLanguage,
          options: [
            ('', l.languageSystem, null),
            for (final code in AppSettings.supportedLanguages)
              (code, languageNames[code]!, languageStyle(code)),
          ],
        ),
        _Choice<ThemeMode>(
          icon: Icons.brightness_6_outlined,
          title: l.theme,
          value: s.themeMode,
          onChanged: (v) => s.update(themeMode: v),
          options: [
            (ThemeMode.system, l.themeSystem, null),
            (ThemeMode.light, l.themeLight, null),
            (ThemeMode.dark, l.themeDark, null),
          ],
        ),
        if (!Platform.isAndroid)
          _Choice<CloseAction>(
            icon: Icons.close_rounded,
            title: l.closeBehavior,
            value: s.closeAction,
            onChanged: (v) => s.update(closeAction: v),
            options: [
              (CloseAction.ask, l.closeAsk, null),
              (CloseAction.tray, l.closeTray, null),
              (CloseAction.quit, l.closeQuit, null),
            ],
          ),
        _Row(
          icon: Icons.visibility_outlined,
          label: l.showPublicIp,
          child: Switch(
            value: s.showPublicIp,
            onChanged: (v) => s.update(showPublicIp: v),
          ),
        ),
        if (Platform.isAndroid)
          ValueListenableBuilder(
            valueListenable: AndroidCore.showSpeed,
            builder: (context, on, _) => _Row(
              icon: Icons.speed_rounded,
              label: l.speedInNotification,
              child: Switch(
                value: on,
                onChanged: (v) => runShowingErrors(
                  context,
                  () => AndroidCore.setShowSpeed(v),
                ),
              ),
            ),
          ),
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          _Row(
            icon: Icons.power_settings_new_rounded,
            label: l.startOnBoot,
            child: Switch(
              value: s.autostart,
              onChanged: (v) => s.update(autostart: v),
            ),
          ),
        // Only with the start at sign-in: dimmed without it.
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          Opacity(
            opacity: s.autostart ? 1 : 0.5,
            child: _Row(
              icon: Icons.link_rounded,
              label: l.connectOnStartup,
              child: Switch(
                value: s.autoConnect,
                onChanged: s.autostart ? (v) => s.update(autoConnect: v) : null,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _connection(AppLocalizations l) {
    final status = _core.status;
    final proxyListen = _str(['proxy', 'listen']);
    final port = portOf(proxyListen) ?? 10810;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // How the app reaches Mozilla.
        Panel(
          title: l.sectionConnection,
          icon: Icons.cloud_outlined,
          child: Column(
            children: [
              _Choice<String>(
                icon: Icons.http_rounded,
                title: l.transport,
                value: _str(['proxy', 'transport']) == 'h2' ? 'h2' : 'h3',
                onChanged: _saving
                    ? null
                    : (v) => _save({
                        ['proxy', 'transport']: v,
                      }),
                options: [
                  ('h2', l.transportH2, null),
                  ('h3', l.transportH3, null),
                ],
              ),
              // The phone never sleeps (the core turns it off there).
              if (!Platform.isAndroid) _sleepChoice(l),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Where apps on this device (and the network) connect.
        Panel(
          title: l.localProxy,
          icon: Icons.computer_rounded,
          child: Column(
            children: [
              if (Platform.isAndroid)
                ValueListenableBuilder(
                  valueListenable: AndroidCore.mode,
                  builder: (context, mode, _) => _Choice<String>(
                    icon: Icons.vpn_lock_outlined,
                    title: l.connectionMode,
                    value: mode,
                    onChanged: (v) =>
                        runShowingErrors(context, () => AndroidCore.setMode(v)),
                    options: [
                      ('vpn', l.modeVpn, null),
                      ('proxy', l.modeProxyOnly, null),
                    ],
                  ),
                ),
              if (status != null && status.systemProxySupported)
                _Choice<String>(
                  icon: Icons.tune_rounded,
                  title: l.connectionMode,
                  value: status.systemProxySet ? 'set' : 'clear',
                  onChanged: (v) =>
                      runShowingErrors(context, () => _core.setSystemProxy(v)),
                  options: [
                    ('clear', l.modeProxy, null),
                    ('set', l.systemProxy, null),
                  ],
                ),
              _PortRow(
                icon: Icons.call_split_rounded,
                label: l.proxyPort,
                listen: proxyListen,
                onChange: () => _changePort(proxyListen, _core.setProxyPort),
              ),
              // Who may connect: this device only, or other devices too (all
              // interfaces). A login is optional either way; the core warns
              // in its log when the proxy is open to the network without one.
              _Choice<bool>(
                icon: Icons.share_outlined,
                title: l.listenAddress,
                value: sharedWithLan(proxyListen),
                onChanged: _saving
                    ? null
                    : (all) => _save({
                        ['proxy', 'listen']: all
                            ? '0.0.0.0:$port'
                            : '127.0.0.1:$port',
                      }),
                options: [
                  (false, l.listenLocal, null),
                  (true, l.listenAll, null),
                ],
              ),
              _Expand(
                icon: Icons.key_outlined,
                title: l.proxyLogin,
                children: [
                  // Both are saved together: the core takes both or neither.
                  _ProxyLogin(
                    username: _str(['proxy', 'username']),
                    password: _str(['proxy', 'password']),
                    onSave: (username, password) => _save({
                      ['proxy', 'username']: username,
                      ['proxy', 'password']: password,
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _routing(AppLocalizations l) {
    final on = _bool(['routing', 'enabled']);
    final region = _str(['routing', 'region']);
    // Separate sections: the switch and country, the rules, the geo
    // files, and the destination test.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          title: l.sectionRouting,
          icon: Icons.alt_route_rounded,
          child: Column(
            children: [
              _Choice<String>(
                icon: Icons.flag_outlined,
                title: l.region,
                value: AppSettings.regions.contains(region) ? region : '',
                onChanged: _saving || !on
                    ? null
                    : (v) => _save({
                        ['routing', 'region']: v,
                      }),
                options: [
                  for (final r in AppSettings.regions)
                    (r, regionName(l, r), null),
                ],
              ),
              if (Platform.isAndroid)
                _Row(
                  icon: Icons.apps_rounded,
                  label: l.bypassApps,
                  child: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BypassAppsPage(
                        region: on && region.isNotEmpty
                            ? regionName(l, region)
                            : null,
                      ),
                    ),
                  ),
                ),
              _Row(
                icon: Icons.alt_route_rounded,
                label: l.routingDirect,
                child: Switch(
                  value: on,
                  onChanged: _saving
                      ? null
                      : (v) => _save({
                          ['routing', 'enabled']: v,
                        }),
                ),
              ),
              // A shortcut for one Block rule, which the list shows too.
              _Row(
                icon: Icons.block_rounded,
                label: l.blockAds,
                child: Switch(
                  value: on && _blocksAds,
                  onChanged: _saving || !on ? null : _setBlockAds,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: l.rulesTitle,
          icon: Icons.rule_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The region's rules are in the Direct list itself: the user can
              // change or remove them; another region replaces them.
              _TextSetting(
                label: l.directRules,
                hint: l.directRulesHint,
                value: _list(['routing', 'direct']).join('\n'),
                multiline: true,
                onSave: (v) => _save({
                  ['routing', 'direct']: _lines(v),
                }),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _saving ? null : _restoreRegionRules,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(l.restoreRegionRules),
                ),
              ),
              const SizedBox(height: 16),
              _TextSetting(
                label: l.blockRules,
                hint: l.blockRulesHint,
                value: _list(['routing', 'block']).join('\n'),
                multiline: true,
                onSave: (v) => _save({
                  ['routing', 'block']: _lines(v),
                }),
              ),
              _Expand(
                title: l.ruleSyntaxTitle,
                children: const [_RuleSyntax()],
              ),
              const Divider(height: 24),
              _Row(
                icon: Icons.travel_explore_rounded,
                label: l.resolveDomains,
                child: Switch(
                  value: _bool(['routing', 'resolve_domains']),
                  onChanged: _saving
                      ? null
                      : (v) => _save({
                          ['routing', 'resolve_domains']: v,
                        }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: l.routingLists,
          icon: Icons.public_rounded,
          child: _RoutingLists(
            // Read again after the source changes.
            key: ValueKey(_str(['routing', 'geosite_url'])),
            core: _core,
            onSource: (geosite, geoip) => _save({
              ['routing', 'geosite_url']: geosite,
              ['routing', 'geoip_url']: geoip,
            }),
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: l.testDestination,
          icon: Icons.science_outlined,
          child: _DestinationTest(core: _core),
        ),
      ],
    );
  }

  /// The Block rule for ads, in both geo sources.
  static const _adsRule = 'geosite:category-ads-all';

  bool _isAdsRule(String rule) => rule.trim().toLowerCase() == _adsRule;

  bool get _blocksAds => _list(['routing', 'block']).any(_isAdsRule);

  Future<void> _setBlockAds(bool on) => _save({
    ['routing', 'block']: [
      for (final r in _list(['routing', 'block']))
        if (!_isAdsRule(r)) r,
      if (on) _adsRule,
    ],
  });

  /// Puts the region's rules back in the Direct list, before the user's
  /// own (the ones removed come back; nothing else changes).
  Future<void> _restoreRegionRules() async {
    RoutingInfo? info;
    final ok = await runShowingErrors(context, () async {
      info = await _core.call((api) => api.routing());
    });
    final presets = info?.regionRules;
    if (!ok || presets == null || !mounted) return;
    final current = _list(['routing', 'direct']);
    final seen = {for (final r in presets) r.toLowerCase()};
    await _save({
      ['routing', 'direct']: [
        ...presets,
        for (final r in current)
          if (!seen.contains(r.trim().toLowerCase())) r,
      ],
    });
  }

  Widget _accounts(AppLocalizations l) => Panel(
    title: l.sectionAccounts,
    icon: Icons.people_outline_rounded,
    child: Column(
      children: [
        _TextSetting(
          label: l.switchThreshold,
          hint: l.switchThresholdHint,
          value: _number(_get(['accounts', 'switch_threshold_percent'])),
          suffix: '%',
          validator: (v) => _intIn(v, 1, 100) ? null : l.numberInvalid(1, 100),
          onSave: (v) => _save({
            ['accounts', 'switch_threshold_percent']: int.parse(v.trim()),
          }),
        ),
      ],
    ),
  );

  Widget _dns(AppLocalizations l) {
    final servers = _list(['dns', 'servers']);
    final saved =
        _dnsPresets.entries
            .where((e) => e.value.join(',') == servers.join(','))
            .firstOrNull
            ?.key ??
        'custom';
    final preset = _dnsPreset ?? saved;
    final names = {
      'system': l.dnsSystem,
      'auto': l.dnsAuto,
      'cloudflare': 'Cloudflare',
      'google': 'Google',
      'quad9': 'Quad9',
      'cloudflare_dot': 'Cloudflare (DNS over TLS)',
      'custom': l.dnsCustom,
    };
    return Panel(
      title: l.sectionDns,
      icon: Icons.dns_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Choice<String>(
            icon: Icons.dns_outlined,
            title: l.dnsPreset,
            value: preset,
            onChanged: _saving
                ? null
                : (v) {
                    setState(() => _dnsPreset = v);
                    if (v != 'custom') {
                      _save({
                        ['dns', 'servers']: _dnsPresets[v]!,
                      }).then((_) {
                        if (mounted) setState(() => _dnsPreset = null);
                      });
                    }
                  },
            options: [for (final e in names.entries) (e.key, e.value, null)],
          ),
          if (preset == 'custom') ...[
            const SizedBox(height: 16),
            _TextSetting(
              label: l.dnsCustom,
              hint: l.dnsCustomHint,
              value: servers.join('\n'),
              multiline: true,
              onSave: (v) async {
                await _save({
                  ['dns', 'servers']: _lines(v),
                });
                if (mounted) setState(() => _dnsPreset = null);
              },
            ),
          ],
          _Row(
            icon: Icons.settings_backup_restore_rounded,
            label: l.dnsFallback,
            child: Switch(
              value: _bool(['dns', 'fallback_to_system']),
              onChanged: _saving
                  ? null
                  : (v) => _save({
                      ['dns', 'fallback_to_system']: v,
                    }),
            ),
          ),
          const Divider(height: 24),
          _DnsTest(core: _core, servers: servers),
        ],
      ),
    );
  }

  /// After how long without traffic the connection to Mozilla sleeps.
  Widget _sleepChoice(AppLocalizations l) {
    final current = _shortDuration(_str(['proxy', 'idle_sleep']));
    final options = [
      ('0s', l.sleepNever, null),
      for (final m in const [5, 15, 30]) ('${m}m', l.sleepMinutes(m), null),
      ('1h', l.sleepHour, null),
    ];
    return _Choice<String>(
      icon: Icons.bedtime_outlined,
      title: l.idleSleep,
      value: current,
      onChanged: _saving
          ? null
          : (v) => _save({
              ['proxy', 'idle_sleep']: v,
            }),
      options: [
        ...options,
        // A value set elsewhere (the dashboard) stays visible.
        if (!options.any((o) => o.$1 == current)) (current, current, null),
      ],
    );
  }

  Widget _advanced(AppLocalizations l) {
    final appListen = _str(['dashboard', 'listen']);
    final dashboard = CoreLocator.listenUri(appListen).replace(path: '/app/');
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PortRow(
            icon: Icons.hub_outlined,
            label: l.appPort,
            listen: appListen,
            onChange: () => _changePort(appListen, _core.setAppPort),
          ),
          _Row(
            icon: Icons.dashboard_outlined,
            label: l.webDashboard,
            // An address reads left to right in a right-to-left language.
            value: ltr('$dashboard'),
            child: const Icon(Icons.open_in_new_rounded, size: 20),
            onTap: () => runShowingErrors(
              context,
              () async => openUrl('${await _core.dashboardLink()}'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-empty trimmed lines.
List<String> _lines(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

String _number(Object? v) =>
    v is num ? (v == v.roundToDouble() ? '${v.round()}' : '$v') : '';

bool _intIn(String v, int min, int max) {
  final n = int.tryParse(v.trim());
  return n != null && n >= min && n <= max;
}

/// Go's "1h0m0s" as "1h", "15m0s" as "15m".
String _shortDuration(String go) {
  var s = go;
  if (s.endsWith('m0s')) s = s.substring(0, s.length - 2);
  if (s.endsWith('h0m')) s = s.substring(0, s.length - 2);
  return s;
}

/// A choice among a few values, shown as the current one; a tap opens the
/// values in a dialog in the middle of the window (not a menu at the
/// control), one radio button each.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;

  /// Each value with its label and the label's style (a language in its
  /// own font).
  final List<(T, String, TextStyle?)> options;
  final ValueChanged<T>? onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: RadioGroup<T>(
              groupValue: value,
              onChanged: (v) => Navigator.pop(context, v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (v, label, style) in options)
                    RadioListTile<T>(
                      value: v,
                      title: Text(label, style: style),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ],
      ),
    );
    if (picked != null && picked != value) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.$1 == value).firstOrNull;
    return _Row(
      icon: icon,
      label: title,
      value: current?.$2 ?? '',
      onTap: onChanged == null ? null : () => _open(context),
    );
  }
}

/// A setting as one row, as in Hiddify: its icon, its name with the
/// current value under it, and a switch (or nothing) at the end. A tap
/// opens the choices, the port dialog, or the page it names.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.child,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final value = this.value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: muted),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyLarge),
                  if (value != null && value.isNotEmpty)
                    Text(
                      value,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                ],
              ),
            ),
            if (child case final child?) ...[const SizedBox(width: 12), child],
          ],
        ),
      ),
    );
  }
}

/// A collapsed group of settings.
class _Expand extends StatelessWidget {
  const _Expand({required this.title, required this.children, this.icon});

  final String title;
  final List<Widget> children;

  /// Lines the group up with the rows (_Row) above it.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: icon == null
            ? EdgeInsets.zero
            : const EdgeInsetsDirectional.only(start: 4),
        leading: icon == null
            ? null
            : Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(
          title,
          style: icon == null
              ? theme.textTheme.titleSmall
              : theme.textTheme.bodyLarge,
        ),
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// A text setting with its own Save button, enabled once the text changes.
class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.onSave,
    this.hint,
    this.multiline = false,
    this.suffix,
    this.validator,
  });

  final String label;
  final String value;
  final Future<void> Function(String value) onSave;
  final String? hint;
  final bool multiline;
  final String? suffix;
  final String? Function(String value)? validator;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _controller = TextEditingController(text: widget.value);
  String? _error;
  bool _saving = false;

  @override
  void didUpdateWidget(_TextSetting old) {
    super.didUpdateWidget(old);
    // A saved value comes back from the core; keep unsaved typing.
    if (old.value != widget.value && _controller.text == old.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.text != widget.value;

  Future<void> _submit() async {
    final error = widget.validator?.call(_controller.text);
    setState(() => _error = error);
    if (error != null || !_dirty) return;
    setState(() => _saving = true);
    await widget.onSave(_controller.text);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final field = TextField(
      controller: _controller,
      minLines: widget.multiline ? 3 : 1,
      maxLines: widget.multiline ? 8 : 1,
      textDirection: TextDirection.ltr,
      style: widget.multiline
          ? const TextStyle(fontFamily: 'Consolas', fontSize: 13)
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.hint,
        helperMaxLines: 6,
        errorText: _error,
        suffixText: widget.suffix,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() => _error = null),
      onSubmitted: widget.multiline ? null : (_) => _submit(),
    );
    final button = _saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : FilledButton.tonal(
            onPressed: _dirty ? _submit : null,
            child: Text(l.save),
          );
    // In a narrow window (a phone), and under a list of lines, the button
    // goes under the field, which keeps the whole width.
    return LayoutBuilder(
      builder: (context, box) => widget.multiline || box.maxWidth < 480
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerEnd, child: button),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field),
                const SizedBox(width: 12),
                Padding(padding: const EdgeInsets.only(top: 2), child: button),
              ],
            ),
    );
  }
}

/// The proxy's username and password, saved together with one button: the
/// core accepts both or neither, never one alone.
class _ProxyLogin extends StatefulWidget {
  const _ProxyLogin({
    required this.username,
    required this.password,
    required this.onSave,
  });

  final String username;
  final String password;
  final Future<void> Function(String username, String password) onSave;

  @override
  State<_ProxyLogin> createState() => _ProxyLoginState();
}

class _ProxyLoginState extends State<_ProxyLogin> {
  late final _user = TextEditingController(text: widget.username);
  late final _pass = TextEditingController(text: widget.password);
  bool _show = false;
  bool _saving = false;
  String? _error;

  @override
  void didUpdateWidget(_ProxyLogin old) {
    super.didUpdateWidget(old);
    // Saved values come back from the core; keep unsaved typing.
    if (old.username != widget.username && _user.text == old.username) {
      _user.text = widget.username;
    }
    if (old.password != widget.password && _pass.text == old.password) {
      _pass.text = widget.password;
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _user.text.trim() != widget.username || _pass.text != widget.password;

  Future<void> _submit() async {
    final user = _user.text.trim();
    final pass = _pass.text;
    if (user.isEmpty != pass.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).loginBothOrNone);
      return;
    }
    if (!_dirty) return;
    setState(() => _saving = true);
    await widget.onSave(user, pass);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void changed(String _) => setState(() => _error = null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.proxyLoginHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(
          controller: _user,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l.proxyUsername,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: changed,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: !_show,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l.proxyPassword,
            errorText: _error,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _show ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
          onChanged: changed,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton.tonal(
                  onPressed: _dirty ? _submit : null,
                  child: Text(l.save),
                ),
        ),
      ],
    );
  }
}

/// A port setting: the current port and a button that changes it.
class _PortRow extends StatelessWidget {
  const _PortRow({
    required this.icon,
    required this.label,
    required this.listen,
    required this.onChange,
  });

  final IconData icon;
  final String label;
  final String listen;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => _Row(
    icon: icon,
    label: label,
    value: '${portOf(listen) ?? '—'}',
    onTap: listen.isEmpty ? null : onChange,
  );
}

/// The routing lists: their state and Update now.
class _RoutingLists extends StatefulWidget {
  const _RoutingLists({super.key, required this.core, required this.onSource});

  final CoreController core;

  /// Saves another list set (its two URLs); the core downloads it.
  final Future<bool> Function(String geosite, String geoip) onSource;

  @override
  State<_RoutingLists> createState() => _RoutingListsState();
}

class _RoutingListsState extends State<_RoutingLists> {
  RoutingInfo? _info;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final info = await widget.core.call((api) => api.routing());
      if (mounted) setState(() => _info = info);
    } on Exception {
      // Shown as unknown.
    }
  }

  Future<void> _update() async {
    final l = AppLocalizations.of(context);
    setState(() => _updating = true);
    try {
      final info = await widget.core.call((api) => api.updateRoutingLists());
      if (!mounted) return;
      setState(() => _info = info);
      showError(context, l.listsUpdated);
    } on CoreApiException catch (e) {
      if (mounted) showError(context, e.message);
    } on CoreUnavailable catch (e) {
      if (mounted) showError(context, describeProblem(l, e));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final info = _info;
    // When the files were updated ("5 days ago": the oldest), and their
    // names and size.
    final files =
        info?.lists ?? const <({String name, int size, DateTime? updatedAt})>[];
    final dates = [
      for (final f in files)
        if (f.updatedAt != null) f.updatedAt!,
    ]..sort();
    final lines = [
      if (info != null && info.error.isNotEmpty) info.error,
      if (dates.isNotEmpty) l.listsUpdatedAgo(formatSince(l, dates.first)),
      if (files.isNotEmpty)
        [
          ltr(files.map((f) => f.name).join(', ')),
          formatBytes(files.fold(0, (sum, f) => sum + f.size)),
        ].join(' · '),
    ];
    final sources = info?.sources ?? const [];
    // A tap downloads the lists again.
    final lists = _Row(
      icon: Icons.folder_outlined,
      label: l.updateLists,
      value: lines.join('\n'),
      onTap: _updating ? null : _update,
      child: _updating
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded),
    );
    if (info == null || sources.isEmpty) return lists;
    return Column(
      children: [
        // Where the lists come from, as in v2rayNG; the country picks its
        // usual one by itself.
        _Choice<String>(
          icon: Icons.cloud_outlined,
          title: l.listSource,
          value: info.source,
          onChanged: (id) {
            final s = sources.firstWhere((s) => s.id == id);
            widget.onSource(s.geositeUrl, s.geoipUrl);
          },
          options: [
            for (final s in sources) (s.id, s.name, null),
            if (info.source.isEmpty) ('', l.listSourceCustom, null),
          ],
        ),
        lists,
      ],
    );
  }
}

/// A rule as written, left to right in a small monospace box.
class _RuleChip extends StatelessWidget {
  const _RuleChip(this.rule);

  final String rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          rule,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'Consolas',
            fontFamilyFallback: const ['monospace'],
          ),
        ),
      ),
    );
  }
}

/// The rules the chosen country adds by itself, so they are no surprise.
/// How to write a rule, one example per kind.
class _RuleSyntax extends StatelessWidget {
  const _RuleSyntax();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // The rules are English, so the guide reads left to right in every
    // language: the rule first, then what it means (in the app's own
    // direction).
    final direction = Directionality.of(context);
    final examples = [
      ('domain:example.com', l.ruleDomain),
      ('full:www.example.com', l.ruleFull),
      ('keyword:bank', l.ruleKeyword),
      ('geosite:ir', l.ruleGeosite),
      ('geoip:ir', l.ruleGeoip),
      ('1.2.3.4  10.0.0.0/8', l.ruleIp),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.rulesSyntaxTitle,
            textDirection: direction,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          for (final (rule, what) in examples)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Wrap(
                textDirection: TextDirection.ltr,
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _RuleChip(rule),
                  Text(what, textDirection: direction, style: small),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Where a destination goes, and which rule decides it.
class _DestinationTest extends StatefulWidget {
  const _DestinationTest({required this.core});

  final CoreController core;

  @override
  State<_DestinationTest> createState() => _DestinationTestState();
}

class _DestinationTestState extends State<_DestinationTest> {
  final _target = TextEditingController();
  DestinationTest? _result;
  bool _testing = false;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final target = _target.text.trim();
    if (target.isEmpty) return;
    final l = AppLocalizations.of(context);
    setState(() => _testing = true);
    try {
      final result = await widget.core.call(
        (api) => api.testDestination(target),
      );
      if (mounted) setState(() => _result = result);
    } on CoreApiException catch (e) {
      if (mounted) showError(context, e.message);
    } on CoreUnavailable catch (e) {
      if (mounted) showError(context, describeProblem(l, e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = _result;
    final (text, color) = switch (r?.route) {
      'direct' => (l.routeDirect, StatusColors.good),
      'block' => (l.routeBlock, StatusColors.bad),
      _ => (l.routeProxy, theme.colorScheme.primary),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _target,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l.testDestination,
                  hintText: l.destinationHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _test(),
              ),
            ),
            const SizedBox(width: 12),
            _testing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton.tonal(onPressed: _test, child: Text(l.check)),
          ],
        ),
        if (r != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(text, color: color),
              if (r.rule.isNotEmpty)
                Text(l.ruleMatched(r.rule), style: theme.textTheme.bodySmall),
              if (r.resolved.isNotEmpty)
                Text('→ ${r.resolved}', style: theme.textTheme.bodySmall),
              if (r.portRefused)
                Text(
                  l.portRefusedNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: StatusColors.bad,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Resolves the program's own names through the chosen DNS servers and the
/// system's, side by side.
class _DnsTest extends StatefulWidget {
  const _DnsTest({required this.core, required this.servers});

  final CoreController core;
  final List<String> servers;

  @override
  State<_DnsTest> createState() => _DnsTestState();
}

class _DnsTestState extends State<_DnsTest> {
  List<DnsTestHost>? _results;
  bool _testing = false;

  Future<void> _test() async {
    final l = AppLocalizations.of(context);
    setState(() => _testing = true);
    try {
      final results = await widget.core.call(
        (api) => api.testDns(widget.servers),
      );
      if (mounted) setState(() => _results = results);
    } on CoreApiException catch (e) {
      if (mounted) showError(context, e.message);
    } on CoreUnavailable catch (e) {
      if (mounted) showError(context, describeProblem(l, e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final results = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(l.testDns),
          ),
        ),
        if (results != null && results.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DnsSummary(results: results),
          const SizedBox(height: 8),
          for (final r in results)
            Directionality(
              textDirection: TextDirection.ltr,
              child: _DnsResultRow(result: r),
            ),
        ],
      ],
    );
  }
}

/// Whether the network's DNS answered [r] with a filtering address (the
/// core decides). Other differences are normal: large services answer by
/// location.
bool _filteredAnswer(DnsTestHost r) => r.filtered;

/// A DNS server's name for people: the well-known ones by their company.
String _dnsServerName(String source) {
  if (source.isEmpty || source == 'system') return '';
  const known = {
    '1.1.1.1': 'Cloudflare',
    '1.0.0.1': 'Cloudflare',
    '8.8.8.8': 'Google',
    '8.8.4.4': 'Google',
    '9.9.9.9': 'Quad9',
    '149.112.112.112': 'Quad9',
  };
  for (final e in known.entries) {
    if (source.contains(e.key)) return e.value;
  }
  return Uri.tryParse(source)?.host.isNotEmpty == true
      ? Uri.parse(source).host
      : source;
}

/// The test in one line: whether the chosen servers answered, through
/// which, and whether the network's own DNS answered otherwise.
class _DnsSummary extends StatelessWidget {
  const _DnsSummary({required this.results});

  final List<DnsTestHost> results;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final failed = results.where((r) => r.error.isNotEmpty).length;
    final differs = results.where(_filteredAnswer).length;
    final server = results
        .map((r) => _dnsServerName(r.source))
        .firstWhere((n) => n.isNotEmpty, orElse: () => '');
    final (icon, color, title) = failed > 0
        ? (
            Icons.error_outline_rounded,
            StatusColors.bad,
            l.dnsSummaryFailed(failed),
          )
        : differs > 0
        ? (Icons.shield_outlined, StatusColors.busy, l.dnsSummaryOk)
        : (Icons.verified_outlined, StatusColors.good, l.dnsSummaryOk);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [title, if (server.isNotEmpty) l.dnsVia(server)].join(' · '),
                  style: theme.textTheme.titleSmall,
                ),
                if (differs > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.dnsSummaryDiffers(differs),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One name of the test: what it is for, the address found and how fast,
/// and the network's own DNS beside it when it answered otherwise.
class _DnsResultRow extends StatelessWidget {
  const _DnsResultRow({required this.result});

  final DnsTestHost result;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = result;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ok = r.error.isEmpty;
    final filtered = _filteredAnswer(r);
    String addrs(List<String> a) => a.isEmpty
        ? '—'
        : [a.first, if (a.length > 1) '+${a.length - 1}'].join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              !ok
                  ? Icons.cancel_rounded
                  : filtered
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              size: 18,
              color: !ok
                  ? StatusColors.bad
                  : filtered
                  ? StatusColors.busy
                  : StatusColors.good,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.role.isNotEmpty ? r.role : r.host,
                  style: theme.textTheme.titleSmall,
                ),
                Text(ltr(r.host), style: muted),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? '${l.dnsAnswer} ${ltr(addrs(r.addrs))}'
                      : '${l.dnsAnswer} ${r.error}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ok ? null : StatusColors.bad,
                  ),
                ),
                // The network's own answer when it differs; a warning only
                // when it is a filtering address.
                if (r.differs && r.systemAddrs.isNotEmpty)
                  Text(
                    [
                      '${l.dnsNetworkAnswer} ${ltr(addrs(r.systemAddrs))}',
                      if (filtered) l.dnsFiltered,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: filtered
                          ? StatusColors.busy
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (ok)
            Text(
              l.milliseconds(r.ms),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
