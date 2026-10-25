import 'package:flutter/material.dart';

import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../platform.dart';
import 'format.dart';
import 'signin_dialog.dart';
import 'widgets.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final list = core.accounts?.accounts ?? const <Account>[];
    final threshold = core.accounts?.thresholdPercent ?? 0;
    return ListView(
      padding: pagePadding(context),
      children: [
        Row(
          children: [
            Expanded(child: PageTitle(l.navAccounts)),
            FilledButton.icon(
              onPressed: () => showSignInDialog(context, core),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.addAccount),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (core.accounts == null)
          const Center(child: CircularProgressIndicator())
        else if (list.isEmpty)
          Panel(
            // Across the whole panel, so its middle is the panel's.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Icon(
                    Icons.group_add_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.noAccounts,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.noAccountsHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _AccountCard(
              core: core,
              account: list[i],
              threshold: threshold,
              first: i == 0,
              last: i == list.length - 1,
            ),
          ],
        // More accounts, more data: each has its own month's allowance,
        // and the app moves to the next one by itself.
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [
                  l.accountsGuide(_allowance(list)),
                  if (list.length > 1) l.accountsOrderNote(threshold.round()),
                ].join(' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _CreateAccountGuide(),
      ],
    );
  }
}

/// Why an account is out of the rotation, in the user's language; the
/// core's English for a reason the app does not know; null for none.
/// [threshold] is the account-switch setting, in percent.
String? accountReason(AppLocalizations l, Account a, double threshold) {
  final time = a.retryAt == null ? null : formatTime(a.retryAt!.toLocal());
  final detail = a.reasonDetail.isEmpty ? null : ltr(a.reasonDetail);
  final known = switch (a.reasonCode) {
    'quota_threshold' => l.reasonQuotaThreshold(
      (threshold > 0 ? threshold : 95).round(),
    ),
    'quota_exhausted' => l.reasonQuotaExhausted,
    'signin_required' => l.reasonSignInRequired,
    'signin_confirm' => l.reasonSignInConfirm,
    'signin_failed' when detail != null => l.reasonSignInFailed(detail),
    'signin_wait' when time != null => l.reasonSignInWait(time),
    'signin_retry' when detail != null && time != null => l.reasonSignInRetry(
      detail,
      time,
    ),
    'not_entitled' => l.reasonNotEntitled,
    _ => null,
  };
  return known ?? (a.reason.isEmpty ? null : a.reason);
}

/// An account's monthly allowance as the accounts report it (50 GB until
/// one has been read).
String _allowance(List<Account> list) {
  final limit =
      list
          .map((a) => a.usage?.limitBytes ?? 0)
          .where((b) => b > 0)
          .firstOrNull ??
      50 << 30;
  return formatBytes(limit).replaceAll('.0 ', ' ');
}

/// Where to make a Firefox Account: Mozilla's site, then Add account here.
class _CreateAccountGuide extends StatelessWidget {
  const _CreateAccountGuide();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.createAccountTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  l.createAccountHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  onPressed: () => openUrl(firefoxAccountSignUpUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  // The address reads left to right in every language.
                  label: Text(
                    'accounts.firefox.com',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.core,
    required this.account,
    required this.threshold,
    required this.first,
    required this.last,
  });

  final CoreController core;
  final Account account;
  final double threshold;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = account;
    final busy = core.busyAccounts.contains(a.id);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final usage = a.usage;
    return Opacity(
      opacity: a.enabled ? 1 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: a.active
              ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            // A phone: the controls go under the account.
            final narrow = box.maxWidth < 520;
            // What the account needs now, beside its name on a computer, so
            // every card's bar is as wide and the threshold marks line up.
            final Widget? action = busy
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : a.needsSignIn
                ? FilledButton.tonal(
                    onPressed: () => _signInAgain(context),
                    child: Text(l.signInAgain),
                  )
                : !a.active && a.enabled && a.status == AccountStatus.ready
                ? OutlinedButton(
                    onPressed: () =>
                        runShowingErrors(context, () => core.activate(a)),
                    child: Text(l.useNow),
                  )
                : null;
            final controls = <Widget>[
              Tooltip(
                message: a.enabled ? l.statusEnabled : l.statusDisabled,
                child: Switch(
                  value: a.enabled,
                  onChanged: busy
                      ? null
                      : (v) => runShowingErrors(
                          context,
                          () => core.setEnabled(a, v),
                        ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l.more,
                enabled: !busy,
                onSelected: (v) => switch (v) {
                  'refresh' => runShowingErrors(
                    context,
                    () => core.refreshQuota(a),
                  ),
                  'remove' => _remove(context),
                  _ => null,
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: const Icon(Icons.sync_rounded),
                      title: Text(l.refreshQuota),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(l.remove),
                    ),
                  ),
                ],
              ),
            ];
            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 14, 16, 14),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l.moveUp,
                        onPressed: first || busy
                            ? null
                            : () => runShowingErrors(
                                context,
                                () => core.move(a, -1),
                              ),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      Text('${a.position}', style: theme.textTheme.titleMedium),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l.moveDown,
                        onPressed: last || busy
                            ? null
                            : () => runShowingErrors(
                                context,
                                () => core.move(a, 1),
                              ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // The name takes all the room the button leaves.
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      a.name,
                                      style: theme.textTheme.titleMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _StatusPill(account: a),
                                ],
                              ),
                            ),
                            if (!narrow && action != null) ...[
                              const SizedBox(width: 12),
                              action,
                            ],
                          ],
                        ),
                        if (a.name != a.email && a.email.isNotEmpty)
                          Text(a.email, style: muted),
                        if (accountReason(l, a, threshold)
                            case final reason?) ...[
                          const SizedBox(height: 4),
                          Text(reason, style: muted),
                        ],
                        const SizedBox(height: 12),
                        if (usage == null)
                          Text(l.quotaNotRead, style: muted)
                        else if (usage.unlimited)
                          Text(l.unlimitedQuota, style: muted)
                        else ...[
                          QuotaBar(
                            percent: a.usedPercent,
                            threshold: threshold,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              l.usedOf(
                                formatBytes(usage.usedBytes),
                                formatBytes(usage.limitBytes),
                              ),
                              if (usage.resetAt != null)
                                l.resets(formatDate(l, usage.resetAt!)),
                            ].join(' · '),
                            style: muted,
                          ),
                        ],
                        if (narrow) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (action != null) ...[
                                action,
                                const SizedBox(width: 8),
                              ],
                              ...controls,
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!narrow) ...[const SizedBox(width: 16), ...controls],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Signs in with the stored password; without one, asks for it.
  Future<void> _signInAgain(BuildContext context) async {
    final api = core.api;
    if (api == null) return;
    try {
      final started = await api.startSignInAgain(account.id);
      if (context.mounted) {
        await showSignInDialog(context, core, started: started);
      }
    } on CoreApiException catch (e) {
      if (!context.mounted) return;
      if (e.statusCode == 409) {
        await showSignInDialog(context, core, email: account.email);
      } else {
        showError(context, e.message);
      }
    } on CoreUnavailable catch (e) {
      if (context.mounted) {
        showError(context, describeProblem(AppLocalizations.of(context), e));
      }
    }
  }

  Future<void> _remove(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeTitle),
        content: Text(l.removeBody(account.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StatusColors.bad),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runShowingErrors(context, () => core.remove(account));
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = account;
    if (!a.enabled) return Pill(l.statusDisabled);
    if (a.active) {
      return Pill(
        l.statusActive,
        color: StatusColors.good,
        icon: Icons.bolt_rounded,
      );
    }
    return switch (a.status) {
      AccountStatus.ready => Pill(
        l.statusReady,
        color: Theme.of(context).colorScheme.primary,
      ),
      AccountStatus.reauthRequired => Pill(
        l.statusNeedsSignIn,
        color: StatusColors.bad,
      ),
      AccountStatus.reserved => Pill(
        l.statusReserved,
        color: StatusColors.busy,
      ),
      AccountStatus.unavailable => Pill(
        a.retryAt != null
            ? l.statusUnavailableUntil(formatDate(l, a.retryAt!))
            : l.statusUnavailable,
        color: StatusColors.busy,
      ),
      _ => Pill(a.status),
    };
  }
}
