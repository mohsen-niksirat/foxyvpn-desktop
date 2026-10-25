import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import 'widgets.dart';

/// The first run: the user picks a language and a country, and the
/// country's sites go directly (the core's routing region).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.core, required this.settings});

  final CoreController core;
  final AppSettings settings;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late String _language;
  late String _region;

  /// The region follows the language until the user picks one.
  bool _regionPicked = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final system = PlatformDispatcher.instance.locale;
    _language = widget.settings.language.isNotEmpty
        ? widget.settings.language
        : AppSettings.languageFor(system);
    _region = AppSettings.suggestedRegion(_language, system.countryCode);
  }

  void _pickLanguage(String language) {
    setState(() {
      _language = language;
      if (!_regionPicked) {
        _region = AppSettings.regionForLanguage(language) ?? _region;
      }
    });
    // Show the page in the chosen language at once.
    widget.settings.update(language: language);
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    final region = _region;
    await runShowingErrors(
      context,
      () => widget.core.editSettings((config) {
        final routing = config['routing'];
        if (routing is! Map<String, Object?>) return;
        routing['enabled'] = region.isNotEmpty;
        if (region.isNotEmpty) routing['region'] = region;
      }),
    );
    widget.settings.update(language: _language, firstRun: false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Panel(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.welcomeTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.welcomeBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: InputDecoration(
                      labelText: l.language,
                      prefixIcon: const Icon(Icons.translate_rounded),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => _pickLanguage(v!),
                    items: [
                      for (final code in AppSettings.supportedLanguages)
                        DropdownMenuItem(
                          value: code,
                          child: Text(
                            languageNames[code]!,
                            style: languageStyle(code),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_region),
                    initialValue: _region,
                    decoration: InputDecoration(
                      labelText: l.region,
                      helperText: l.routingDirectHint,
                      helperMaxLines: 3,
                      prefixIcon: const Icon(Icons.alt_route_rounded),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() {
                      _region = v!;
                      _regionPicked = true;
                    }),
                    items: [
                      for (final r in AppSettings.regions)
                        DropdownMenuItem(
                          value: r,
                          child: Text(regionName(l, r)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _saving ? null : _start,
                    child: Text(l.start),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
