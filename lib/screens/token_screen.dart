import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adpocket/core/layout.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/widget_service.dart';
import 'package:adpocket/theme.dart';
import 'package:adpocket/widgets/section_card.dart';

const partnerDashboardUrl = 'https://partner.yandex.ru/v2/dashboard/';

enum TokenScreenMode { onboarding, add, replace }

/// Onboarding / add-account / replace-token screen: explains where the token
/// comes from, validates it and stores it.
class TokenScreen extends StatefulWidget {
  final TokenScreenMode mode;
  const TokenScreen({this.mode = TokenScreenMode.onboarding, super.key});

  bool get replaceMode => mode == TokenScreenMode.replace;
  bool get popsOnSuccess => mode != TokenScreenMode.onboarding;

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  final _controller = TextEditingController();
  final _labelController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.read<AppSettings>().strings;
    final session = context.read<AppSession>();
    final token = _controller.text.trim();
    if (token.isEmpty) {
      setState(() => _error = s['token.empty']);
      return;
    }
    final widgetRefreshEnabled = context.read<AppSettings>().widgetRefresh;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final login = await session.api.validateToken(token);
      if (widget.replaceMode && session.accountId != null) {
        await session.replaceToken(session.accountId!, token);
      } else {
        final label =
            _labelController.text.trim().isNotEmpty
                ? _labelController.text.trim()
                : login;
        await session.addAccount(token, label: label);
      }
      await WidgetService.onSignedIn(refreshEnabled: widgetRefreshEnabled);
      if (!mounted) return;
      if (widget.popsOnSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.replaceMode ? s['set.tokenSaved'] : s['acc.added'],
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      setState(
        () =>
            _error =
                e.isUnauthorized
                    ? s['token.invalid']
                    : e.isNetwork
                    ? s['common.noInternet']
                    : '${s['common.error']}: ${e.message}',
      );
    } catch (e) {
      setState(() => _error = '${s['common.error']}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final s = settings.strings;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.replaceMode
              ? s['set.changeToken']
              : widget.mode == TokenScreenMode.add
              ? s['acc.add']
              : s['app.title'],
        ),
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
                      color: Brand.amber,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: Brand.navy,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s['token.title'],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s['token.subtitle'],
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: s['token.field'],
                  errorText: _error,
                  errorMaxLines: 3,
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (!widget.replaceMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _labelController,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: s['acc.label'],
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child:
                    _busy
                        ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Brand.navy,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(s['token.checking']),
                          ],
                        )
                        : Text(s['token.continue']),
              ),
              const SizedBox(height: 24),
              SectionCard(
                title: s['token.howto'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 1; i <= 4; i++)
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
                            Expanded(child: Text(s['token.step$i'])),
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed:
                          () => launchUrl(
                            Uri.parse(partnerDashboardUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(s['token.open']),
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
