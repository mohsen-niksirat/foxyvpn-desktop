import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ports.dart';
import '../l10n/app_localizations.dart';

/// Asks for a port: in place of [taken], with a free one filled in, or to
/// change the [current] one, starting from it. The chosen port, or null
/// when the user cancels or keeps the current one.
Future<int?> showPortDialog(
  BuildContext context, {
  String? taken,
  String? current,
}) => showDialog<int>(
  context: context,
  builder: (_) => _PortDialog(taken: taken, current: current),
);

class _PortDialog extends StatefulWidget {
  const _PortDialog({this.taken, this.current});

  /// The taken address or port, as the core reported it.
  final String? taken;

  /// The address or port in use now, to change.
  final String? current;

  @override
  State<_PortDialog> createState() => _PortDialogState();
}

class _PortDialogState extends State<_PortDialog> {
  final _field = TextEditingController();
  String? _error;
  bool _checking = false;

  bool get _changing => widget.current != null;

  /// The taken port, or the current one when changing it.
  int get _takenPort {
    final given = widget.current ?? widget.taken ?? '';
    return portOf(given) ?? int.tryParse(given) ?? 10810;
  }

  @override
  void initState() {
    super.initState();
    if (_changing) {
      _field.text = '$_takenPort';
      _field.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _field.text.length,
      );
      return;
    }
    findFreePort(_takenPort).then((port) {
      if (mounted && _field.text.isEmpty) _field.text = '$port';
    });
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final port = int.tryParse(_field.text.trim());
    if (port == null || !validPort(port)) {
      setState(() => _error = l.portInvalid);
      return;
    }
    // The current port stays: nothing to change.
    if (_changing && port == _takenPort) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _checking = true);
    final free = port == _takenPort ? false : await isFree(port);
    if (!mounted) return;
    setState(() => _checking = false);
    if (!free) {
      setState(() => _error = _changing ? l.portInUse : l.portBusy);
      return;
    }
    Navigator.of(context).pop(port);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.settings_ethernet_rounded),
      title: Text(l.portDialogTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _changing ? l.portChangeBody : l.portDialogBody('$_takenPort'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _field,
              autofocus: true,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.portLabel,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: Text(l.save),
        ),
      ],
    );
  }
}
