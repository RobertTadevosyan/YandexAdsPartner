import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adpocket/core/app_lock.dart';
import 'package:adpocket/core/layout.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/services/admob_api_service.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/widget_service.dart';
import 'package:adpocket/theme.dart';
import 'package:adpocket/widgets/section_card.dart';

const admobConsoleUrl = 'https://admob.google.com/';

/// Adds an AdMob account: Google sign-in with read-only AdMob access, then
/// the publisher account to show. Laid out like the Yandex token screen, in
/// AdMob's colours. With [reconnect] it renews access for the active account.
class AdMobConnectScreen extends StatefulWidget {
  final bool reconnect;
  const AdMobConnectScreen({this.reconnect = false, super.key});

  @override
  State<AdMobConnectScreen> createState() => _AdMobConnectScreenState();
}

class _AdMobConnectScreenState extends State<AdMobConnectScreen> {
  final _labelController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final settings = context.read<AppSettings>();
    final s = settings.strings;
    final session = context.read<AppSession>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final grant = await LockGate.duringExternalFlow(
        session.admob.auth.signIn,
      );
      final publishers = await session.admob.listPublishers(grant.email);
      if (!mounted) return;
      if (publishers.isEmpty) {
        setState(() => _error = s['admob.noAccounts']);
        return;
      }
      final AdMobPublisher? picked =
          publishers.length == 1
              ? publishers.first
              : await showModalBottomSheet<AdMobPublisher>(
                context: context,
                showDragHandle: true,
                builder:
                    (ctx) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Text(
                              s['admob.pick'],
                              style: Theme.of(ctx).textTheme.titleMedium,
                            ),
                          ),
                          for (final p in publishers)
                            ListTile(
                              leading: const Icon(Icons.account_balance),
                              title: Text(p.publisherId),
                              subtitle: Text(p.currencyCode),
                              onTap: () => Navigator.pop(ctx, p),
                            ),
                        ],
                      ),
                    ),
              );
      if (picked == null || !mounted) return;
      final typed = _labelController.text.trim();
      await session.addAdMobAccount(
        publisherId: picked.publisherId,
        googleEmail: grant.email,
        label: typed.isNotEmpty ? typed : (grant.name ?? grant.email),
      );
      await WidgetService.onSignedIn(refreshEnabled: settings.widgetRefresh);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.reconnect ? s['admob.reconnected'] : s['acc.added'],
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // -1: the user closed Google's sheet.
      if (!mounted || e.statusCode == -1) return;
      setState(
        () =>
            _error =
                e.isNetwork
                    ? s['common.noInternet']
                    : e.statusCode == 403
                    ? s['admob.noAccess']
                    : '${s['common.error']}: ${e.message}',
      );
    } catch (e) {
      if (mounted) setState(() => _error = '${s['common.error']}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final s = settings.strings;
    final dark = switch (settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    return Theme(
      data: dark ? adMobDarkTheme : adMobLightTheme,
      child: Builder(builder: (context) => _body(context, s, settings)),
    );
  }

  Widget _body(BuildContext context, dynamic s, AppSettings settings) {
    final scheme = Theme.of(context).colorScheme;
    final brand = BrandPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reconnect ? s['admob.reconnect'] : s['acc.add']),
        actions: [
          TextButton(
            onPressed:
                () => settings.setLang(settings.lang == 'ru' ? 'en' : 'ru'),
            child: Text(settings.lang == 'ru' ? 'EN' : 'RU'),
          ),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [brand.heroStart, brand.heroEnd],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.bar_chart_rounded,
                      color: brand.onHero,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s['admob.title'],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s['admob.subtitle'],
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (!widget.reconnect) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _labelController,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: s['acc.label'],
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _connect,
                icon:
                    _busy
                        ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                        : const Icon(Icons.login),
                label: Text(_busy ? s['admob.connecting'] : s['admob.signIn']),
              ),
              const SizedBox(height: 24),
              SectionCard(
                title: s['admob.howto'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 1; i <= 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$i',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s['admob.step$i'])),
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed:
                          () => launchUrl(
                            Uri.parse(admobConsoleUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(s['admob.open']),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
