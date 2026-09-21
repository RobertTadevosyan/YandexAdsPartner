import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adpocket/core/formatters.dart';
import 'package:adpocket/core/layout.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/core/strings.dart';
import 'package:adpocket/models/ad_unit.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/theme.dart';
import 'package:adpocket/widgets/section_card.dart';
import 'package:adpocket/widgets/state_views.dart';

const _inventoryDocsUrl =
    'https://yandex.ru/dev/partner-statistics/doc/ru/reference/in-app-api';
const _partnerSupportUrl = 'https://partner.yandex.ru/v2/support/';
const _partnerUrl = 'https://partner.yandex.ru/v2/dashboard/';

/// Mobile ad units (Advertising Inventory Management API, beta).
class AdUnitsScreen extends StatefulWidget {
  const AdUnitsScreen({super.key});

  @override
  State<AdUnitsScreen> createState() => _AdUnitsScreenState();
}

class _AdUnitsScreenState extends State<AdUnitsScreen> {
  final _tokenCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  List<AdUnit>? _units;
  bool _archived = false;
  String? _loadedToken;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<AppSession>();
    if (session.hasInventoryToken && _loadedToken != session.inventoryToken) {
      _loadedToken = session.inventoryToken;
      _load();
    }
  }

  Future<void> _load() async {
    final session = context.read<AppSession>();
    final token = session.inventoryToken;
    if (token == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final units = await session.inventory.listAdUnits(
        token,
        statuses: [_archived ? 'ARCHIVED' : 'ENABLED'],
      );
      if (mounted) setState(() => _units = units);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final s = context.read<AppSettings>().strings;
    final session = context.read<AppSession>();
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _error = s['token.empty']);
      return;
    }
    if (token == session.token) {
      setState(() => _error = s['ad.wrongToken']);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final units = await session.inventory.listAdUnits(token);
      await session.setInventoryToken(token);
      _loadedToken = token;
      if (mounted) setState(() => _units = units);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () =>
              _error =
                  e.isUnauthorized
                      ? s['token.invalid']
                      : e.isNetwork
                      ? s['common.noInternet']
                      : e.message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openUnit(AdUnit unit) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdUnitDetailScreen(unit: unit)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final session = context.watch<AppSession>();
    final s = settings.strings;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(s['ad.title']),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Brand.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s['ad.beta'],
                style: const TextStyle(
                  fontSize: 11,
                  color: Brand.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (session.hasInventoryToken)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'refresh') _load();
                if (v == 'disconnect') {
                  await session.clearInventoryToken();
                  setState(() {
                    _units = null;
                    _loadedToken = null;
                  });
                }
              },
              itemBuilder:
                  (_) => [
                    PopupMenuItem(
                      value: 'refresh',
                      child: Text(s['dash.refresh']),
                    ),
                    PopupMenuItem(
                      value: 'disconnect',
                      child: Text(s['ad.disconnect']),
                    ),
                  ],
            ),
        ],
      ),
      body: PageBody(
        child:
            !session.hasInventoryToken
                ? _buildConnect(s, scheme)
                : _buildList(s, scheme, settings.lang),
      ),
    );
  }

  Widget _buildConnect(AppStrings s, ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.view_quilt_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s['ad.intro'],
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tokenCtrl,
                obscureText: _obscure,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: s['ad.tokenField'],
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
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _connect,
                child:
                    _busy
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Brand.navy,
                          ),
                        )
                        : Text(s['ad.connect']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: s['ad.howto'],
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
                      Expanded(child: Text(s['ad.step$i'])),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        () => launchUrl(
                          Uri.parse(_partnerSupportUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                    icon: const Icon(Icons.support_agent, size: 18),
                    label: Text(s['ad.openSupport']),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        () => launchUrl(
                          Uri.parse(_partnerUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(s['token.open']),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        () => launchUrl(
                          Uri.parse(_inventoryDocsUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: Text(s['ad.openDocs']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(AppStrings s, ColorScheme scheme, String lang) {
    final units = _units;
    final byApp = <num, List<AdUnit>>{};
    for (final u in units ?? const <AdUnit>[]) {
      byApp.putIfAbsent(u.applicationId, () => []).add(u);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(s['ad.enabled']),
                icon: const Icon(Icons.check_circle_outline, size: 16),
              ),
              ButtonSegment(
                value: true,
                label: Text(s['ad.archived']),
                icon: const Icon(Icons.archive_outlined, size: 16),
              ),
            ],
            selected: {_archived},
            showSelectedIcon: false,
            onSelectionChanged: (v) {
              setState(() => _archived = v.first);
              _load();
            },
          ),
          const SizedBox(height: 12),
          if (_busy && units == null)
            const LoadingView()
          else if (_error != null)
            ErrorView(
              title: s['ad.error'],
              details: _error,
              retryLabel: s['common.retry'],
              onRetry: _load,
            )
          else if (units == null || units.isEmpty)
            EmptyView(text: s['ad.empty'], icon: Icons.view_quilt_outlined)
          else
            for (final entry in byApp.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(
                  '${s['ad.app']} ${entry.key.toInt()}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0) const Divider(indent: 56),
                      _AdUnitTile(
                        unit: entry.value[i],
                        s: s,
                        lang: lang,
                        onTap: () => _openUnit(entry.value[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

IconData adUnitIcon(String kind) {
  switch (kind) {
    case 'interstitial':
      return Icons.fullscreen;
    case 'rewarded':
      return Icons.card_giftcard;
    case 'native':
      return Icons.article_outlined;
    case 'appopen':
      return Icons.open_in_full;
    default:
      return Icons.view_day_outlined;
  }
}

class _AdUnitTile extends StatelessWidget {
  final AdUnit unit;
  final AppStrings s;
  final String lang;
  final VoidCallback onTap;
  const _AdUnitTile({
    required this.unit,
    required this.s,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strategy = s['ad.strategy.${unit.strategy.type}'];
    final floor =
        unit.strategy.hasFloor && unit.strategy.minCpm != null
            ? ' · ${Fmt.money(unit.strategy.minCpm!, lang)}'
            : '';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(adUnitIcon(unit.kind), color: scheme.onSurface, size: 20),
      ),
      title: Text(
        unit.caption.isEmpty ? unit.id : unit.caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${s['ad.type.${unit.kind}']} · $strategy$floor\n${unit.id}',
        style: const TextStyle(fontSize: 12),
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Detail + edit form for one ad unit.
class AdUnitDetailScreen extends StatefulWidget {
  final AdUnit unit;
  const AdUnitDetailScreen({required this.unit, super.key});

  @override
  State<AdUnitDetailScreen> createState() => _AdUnitDetailScreenState();
}

class _AdUnitDetailScreenState extends State<AdUnitDetailScreen> {
  late AdUnit _unit = widget.unit;
  late final _captionCtrl = TextEditingController(text: widget.unit.caption);
  late final _floorCtrl = TextEditingController(
    text: widget.unit.strategy.minCpm?.toString() ?? '',
  );
  late String _strategyType = widget.unit.strategy.type;
  bool _busy = false;
  bool _changed = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    _floorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = context.read<AppSettings>().strings;
    final session = context.read<AppSession>();
    final token = session.inventoryToken;
    if (token == null) return;
    final floor = double.tryParse(_floorCtrl.text.replaceAll(',', '.'));
    final strategy = AdUnitStrategy(
      type: _strategyType,
      minCpm: _strategyType == 'MaxRevenueStrategy' ? null : floor,
    );
    if (strategy.hasFloor && strategy.minCpm == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s['ad.floor'])));
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await session.inventory.updateAdUnit(
        token,
        _unit,
        caption:
            _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
        strategy: strategy,
      );
      if (!mounted) return;
      setState(() {
        _unit = updated;
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s['ad.saved'])));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s['ad.error']}: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final s = context.read<AppSettings>().strings;
    final session = context.read<AppSession>();
    final token = session.inventoryToken;
    if (token == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(s['ad.archive']),
            content: Text(s['ad.archiveConfirm']),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s['rep.cancel']),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s['ad.archive']),
              ),
            ],
          ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await session.inventory.archiveAdUnit(token, _unit.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s['ad.archivedOk'])));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s['ad.error']}: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final s = settings.strings;
    final scheme = Theme.of(context).colorScheme;
    final unit = _unit;
    final canEdit = unit.editable && !unit.isArchived;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _changed) {
          // Result already delivered through pop(true) where applicable.
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(unit.caption.isEmpty ? unit.id : unit.caption),
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: PageBody(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          adUnitIcon(unit.kind),
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s['ad.type.${unit.kind}'],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Chip(
                          label: Text(
                            unit.isArchived
                                ? s['ad.archived']
                                : s['ad.enabled'],
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _kv(context, 'ID', unit.id, copy: true),
                    _kv(
                      context,
                      s['ad.app'],
                      unit.applicationId.toInt().toString(),
                    ),
                    if (unit.createDate != null)
                      _kv(
                        context,
                        s['ad.created'],
                        Fmt.date(unit.createDate!, settings.lang),
                      ),
                    if (unit.kind == 'rewarded' && unit.currencyType != null)
                      _kv(
                        context,
                        s['ad.reward'],
                        '${unit.currencyValue ?? ''} ${unit.currencyType}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: s['ad.edit'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!canEdit)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          s['ad.notEditable'],
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    TextField(
                      controller: _captionCtrl,
                      enabled: canEdit,
                      maxLength: 255,
                      decoration: InputDecoration(
                        labelText: s['ad.caption'],
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _strategyType,
                      decoration: InputDecoration(labelText: s['ad.strategy']),
                      items: [
                        for (final t in AdUnitStrategy.types)
                          DropdownMenuItem(
                            value: t,
                            child: Text(s['ad.strategy.$t']),
                          ),
                      ],
                      onChanged:
                          canEdit
                              ? (v) => setState(
                                () => _strategyType = v ?? _strategyType,
                              )
                              : null,
                    ),
                    if (_strategyType != 'MaxRevenueStrategy') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _floorCtrl,
                        enabled: canEdit,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: s['ad.floor']),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: canEdit && !_busy ? _save : null,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(s['rep.save']),
                    ),
                    if (canEdit) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _archive,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(color: scheme.error),
                        ),
                        icon: const Icon(Icons.archive_outlined),
                        label: Text(s['ad.archive']),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool copy = false}) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.read<AppSettings>().strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (copy)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: v));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(s['ad.copy'])));
              },
            ),
        ],
      ),
    );
  }
}
