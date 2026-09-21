import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/models/account.dart';
import 'package:adpocket/screens/token_screen.dart';
import 'package:adpocket/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Round avatar of the active account; tap opens the account sheet.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final s = context.watch<AppSettings>().strings;
    final active = session.active;
    if (active == null) return const SizedBox.shrink();
    return Tooltip(
      message: active.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showAccountSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Brand.amber,
            child: Text(
              active.initials,
              style: const TextStyle(
                color: Brand.navy,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              semanticsLabel: s['acc.switchTo'],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final s = context.watch<AppSettings>().strings;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                s['acc.title'],
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          for (final a in session.accounts)
            AccountTile(
              account: a,
              selected: a.id == session.accountId,
              onTap: () async {
                Navigator.pop(context);
                await session.switchAccount(a.id);
              },
            ),
          ListTile(
            leading: Icon(
              Icons.person_add_alt_1_outlined,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(s['acc.add']),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TokenScreen(mode: TokenScreenMode.add),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class AccountTile extends StatelessWidget {
  final Account account;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  const AccountTile({
    required this.account,
    required this.selected,
    this.onTap,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>().strings;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor:
            selected ? Brand.amber : scheme.surfaceContainerHighest,
        child: Text(
          account.initials,
          style: TextStyle(
            color: selected ? Brand.navy : scheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(account.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        selected
            ? '${account.maskedToken} · ${s['acc.active']}'
            : account.maskedToken,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      trailing:
          trailing ??
          (selected
              ? const Icon(Icons.check_circle, color: Brand.amber)
              : null),
    );
  }
}
