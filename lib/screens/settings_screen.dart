import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adpocket/core/app_lock.dart';
import 'package:adpocket/core/layout.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/screens/token_screen.dart';
import 'package:adpocket/services/report_cache.dart';
import 'package:adpocket/services/widget_service.dart';
import 'package:adpocket/services/battery_guard.dart';
import 'package:adpocket/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:adpocket/widgets/account_switcher.dart';
import 'package:adpocket/widgets/battery_dialog.dart';
import 'package:adpocket/widgets/section_card.dart';

const _docsUrl = 'https://yandex.ru/dev/partner-statistics/doc/';

/// Published from docs/privacy-site (GitHub Pages); update when the site moves.
const privacyPolicyUrl =
    'https://roberttadevosyan.github.io/privacy/app.adpocket.yan/';

class SettingsScreen extends StatelessWidget {
  final AppLockService? lockService;
  const SettingsScreen({this.lockService, super.key});

  Future<void> _toggleNotification(
    BuildContext context,
    AppSettings settings,
    bool enable,
    Future<void> Function(bool) setter,
  ) async {
    final s = settings.strings;
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<AppSession>();
    if (enable && !await NotificationService.requestPermission()) {
      messenger.showSnackBar(SnackBar(content: Text(s['notif.denied'])));
      return;
    }
    await setter(enable);
    await _rescheduleNotifications(session, settings);
  }

  Future<void> _rescheduleNotifications(
    AppSession session,
    AppSettings settings,
  ) async {
    if (!settings.anyNotifications) {
      await NotificationService.cancelAll();
      return;
    }
    final data = await ReportCache.loadDashboard(accountId: session.accountId);
    if (data != null) await NotificationService.onDataRefreshed(data, settings);
  }

