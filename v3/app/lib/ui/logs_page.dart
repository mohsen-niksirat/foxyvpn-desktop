import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'widgets.dart';

/// The core's live log: a level and text filter, auto-scroll,
/// clear, and copy.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.core});

  final CoreController core;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  /// Levels from least to most severe; the filter shows a level and above.
  static const _levels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
  static const _max = 2000;

  final _entries = <LogEntry>[];
  final _scroll = ScrollController();
  Timer? _timer;
  int _after = 0;
  bool _reading = false;
  String _minLevel = 'DEBUG';
  String _text = '';
  bool _follow = true;

  /// logging.verbose in the core's settings; null until read.
  bool? _verbose;

  @override
  void initState() {
    super.initState();
    _after = widget.core.logsClearedAfter;
    _readVerbose();
    _read();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _read());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    if (_reading) return;
    _reading = true;
    try {
      final more = await widget.core.call((api) => api.logs(_after));
      if (!mounted || more.isEmpty) return;
      // Lines logged before Clear but not yet read (the page reads once a
      // second, and a read may be under way) stay cleared.
      final cleared = widget.core.logsClearedAt;
      setState(() {
        _entries.addAll([
          for (final e in more)
            if (cleared == null || e.time == null || e.time!.isAfter(cleared))
              e,
        ]);
        _after = more.last.id;
        if (_entries.length > _max) {
          _entries.removeRange(0, _entries.length - _max);
        }
      });
      if (_follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    } on CoreApiException {
      // The next tick tries again.
    } on CoreUnavailable {
      // The shell shows it.
    } finally {
      _reading = false;
    }
  }

  Future<void> _readVerbose() async {
    try {
      final config = await widget.core.settings();
      final logging = config['logging'];
      if (mounted) {
        setState(
          () => _verbose = logging is Map<String, Object?>
              ? logging['verbose'] == true
              : false,
        );
      }
    } on Exception {
      // The chip stays hidden.
    }
  }

  Future<void> _setVerbose(bool on) async {
    final ok = await runShowingErrors(
      context,
      () => widget.core.editSettings((config) {
        final logging = config['logging'];
        if (logging is Map<String, Object?>) {
          logging['verbose'] = on;
        } else {
          config['logging'] = <String, Object?>{'verbose': on};
        }
      }),
    );
    if (ok && mounted) setState(() => _verbose = on);
  }

  List<LogEntry> _visible() {
    final min = _levels.indexOf(_minLevel);
    final text = _text.trim().toLowerCase();
    return [
      for (final e in _entries)
        if (_levels.indexOf(e.level) >= min &&
            (text.isEmpty || e.message.toLowerCase().contains(text)))
          e,
    ];
  }

  static String _line(LogEntry e) {
    final t = e.time;
    final time = t == null
        ? ''
        : '${formatTime(t)}:${t.second.toString().padLeft(2, '0')}';
    return '$time ${e.level.padRight(5)} ${e.message}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final visible = _visible();
    return Padding(
      padding: pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(l.navLogs),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'DEBUG', label: Text(l.levelAll)),
                  const ButtonSegment(value: 'INFO', label: Text('INFO')),
                  const ButtonSegment(value: 'WARN', label: Text('WARN')),
                  const ButtonSegment(value: 'ERROR', label: Text('ERROR')),
                ],
                selected: {_minLevel},
                onSelectionChanged: (v) => setState(() => _minLevel = v.first),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.filter_list_rounded, size: 20),
                    hintText: l.filter,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _text = v),
                ),
              ),
              FilterChip(
                label: Text(l.follow),
                selected: _follow,
                onSelected: (v) => setState(() => _follow = v),
              ),
              // Every destination in the log, for finding problems.
              if (_verbose case final verbose?)
                FilterChip(
                  avatar: const Icon(Icons.article_outlined, size: 18),
                  label: Text(l.verboseLogs),
                  selected: verbose,
                  onSelected: _setVerbose,
                ),
              TextButton.icon(
                onPressed: () => setState(() {
                  widget.core.logsClearedAfter = _after;
                  widget.core.logsClearedAt = DateTime.now();
                  _entries.clear();
                }),
                icon: const Icon(Icons.clear_all_rounded),
                label: Text(l.clear),
              ),
              TextButton.icon(
                onPressed: visible.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(
                          ClipboardData(text: visible.map(_line).join('\n')),
                        );
                        showError(context, l.logsCopied);
                      },
                icon: const Icon(Icons.copy_rounded),
                label: Text(l.copyAll),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: visible.isEmpty
                  ? Center(child: Text(l.noLogs))
                  : SelectionArea(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: visible.length,
                        itemBuilder: (context, i) =>
                            _LogLine(entry: visible[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    final color = switch (e.level) {
      'ERROR' => StatusColors.bad,
      'WARN' => StatusColors.busy,
      'DEBUG' => theme.colorScheme.onSurfaceVariant,
      _ => theme.colorScheme.primary,
    };
    const mono = TextStyle(
      fontFamily: 'Consolas',
      fontSize: 12.5,
      height: 1.45,
    );
    final t = e.time;
    // Log lines are English and stay left to right in every language.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text.rich(
        TextSpan(
          style: mono.copyWith(color: theme.colorScheme.onSurface),
          children: [
            if (t != null)
              TextSpan(
                text:
                    '${formatTime(t)}:${t.second.toString().padLeft(2, '0')}  ',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            TextSpan(
              text: '${e.level.padRight(5)}  ',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: e.message),
          ],
        ),
      ),
    );
  }
}
