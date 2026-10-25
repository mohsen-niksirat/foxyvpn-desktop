import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/android_core.dart';
import '../l10n/app_localizations.dart';

/// Android, per-app proxy (v2rayN's words): bypass the selected apps, or
/// proxy only the selected apps. The routing region's list (Iran's banks,
/// messengers, and the like) is a suggestion: checked at first, and again
/// with "Suggested apps", never forced. The choice is kept by the app
/// (CoreService.kt) and applied when the page closes.
class BypassAppsPage extends StatefulWidget {
  const BypassAppsPage({super.key, this.region});

  /// The routing region's name while routing is on; its apps are marked.
  final String? region;

  @override
  State<BypassAppsPage> createState() => _BypassAppsPageState();
}

class _BypassAppsPageState extends State<BypassAppsPage> {
  List<InstalledApp>? _apps;
  AppRouting? _routing;

  /// The choice when the page opened, to know whether to apply it.
  String _initial = '';
  String _query = '';
  final Map<String, Future<Uint8List?>> _icons = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await AndroidCore.installedApps();
    final routing = await AndroidCore.appRouting();
    if (!mounted) return;
    setState(() {
      _routing = routing;
      _initial = routing.key;
      _apps = apps;
      _sort();
    });
  }

  /// The checked apps first, then by name.
  void _sort() {
    final r = _routing!;
    _apps!.sort((a, b) {
      final ca = r.checked(a.package), cb = r.checked(b.package);
      if (ca != cb) return ca ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  }

  void _save() => AndroidCore.setAppRouting(_routing!, apply: false);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final routing = _routing;
    final q = _query.trim().toLowerCase();
    final apps = [
      for (final a in _apps ?? const <InstalledApp>[])
        if (q.isEmpty ||
            a.label.toLowerCase().contains(q) ||
            a.package.toLowerCase().contains(q))
          a,
    ];
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Applied once: the VPN is set up again with the new choice.
        if (didPop && routing != null && routing.key != _initial) {
          AndroidCore.setAppRouting(routing, apply: true);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.bypassApps)),
        body: routing == null || _apps == null
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: apps.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(l.appModeExclude),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(l.appModeInclude),
                              ),
                            ],
                            selected: {routing.onlyChosen},
                            onSelectionChanged: (v) {
                              setState(() {
                                routing.onlyChosen = v.first;
                                _sort();
                              });
                              _save();
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            routing.onlyChosen
                                ? l.appModeIncludeHint
                                : l.appModeExcludeHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (!routing.onlyChosen &&
                              routing.suggested.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final added = routing.checkSuggested(
                                    _apps!.map((a) => a.package),
                                  );
                                  setState(_sort);
                                  _save();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l.suggestedAdded(added)),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: Text(l.suggestedApps),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              isDense: true,
                              prefixIcon: const Icon(Icons.search_rounded),
                              hintText: l.search,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ],
                      ),
                    );
                  }
                  final app = apps[i - 1];
                  final onList =
                      widget.region != null &&
                      routing.suggested.contains(app.package);
                  final icon = _icons.putIfAbsent(
                    app.package,
                    () => AndroidCore.appIcon(app.package),
                  );
                  return CheckboxListTile(
                    value: routing.checked(app.package),
                    onChanged: (v) {
                      setState(() => routing.toggle(app.package, v ?? false));
                      _save();
                    },
                    secondary: SizedBox.square(
                      dimension: 40,
                      child: FutureBuilder<Uint8List?>(
                        future: icon,
                        builder: (context, snap) => snap.data == null
                            ? const Icon(Icons.android_rounded)
                            : Image.memory(snap.data!, gaplessPlayback: true),
                      ),
                    ),
                    title: Text(app.label),
                    subtitle: Text(
                      onList ? l.fromRegionList(widget.region!) : app.package,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onList ? theme.colorScheme.primary : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
