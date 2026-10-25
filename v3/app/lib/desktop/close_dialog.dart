import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../l10n/app_localizations.dart';

/// The user's answer to the close dialog.
typedef CloseChoice = ({CloseAction action, bool remember});

/// Asks whether closing the window minimizes the app to the tray or quits
/// it; null when the user cancels.
Future<CloseChoice?> showCloseDialog(BuildContext context) =>
    showDialog<CloseChoice>(
      context: context,
      builder: (_) => const _CloseDialog(),
    );

class _CloseDialog extends StatefulWidget {
  const _CloseDialog();

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  bool _remember = false;

  void _pick(CloseAction action) =>
      Navigator.of(context).pop((action: action, remember: _remember));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.power_settings_new_rounded),
      title: Text(l.closeTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.closeBody),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              title: Text(l.rememberChoice),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        OutlinedButton(
          onPressed: () => _pick(CloseAction.quit),
          child: Text(l.quit),
        ),
        FilledButton(
          onPressed: () => _pick(CloseAction.tray),
          child: Text(l.minimizeToTray),
        ),
      ],
    );
  }
}
