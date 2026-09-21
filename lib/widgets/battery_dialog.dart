import 'package:adpocket/core/settings.dart';
import 'package:adpocket/services/battery_guard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Explains why the widget needs a battery exemption and opens the system
/// dialog. Returns true when the user chose "Allow".
Future<bool> showBatteryDialog(BuildContext context) async {
  final s = context.read<AppSettings>().strings;
  final vendor = await BatteryGuard.manufacturer();
  final hintKey = BatteryGuard.hintKey(vendor);
  if (!context.mounted) return false;
  final scheme = Theme.of(context).colorScheme;
  final choice = await showDialog<String>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(s['battery.title']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s['battery.body']),
              if (hintKey != null) ...[
                const SizedBox(height: 12),
                Text(
                  s[hintKey],
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'later'),
              child: Text(s['battery.later']),
            ),
            if (hintKey != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'settings'),
                child: Text(s['battery.openSettings']),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'allow'),
              child: Text(s['battery.allow']),
            ),
          ],
        ),
  );
  switch (choice) {
    case 'allow':
      final launched = await BatteryGuard.requestExemption();
      if (!launched) await BatteryGuard.openAppSettings();
      return true;
    case 'settings':
      await BatteryGuard.openAppSettings();
      return false;
    default:
      return false;
  }
}