  Future<void> _accountAction(
    BuildContext context,
    AppSession session,
    AppSettings settings,
    String id,
    String action,
  ) async {
    final s = settings.strings;
    final account = session.accounts.firstWhere((a) => a.id == id);
    switch (action) {
      case 'rename':
        final ctrl = TextEditingController(text: account.label);
        final name = await showDialog<String>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(s['acc.rename']),
                content: TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: s['acc.label']),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s['rep.cancel']),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    child: Text(s['rep.save']),
                  ),
                ],
              ),
        );
        if (name != null) await session.renameAccount(id, name);
      case 'replace':
        if (id != session.accountId) await session.switchAccount(id);
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TokenScreen(mode: TokenScreenMode.replace),
            ),
          );
        }
      case 'remove':
        final ok = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(s['acc.remove']),
                content: Text(s['acc.removeConfirm']),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(s['rep.cancel']),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(s['acc.remove']),
                  ),
                ],
              ),
        );
        if (ok == true) {
          await session.removeAccount(id);
          if (!session.isSignedIn) {
            await WidgetService.onSignedOut(lang: settings.lang);
          } else {
            final cached = await ReportCache.loadDashboard(
              accountId: session.accountId,
            );
            await WidgetService.push(
              cached,
              lang: settings.lang,
              currency: settings.currency,
              vat: settings.vat,
            );
          }
        }
    }
  }

  Future<void> _addWidget(BuildContext context, AppSettings settings) async {
    final s = settings.strings;
    final messenger = ScaffoldMessenger.of(context);
    final accountId = context.read<AppSession>().accountId;
    if (await WidgetService.installedCount() > 0) {
      messenger.showSnackBar(SnackBar(content: Text(s['set.widgetAlready'])));
      return;
    }
    if (!await WidgetService.canPin()) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            WidgetService.canRequestPin
                ? s['set.widgetPinUnsupported']
                : s['set.widgetIosHint'],
          ),
        ),
      );
      final cached = await ReportCache.loadDashboard(accountId: accountId);
      await WidgetService.push(
        cached,
        lang: settings.lang,
        currency: settings.currency,
        vat: settings.vat,
      );
      return;
    }
    // Make sure the widget has something to show and keeps refreshing.
    await settings.setWidgetRefresh(true);
    await WidgetService.setBackgroundRefresh(true);
    if (context.mounted && !await BatteryGuard.isExempt() && context.mounted) {
      await showBatteryDialog(context);
    }
    final cached = await ReportCache.loadDashboard(accountId: accountId);
    await WidgetService.push(
      cached,
      lang: settings.lang,
      currency: settings.currency,
      vat: settings.vat,
    );
    await WidgetService.requestPin();
  }

  Future<void> _refreshWidget(
    BuildContext context,
    AppSettings settings,
  ) async {
    final s = settings.strings;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WidgetService.refreshFromNetwork();
      messenger.showSnackBar(SnackBar(content: Text(s['set.widgetUpdated'])));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${s['common.error']}: $e')),
      );
    }
  }

  /// Enabling or disabling the lock requires a successful authentication,
  /// so nobody can switch it off without the device credential.
  Future<void> _toggleAppLock(
    BuildContext context,
    AppSettings settings,
    bool enable,
  ) async {
    final s = settings.strings;
    final service = lockService ?? AppLockService();
    final messenger = ScaffoldMessenger.of(context);
    if (!await service.isAvailable()) {
      messenger.showSnackBar(
        SnackBar(content: Text(s['set.appLockUnavailable'])),
      );
      return;
    }
    final ok = await service.authenticate(s['lock.reason']);
    if (ok) await settings.setAppLock(enable);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final session = context.watch<AppSession>();
    final s = settings.strings;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s['set.title'])),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SectionCard(
              title: s['acc.title'],
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Column(
                children: [
                  for (final a in session.accounts)
                    AccountTile(
                      account: a,
                      selected: a.id == session.accountId,
                      onTap:
                          a.id == session.accountId
                              ? null
                              : () => session.switchAccount(a.id),
                      trailing: PopupMenuButton<String>(
                        onSelected:
                            (v) => _accountAction(
                              context,
                              session,
                              settings,
                              a.id,
                              v,
                            ),
                        itemBuilder:
                            (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(s['acc.rename']),
                              ),
                              PopupMenuItem(
                                value: 'replace',
                                child: Text(s['set.changeToken']),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  s['acc.remove'],
                                  style: TextStyle(color: scheme.error),
                                ),
                              ),
                            ],
                      ),
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.person_add_alt_1_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: Text(s['acc.add']),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => const TokenScreen(
                                  mode: TokenScreenMode.add,
                                ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: s['set.display'],
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language),
                    title: Text(s['set.language']),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ru', label: Text('RU')),
                        ButtonSegment(value: 'en', label: Text('EN')),
                      ],
                      selected: {settings.lang},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => settings.setLang(v.first),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.currency_exchange),
                    title: Text(s['set.currency']),
                    trailing: DropdownButton<String>(
                      value: settings.currency,
                      underline: const SizedBox.shrink(),
                      items:
                          AppSettings.currencies
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                      onChanged:
                          (v) => v == null ? null : settings.setCurrency(v),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.receipt_long),
                    title: Text(s['set.vat']),
                    subtitle: Text(s['set.vatHint']),
                    value: settings.vat,
                    onChanged: settings.setVat,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.brightness_6),
                    title: Text(s['set.theme']),
                    trailing: DropdownButton<ThemeMode>(
                      value: settings.themeMode,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(s['set.theme.system']),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(s['set.theme.light']),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(s['set.theme.dark']),
                        ),
                      ],
                      onChanged:
                          (v) => v == null ? null : settings.setThemeMode(v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: s['set.security'],
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(s['set.appLock']),
                    subtitle: Text(s['set.appLockHint']),
                    value: settings.appLock,
                    onChanged: (v) => _toggleAppLock(context, settings, v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(
                      s['set.secureNote'],
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (WidgetService.supported) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: s['set.widgets'],
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    FutureBuilder<int>(
                      future: WidgetService.installedCount(),
                      builder: (context, snap) {
                        final n = snap.data ?? 0;
                        final hint =
                            n > 0
                                ? s['set.widgetCount'].replaceFirst('%d', '$n')
                                : s['set.widgetAddHint'];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.widgets_outlined),
                          title: Text(s['set.widgetAdd']),
                          subtitle: Text(hint),
                          trailing: Icon(
                            n > 0
                                ? Icons.check_circle_outline
                                : Icons.add_circle_outline,
                          ),
                          onTap: () => _addWidget(context, settings),
                        );
                      },
                    ),
                    if (WidgetService.hasBackgroundJob) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.autorenew),
                        title: Text(s['set.widgetRefresh']),
                        subtitle: Text(s['set.widgetRefreshHint']),
                        value: settings.widgetRefresh,
                        onChanged: (v) async {
                          await settings.setWidgetRefresh(v);
                          await WidgetService.setBackgroundRefresh(v);
                          if (v &&
                              context.mounted &&
                              !await BatteryGuard.isExempt() &&
                              context.mounted) {
                            await showBatteryDialog(context);
                          }
                        },
                      ),
                      if (BatteryGuard.supported)
                        FutureBuilder<bool>(
                          future: BatteryGuard.isExempt(),
                          builder: (context, snap) {
                            final exempt = snap.data ?? true;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                exempt
                                    ? Icons.battery_charging_full
                                    : Icons.battery_alert,
                                color: exempt ? null : scheme.error,
                              ),
                              title: Text(s['battery.status']),
                              subtitle: Text(
                                exempt
                                    ? s['battery.ok']
                                    : s['battery.restricted'],
                              ),
                              trailing:
                                  exempt
                                      ? null
                                      : const Icon(Icons.chevron_right),
                              onTap:
                                  exempt
                                      ? null
                                      : () => showBatteryDialog(context),
                            );
                          },
                        ),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.refresh),
                      title: Text(s['set.widgetRefreshNow']),
                      onTap: () => _refreshWidget(context, settings),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        WidgetService.canRequestPin
                            ? s['set.widgetRemoveHint']
                            : s['set.widgetIosHint'],
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (NotificationService.supported) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: s['notif.section'],
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.today_outlined),
                      title: Text(s['notif.daily']),
                      subtitle: Text(s['notif.dailyHint']),
                      value: settings.notifyDaily,
                      onChanged:
                          (v) => _toggleNotification(
                            context,
                            settings,
                            v,
                            settings.setNotifyDaily,
                          ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.calendar_month_outlined),
                      title: Text(s['notif.monthly']),
                      subtitle: Text(s['notif.monthlyHint']),
                      value: settings.notifyMonthly,
                      onChanged:
                          (v) => _toggleNotification(
                            context,
                            settings,
                            v,
                            settings.setNotifyMonthly,
                          ),
                    ),
                    if (settings.notifyDaily || settings.notifyMonthly)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule),
                        title: Text(s['notif.time']),
                        trailing: Text(
                          '${settings.notifyHour.toString().padLeft(2, '0')}:${settings.notifyMinute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: settings.notifyHour,
                              minute: settings.notifyMinute,
                            ),
                          );
                          if (picked == null) return;
                          await settings.setNotifyTime(
                            picked.hour,
                            picked.minute,
                          );
                          await _rescheduleNotifications(session, settings);
                        },
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.notification_important_outlined,
                      ),
                      title: Text(s['notif.alerts']),
                      subtitle: Text(s['notif.alertsHint']),
                      value: settings.notifyAlerts,
                      onChanged:
                          (v) => _toggleNotification(
                            context,
                            settings,
                            v,
                            settings.setNotifyAlerts,
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        WidgetService.hasBackgroundJob
                            ? s['notif.androidHint']
                            : s['notif.iosHint'],
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (kDebugMode)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bug_report_outlined),
                        title: Text(s['notif.test']),
                        onTap: () async {
                          if (!await NotificationService.requestPermission()) {
                            return;
                          }
                          final data = await ReportCache.loadDashboard(
                            accountId: session.accountId,
                          );
                          if (data != null) {
                            await NotificationService.showTest(data, settings);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SectionCard(
              title: s['set.about'],
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: Text(s['set.version']),
                    trailing: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder:
                          (_, snap) => Text(
                            snap.hasData
                                ? '${snap.data!.version} (${snap.data!.buildNumber})'
                                : '…',
                          ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.open_in_new),
                    title: Text(s['set.dashboard']),
                    onTap:
                        () => launchUrl(
                          Uri.parse(partnerDashboardUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(s['set.docs']),
                    onTap:
                        () => launchUrl(
                          Uri.parse(_docsUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(s['set.privacy']),
                    subtitle: Text(
                      s['set.notOfficial'],
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    onTap:
                        () => launchUrl(
                          Uri.parse(privacyPolicyUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: Text(s['set.clearCache']),
                    onTap: () async {
                      await ReportCache.clearDashboard(
                        accountId: session.accountId,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s['set.cacheCleared'])),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
