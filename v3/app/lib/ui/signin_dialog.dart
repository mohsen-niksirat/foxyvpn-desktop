import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../platform.dart';
import 'format.dart';
import 'widgets.dart';

/// Adds an account, or signs one in again: the core runs the sign-in and
/// the dialog shows whatever Mozilla asks for (codes, CAPTCHA, a link).
Future<void> showSignInDialog(
  BuildContext context,
  CoreController core, {
  String email = '',
  SignInState? started,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _SignInDialog(core: core, email: email, started: started),
);

class _SignInDialog extends StatefulWidget {
  const _SignInDialog({required this.core, required this.email, this.started});

  final CoreController core;
  final String email;
  final SignInState? started;

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  final _answer = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  SignInState? _state;
  String? _error;

  /// A sign-in started from the form whose password Mozilla has not
  /// accepted yet: the form stays (with the button busy) until it does,
  /// so a password manager is asked to save only a password that works.
  SignInState? _checking;

  /// A failure the person fixes in the form ([_formProblems]): its code
  /// and the core's text.
  String _formProblem = '';
  String _formProblemText = '';
  bool _sending = false;
  bool _showPassword = false;
  Timer? _poll;

  CoreApi? get _api => widget.core.api;

  @override
  void initState() {
    super.initState();
    if (widget.started != null) _follow(widget.started!);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _email.dispose();
    _password.dispose();
    _answer.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Failures of what was typed (a mistyped password or email): the form
  /// comes back with the fields as they were, to fix and send again.
  static const _formProblems = {
    SignInError.wrongPassword,
    SignInError.noAccount,
  };

  void _follow(SignInState s) {
    _poll?.cancel();
    final fromForm = _checking != null;
    _checking = null;
    if (s.step == SignInStep.failed && _formProblems.contains(s.errorCode)) {
      _state = null;
      _formProblem = s.errorCode;
      _formProblemText = s.error;
      final wrongPassword = s.errorCode == SignInError.wrongPassword;
      final field = wrongPassword ? _password : _email;
      final focus = wrongPassword ? _passwordFocus : _emailFocus;
      field.selection = TextSelection.collapsed(offset: field.text.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus.requestFocus();
      });
      return;
    }
    if (fromForm) {
      if (s.passwordAccepted) {
        // The fields are still there: the phone's password manager (Android
        // autofill) may now offer to save them, or update a saved password.
        TextInput.finishAutofillContext();
      } else if (s.step == SignInStep.working) {
        _checking = s;
        _poll = Timer.periodic(const Duration(seconds: 1), (_) => _read());
        return;
      }
      // Otherwise Mozilla asks for something first (a CAPTCHA, an unblock
      // code) or the sign-in failed: nothing is offered for saving.
    }
    _state = s;
    if (s.finished) {
      if (s.step == SignInStep.done) {
        _password.clear();
        widget.core.refresh(accountsToo: true);
      }
      return;
    }
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _read());
  }

  Future<void> _read() async {
    final id = (_state ?? _checking)?.id;
    final api = _api;
    if (id == null || api == null) return;
    try {
      final next = await api.signInState(id);
      if (!mounted) return;
      // Keep a typed answer while the step stays the same.
      if (next.step != _state?.step) _answer.clear();
      setState(() => _follow(next));
    } on Exception {
      // The next tick retries; the core may be busy.
    }
  }

  Future<void> _send(Future<SignInState> Function(CoreApi api) call) async {
    final api = _api;
    if (api == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final next = await call(api);
      if (!mounted) return;
      setState(() => _follow(next));
    } on CoreApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on CoreUnavailable catch (e) {
      if (mounted) {
        setState(
          () => _error = describeProblem(AppLocalizations.of(context), e),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _start() {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
    _formProblem = '';
    _send((api) async {
      final started = await api.startSignIn(email, password);
      // Marks the sign-in as the form's, for _follow.
      _checking = started;
      return started;
    });
  }

  void _submitAnswer() {
    final value = _answer.text.trim();
    final id = _state?.id;
    if (value.isEmpty || id == null) return;
    _send((api) => api.answerSignIn(id, value));
  }

  Future<void> _close() async {
    final s = _state ?? _checking;
    if (s != null && !s.finished) {
      try {
        await _api?.cancelSignIn(s.id);
      } on Exception {
        // The core ends abandoned sign-ins itself.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _restart() => setState(() {
    _poll?.cancel();
    _state = null;
    _checking = null;
    _error = null;
    _formProblem = '';
    _answer.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = _state;
    final done = s?.step == SignInStep.done;
    final failed =
        s?.step == SignInStep.failed || s?.step == SignInStep.cancelled;
    // An account without a password (Google or Apple sign-in) cannot sign
    // in again as it is: the button opens Mozilla's page to set one.
    final noPassword = failed && s?.errorCode == SignInError.noPassword;
    return AlertDialog(
      // A phone's keyboard leaves little room: the content scrolls.
      scrollable: true,
      title: Text(
        s == null
            ? l.addAccount
            : (s.email.isEmpty ? l.signInTitle : ltr(s.email)),
      ),
      content: SizedBox(
        width: 400,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: s == null ? _credentials() : _progress(s),
        ),
      ),
      actions: [
        if (done)
          FilledButton(onPressed: _close, child: Text(l.done))
        else ...[
          TextButton(
            onPressed: _close,
            child: Text(failed ? l.close : l.cancel),
          ),
          if (noPassword)
            FilledButton.icon(
              onPressed: () => openUrl(firefoxAccountSetPasswordUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(l.setPasswordButton),
            )
          else if (failed)
            FilledButton(onPressed: _restart, child: Text(l.tryAgain))
          else if (s == null)
            FilledButton(
              onPressed: _sending || _checking != null ? null : _start,
              child: _sending || _checking != null
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.signIn),
            )
          else if (s.needsAnswer)
            FilledButton(
              onPressed: _sending ? null : _submitAnswer,
              child: Text(l.continueLabel),
            ),
        ],
      ],
    );
  }

  Widget _credentials() {
    final l = AppLocalizations.of(context);
    // The fields are a sign-in form for password managers: they can fill
    // it, and offer to save it when the user signs in (_start); leaving the
    // form otherwise saves nothing.
    return Form(
      key: _form,
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.signInIntro, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              focusNode: _emailFocus,
              autofocus: widget.email.isEmpty,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l.email,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').contains('@') ? null : l.emailInvalid,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              focusNode: _passwordFocus,
              autofocus: widget.email.isNotEmpty,
              obscureText: !_showPassword,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              // Passwords are typed left to right, also in Persian.
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l.password,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? l.hide : l.show,
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? l.passwordEmpty : null,
              onFieldSubmitted: (_) => _start(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(_error!),
            ] else if (_formProblem.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ErrorBox(_problem(l, _formProblem, _formProblemText)),
            ],
            // No Firefox Account has this email: how to make one.
            if (_formProblem == SignInError.noAccount) ...[
              const SizedBox(height: 12),
              Text(
                l.signInNoAccountHint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => openUrl(firefoxAccountSignUpUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(l.createAccountButton),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The instruction for a step in the app's language; the core's own
  /// message for steps the app does not know.
  String _instruction(AppLocalizations l, SignInState s) => switch (s.step) {
    SignInStep.needEmailCode => l.stepEmailCode(s.email),
    SignInStep.needTotp => l.stepTotp,
    SignInStep.needUnblockCode => l.stepUnblockCode(s.email),
    SignInStep.needCaptcha => l.stepCaptcha,
    SignInStep.needEmailLink => l.stepEmailLink(s.email),
    SignInStep.working => l.signingIn,
    SignInStep.failed => l.signInFailed,
    SignInStep.cancelled => l.signInCancelled,
    _ => s.message,
  };

  /// What went wrong, in the app's language; the core's own text for
  /// problems the app does not know.
  String _problem(AppLocalizations l, String code, String text) =>
      switch (code) {
        SignInError.noAccount => l.signInNoAccount,
        SignInError.wrongPassword => l.signInWrongPassword,
        SignInError.noPassword => l.signInNoPassword,
        SignInError.tooManyAttempts => l.signInTooManyAttempts,
        SignInError.unblockCodeRejected => l.signInUnblockRejected,
        SignInError.wrongCode => l.signInWrongCode,
        SignInError.wrongTotp => l.signInWrongTotp,
        SignInError.tooManyCodes => l.signInTooManyCodes,
        SignInError.timedOut => l.signInTimedOut,
        SignInError.network => l.signInNetwork,
        _ => text,
      };

  Widget _progress(SignInState s) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final instruction = _instruction(l, s);
    final error =
        _error ?? (s.error.isEmpty ? null : _problem(l, s.errorCode, s.error));
    final numericCode =
        s.step == SignInStep.needEmailCode || s.step == SignInStep.needTotp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.step == SignInStep.done)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.check_circle_rounded,
              color: StatusColors.good,
              size: 32,
            ),
            title: Text(l.accountReady),
            subtitle: Text(l.accountReadyHint),
          )
        else if (s.step == SignInStep.working ||
            s.step == SignInStep.needEmailLink)
          Row(
            children: [
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(instruction, style: theme.textTheme.bodyMedium),
              ),
            ],
          )
        else if (instruction.isNotEmpty)
          Text(instruction, style: theme.textTheme.bodyMedium),
        if (s.step == SignInStep.needCaptcha && s.captcha.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Captcha(dataUrl: s.captcha),
        ],
        if (s.needsAnswer) ...[
          const SizedBox(height: 16),
          TextField(
            // A new field for each step, so its keyboard is the step's.
            key: ValueKey(s.step),
            controller: _answer,
            autofocus: true,
            // A code from an email or an authenticator app, which the
            // phone may offer to fill; not the CAPTCHA's text.
            autofillHints: s.step == SignInStep.needCaptcha
                ? null
                : const [AutofillHints.oneTimeCode],
            // The emailed and the authenticator codes are digits: the
            // number keyboard, and nothing else is taken. (The unblock
            // code has letters too.)
            keyboardType: numericCode ? TextInputType.number : null,
            inputFormatters: numericCode ? const [_CodeDigits()] : null,
            textDirection: s.step == SignInStep.needCaptcha
                ? null
                : TextDirection.ltr,
            textAlign: numericCode ? TextAlign.center : TextAlign.start,
            style: numericCode
                ? theme.textTheme.titleLarge?.copyWith(letterSpacing: 6)
                : null,
            decoration: InputDecoration(
              labelText: s.step == SignInStep.needCaptcha
                  ? l.captchaLabel
                  : l.codeLabel,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submitAnswer(),
          ),
        ],
        if (error != null && s.step != SignInStep.done) ...[
          const SizedBox(height: 12),
          _ErrorBox(error),
        ],
      ],
    );
  }
}

/// Keeps the digits of a typed or pasted code and drops everything else
/// (spaces, dashes, letters); Persian and Arabic-Indic digits, which a
/// Persian or Arabic keyboard types, become 0-9.
class _CodeDigits extends TextInputFormatter {
  const _CodeDigits();

  static String? _digit(int rune) {
    if (rune >= 0x30 && rune <= 0x39) return String.fromCharCode(rune);
    if (rune >= 0x6F0 && rune <= 0x6F9) return '${rune - 0x6F0}';
    if (rune >= 0x660 && rune <= 0x669) return '${rune - 0x660}';
    return null;
  }

  static String _digits(String text) =>
      text.runes.map(_digit).whereType<String>().join();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = _digits(newValue.text);
    if (text == newValue.text) return newValue;
    // The cursor stays after the same digits it followed.
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final cursor = _digits(newValue.text.substring(0, end)).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

class _Captcha extends StatelessWidget {
  const _Captcha({required this.dataUrl});

  final String dataUrl;

  @override
  Widget build(BuildContext context) {
    final comma = dataUrl.indexOf(',');
    try {
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, height: 120, fit: BoxFit.contain),
      );
    } on FormatException {
      return _ErrorBox(AppLocalizations.of(context).captchaBroken);
    }
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: StatusColors.bad.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: StatusColors.bad),
    ),
  );
}
