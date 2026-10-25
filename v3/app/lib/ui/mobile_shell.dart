import 'dart:io';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import 'about_page.dart';
import 'accounts_page.dart';
import 'logs_page.dart';
import 'overview_page.dart';
import 'servers_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

/// The phone layout: two tabs, Home and Settings, as phone apps have. The
/// rest (accounts, servers, each group of settings, logs, about) opens as a
/// page of its own with the system's back button.
class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.core,
    required this.settings,
    required this.banner,
    this.noCore,
  });

  final CoreController core;
  final AppSettings settings;

  /// Shown above the page when the core stopped answering.
  final Widget? banner;

  /// Shown in place of the pages until the core first answers.
  final Widget? noCore;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _tab = 0;

  /// Opens [page] under a top bar named [title]; it follows the core.
  void _push(String title, Widget Function() page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListenableBuilder(
          listenable: widget.core,
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              top: false,
              child: OwnTopBar(child: _readable(page())),
            ),
          ),
        ),
      ),
    );
  }

  /// [page] no wider than a line can be read on a tablet; the home page
  /// keeps the whole width for its colors and limits its own content.
  static Widget _readable(Widget page) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: page,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final core = widget.core;
    final settings = widget.settings;
    void openServers() =>
        _push(l.navServers, () => ServersPage(core: core, settings: settings));
    void openAccounts() => _push(l.navAccounts, () => AccountsPage(core: core));
    void openConnection() => _push(
      l.sectionConnection,
      () => SettingsPage(
        core: core,
        settings: settings,
        section: SettingsSection.connection,
      ),
    );
    final page =
        widget.noCore ??
        (_tab == 0
            ? OverviewPage(
                core: core,
                settings: settings,
                onOpenServers: openServers,
                onOpenAccounts: openAccounts,
                onOpenConnection: openConnection,
                phone: true,
              )
            : _readable(
                _SettingsList(
                  onOpenServers: openServers,
                  onOpenAccounts: openAccounts,
                  push: _push,
                  core: core,
                  settings: settings,
                ),
              ));
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: SafeArea(
          // The home page's hero reaches under the status bar.
          top: _tab != 0 || widget.noCore != null || widget.banner != null,
          child: Column(
            children: [
              ?widget.banner,
              Expanded(child: page),
            ],
          ),
        ),
        bottomNavigationBar: _themed(
          context,
          // The dark home page has its own night colors.
          home:
              _tab == 0 &&
              widget.noCore == null &&
              Theme.of(context).brightness == Brightness.dark,
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: l.navSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The home page's midnight theme around [child] while home shows.
  Widget _themed(
    BuildContext context, {
    required bool home,
    required Widget child,
  }) => home
      ? Theme(data: midnightTheme(Theme.of(context)), child: child)
      : child;
}

/// The Settings tab: what the app manages, the groups of settings, and the
/// app's own pages.
class _SettingsList extends StatelessWidget {
  const _SettingsList({
    required this.onOpenServers,
    required this.onOpenAccounts,
    required this.push,
    required this.core,
    required this.settings,
  });

  final VoidCallback onOpenServers;
  final VoidCallback onOpenAccounts;
  final void Function(String title, Widget Function() page) push;
  final CoreController core;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget group(String title, List<Widget> tiles) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 20, 8, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );
    Widget tile(IconData icon, String title, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      // Mirrors itself in right-to-left languages.
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
    Widget section(SettingsSection section, IconData icon, String name) => tile(
      icon,
      name,
      () => push(
        name,
        () => SettingsPage(core: core, settings: settings, section: section),
      ),
    );
    return ListView(
      padding: pagePadding(context),
      children: [
        PageTitle(l.settingsTitle),
        // Language and theme first; then which account, which country, and
        // which sites go through the VPN; then the rest.
        group(l.settingsTitle, [
          section(
            SettingsSection.general,
            Icons.tune_rounded,
            l.sectionGeneral,
          ),
          tile(Icons.people_outline_rounded, l.navAccounts, onOpenAccounts),
          tile(Icons.public_rounded, l.navServers, onOpenServers),
          section(
            SettingsSection.routing,
            Icons.alt_route_rounded,
            l.sectionRouting,
          ),
          section(SettingsSection.dns, Icons.dns_rounded, l.sectionDns),
          section(
            SettingsSection.connection,
            Icons.vpn_lock_outlined,
            l.sectionConnection,
          ),
          section(
            SettingsSection.accounts,
            Icons.swap_horiz_rounded,
            l.sectionAccounts,
          ),
          // The app's port and the web dashboard: computers only (a narrow
          // window shows this layout too).
          if (!Platform.isAndroid)
            section(
              SettingsSection.advanced,
              Icons.build_outlined,
              l.sectionAdvanced,
            ),
        ]),
        group(l.groupApp, [
          tile(
            Icons.receipt_long_outlined,
            l.navLogs,
            () => push(l.navLogs, () => LogsPage(core: core)),
          ),
          tile(
            Icons.info_outline_rounded,
            l.navAbout,
            () => push(l.navAbout, () => AboutPage(core: core)),
          ),
        ]),
      ],
    );
  }
}
