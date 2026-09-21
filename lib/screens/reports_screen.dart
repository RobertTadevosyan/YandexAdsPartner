import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:adpocket/core/formatters.dart';
import 'package:adpocket/core/layout.dart';
import 'package:adpocket/core/period.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/core/strings.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/report_preset.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/models/stat_type.dart';
import 'package:adpocket/models/tree_catalog.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/report_cache.dart';
import 'package:adpocket/services/yandex_api_service.dart';
import 'package:adpocket/theme.dart';
import 'package:adpocket/widgets/period_chips.dart';
import 'package:adpocket/widgets/report_sheets.dart';
import 'package:adpocket/widgets/report_table.dart';
import 'package:adpocket/widgets/revenue_chart.dart';
import 'package:adpocket/widgets/section_card.dart';
import 'package:adpocket/widgets/state_views.dart';

const _pageSize = 50;

/// Full report builder mirroring the web dashboard's statistics page.
class ReportsScreen extends StatefulWidget {
  final ReportPreset? initialPreset;
  const ReportsScreen({this.initialPreset, super.key});

  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> {
  TreeCatalog? _catalog;
  String? _catalogLang;
  bool _catalogLoading = false;
  String? _catalogError;

  ReportPeriod _period = const ReportPeriod.preset(PeriodPreset.today);
  List<String> _metricIds = [];
  Map<String, String?> _groups = {};
  List<ReportFilter> _filters = [];
  OrderBy? _orderBy;
  StatType _statType = StatType.main;

  ReportResponse? _report;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  bool _chartMode = false;
  String? _chartMetric;
  List<ReportPreset> _presets = [];
  bool _restored = false;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.watch<AppSettings>().lang;
    final accountId = context.watch<AppSession>().accountId;
    if (_accountId != null && _accountId != accountId) {
      // Account switched: forget this account's report and load the other's.
      _accountId = accountId;
      _catalogLang = null;
      setState(() {
        _catalog = null;
        _report = null;
        _error = null;
        _orderBy = null;
        _metricIds = [];
        _groups = {};
        _filters = [];
        _statType = StatType.main;
      });
      _restore(applyInitial: false);
    }
    _accountId ??= accountId;
    if (_catalogLang != lang) {
      _catalogLang = lang;
      _loadCatalog(lang);
    }
  }

  Future<void> _restore({bool applyInitial = true}) async {
    final accountId = context.read<AppSession>().accountId;
    final raw = await ReportCache.loadReportConfig(accountId: accountId);
    _presets = await ReportCache.loadPresets(accountId: accountId);
    if (raw != null) {
      try {
        final preset = ReportPreset.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        _period = preset.period;
        _metricIds = preset.metricIds;
        _groups = preset.groups;
        _filters = preset.filters;
        _statType = preset.statType;
      } catch (_) {}
    }
    _restored = true;
    if (!mounted) return;
    if (applyInitial && widget.initialPreset != null) {
      applyPreset(widget.initialPreset!, run: true);
    } else if (mounted) {
      setState(() {});
      if (_catalog != null && _hasValidSelection) _run();
    }
  }

  Future<void> _persist() async {
    await ReportCache.saveReportConfig(
      jsonEncode(_buildPreset('').toJson()),
      accountId: context.read<AppSession>().accountId,
    );
  }

  Future<void> _loadCatalog(String lang) async {
    final session = context.read<AppSession>();
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    try {
      final statType = _statType;
      final catalog = await session.catalog(lang, statType: statType.value);
      if (!mounted || statType != _statType) return;
      setState(() {
        _catalog = catalog;
        _catalogLoading = false;
        // Drop selections that do not exist in this catalogue.
        _metricIds =
            _metricIds.where((id) => catalog.byId(id) != null).toList();
        _groups = Map.fromEntries(
          _groups.entries.where((e) => catalog.byId(e.key) != null),
        );
        if (_metricIds.isEmpty && catalog.metrics.isNotEmpty) {
          _metricIds = _defaultMetrics(catalog, statType);
        }
        if (_groups.isEmpty && catalog.dimensions.isNotEmpty) {
          final date = catalog.dimensions.firstWhere(
            (d) => d.id == 'date',
            orElse: () => catalog.dimensions.first,
          );
          _groups = {date.id: date.selectedChildId};
        }
      });
      if (_restored && _report == null && _hasValidSelection && !_loading) {
        _run();
      }
      if (_report != null) _run();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogLoading = false;
        _catalogError =
            e.isUnauthorized
                ? context.read<AppSettings>().strings['common.unauthorized']
                : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogLoading = false;
        _catalogError = e.toString();
      });
    }
  }

  bool get _hasValidSelection => _metricIds.isNotEmpty && _groups.isNotEmpty;

  static List<String> _defaultMetrics(TreeCatalog catalog, StatType type) {
    final preferred =
        type.preferredMetrics.where((id) => catalog.byId(id) != null).toList();
    if (preferred.isNotEmpty) return preferred;
    return catalog.metrics.take(3).map((m) => m.id).toList();
  }

  void _changeStatType(StatType type) {
    if (type == _statType) return;
    setState(() {
      _statType = type;
      _catalog = null;
      _report = null;
      _error = null;
      _orderBy = null;
      _metricIds = [];
      _groups = {};
      _filters = [];
    });
    _loadCatalog(context.read<AppSettings>().lang);
  }

  ReportPreset _buildPreset(String name) => ReportPreset(
    name: name,
    period: _period,
    metricIds: List.of(_metricIds),
    groups: Map.of(_groups),
    filters: List.of(_filters),
    statType: _statType,
  );

  /// Applies a preset (from the presets sheet or the dashboard) and runs it.
  void applyPreset(ReportPreset preset, {bool run = false}) {
    final typeChanged = preset.statType != _statType;
    setState(() {
      _period = preset.period;
      _metricIds = List.of(preset.metricIds);
      _groups = Map.of(preset.groups);
      _filters = List.of(preset.filters);
      _orderBy = null;
      _statType = preset.statType;
      if (typeChanged) {
        _catalog = null;
        _report = null;
      }
    });
    if (typeChanged) {
      _loadCatalog(context.read<AppSettings>().lang);
    } else if (run && _catalog != null) {
      _run();
    }
  }

  Map<String, String> get _dimensionFields => {
    for (final e in _groups.entries)
      if (e.value != null) e.key: e.value!,
  };

  List<String> get _entityFields => [
    for (final e in _groups.entries)
      if (e.value == null) e.key,
  ];

  Future<void> _run({bool append = false}) async {
    final settings = context.read<AppSettings>();
    final session = context.read<AppSession>();
    final s = settings.strings;
    final token = session.token;
    final accountId = session.accountId;
    if (token == null) return;
    if (!_hasValidSelection) {
      setState(() => _error = s['rep.needSelection']);
      return;
    }
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
      _persist();
    }
    try {
      final offset = append ? (_report?.points.length ?? 0) : 0;
      final response = await session.api.fetchReport(
        token: token,
        period: _period,
        fields: _metricIds,
        dimensionFields: _dimensionFields,
        entityFields: _entityFields,
        filters: _filters,
        orderBy:
            _orderBy ??
            (_dimensionFields.containsKey('date')
                ? const OrderBy('date', desc: true)
                : null),
        limit: _pageSize,
        offset: offset,
        lang: settings.lang,
        currency: settings.currency,
        vat: settings.vat,
        statType: _statType.value,
      );
      if (!mounted || session.accountId != accountId) return;
      setState(() {
        if (append && _report != null) {
          _report = _report!.copyWith(
            points: [..._report!.points, ...response.points],
            isLastPage: response.isLastPage,
          );
        } else {
          _report = response;
        }
        if (_chartMetric == null || !_metricIds.contains(_chartMetric)) {
          _chartMetric = _metricIds.first;
        }
      });
    } on ApiException catch (e) {
      if (!mounted || session.accountId != accountId) return;
      final message =
          e.isUnauthorized
              ? s['common.unauthorized']
              : (e.isNetwork ? s['common.noInternet'] : e.message);
      if (append) {
        // Keep the rows already on screen; just tell the user the next page failed.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } else {
        setState(() => _error = message);
      }
    } catch (e) {
      if (!mounted || session.accountId != accountId) return;
      if (append) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      } else {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _pickMetrics() async {
    final s = context.read<AppSettings>().strings;
    final catalog = _catalog;
    if (catalog == null) return;
    final result = await showAppSheet<List<String>>(
      context,
      MetricPickerSheet(metrics: catalog.metrics, selected: _metricIds, s: s),
    );
    if (result != null) setState(() => _metricIds = result);
  }

  Future<void> _pickGroups() async {
    final s = context.read<AppSettings>().strings;
    final catalog = _catalog;
    if (catalog == null) return;
    final result = await showAppSheet<Map<String, String?>>(
      context,
      GroupPickerSheet(catalog: catalog, selected: _groups, s: s),
    );
    if (result != null) {
      setState(() {
        _groups = result;
        _orderBy = null;
      });
    }
  }

  Future<void> _pickFilters() async {
    final s = context.read<AppSettings>().strings;
    final catalog = _catalog;
    if (catalog == null) return;
    final result = await showAppSheet<List<ReportFilter>>(
      context,
      FilterSheet(fields: catalog.filters, filters: _filters, s: s),
    );
    if (result != null) setState(() => _filters = result);
  }

  Future<void> _openPresets() async {
    final s = context.read<AppSettings>().strings;
    final accountId = context.read<AppSession>().accountId;
    final result = await showAppSheet<PresetSheetResult>(
      context,
      PresetSheet(presets: _presets, buildCurrent: _buildPreset, s: s),
    );
    if (result == null) return;
    _presets = result.presets;
    await ReportCache.savePresets(_presets, accountId: accountId);
    if (result.apply != null) {
      applyPreset(result.apply!, run: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s['rep.presetApplied'])));
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  void _reset() {
    setState(() {
      _filters = [];
      _orderBy = null;
      _period = const ReportPeriod.preset(PeriodPreset.today);
      final catalog = _catalog;
      if (catalog != null) {
        _metricIds = _defaultMetrics(catalog, _statType);
        if (catalog.dimensions.isNotEmpty) {
          final date = catalog.dimensions.firstWhere(
            (d) => d.id == 'date',
            orElse: () => catalog.dimensions.first,
          );
          _groups = {date.id: date.selectedChildId};
        }
      }
    });
  }

  List<ReportColumn> _columns(TreeCatalog catalog, ReportResponse report) {
    final cols = <ReportColumn>[];
    for (final e in _groups.entries) {
      final field = catalog.byId(e.key);
      final meta = report.dimensions[e.key];
      var title = meta?.title ?? field?.title ?? e.key;
      if (field != null && field.isDimension && e.value != null) {
        final child = field.copy(selectedChildId: e.value).selectedChildLabel;
        if (child != null) title = '$title, $child';
      }
      cols.add(ReportColumn(id: e.key, title: title, isMeasure: false));
    }
    for (final id in _metricIds) {
      final meta = report.measures[id];
      cols.add(
        ReportColumn(
          id: id,
          title: meta?.title ?? catalog.byId(id)?.title ?? id,
          isMeasure: true,
        ),
      );
    }
    return cols;
  }

  Future<void> _shareCsv(
    TreeCatalog catalog,
    ReportResponse report,
    AppStrings s,
    String lang,
  ) async {
    final cols = _columns(catalog, report);
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final buf = StringBuffer();
    buf.writeln(cols.map((c) => esc(c.title)).join(';'));
    for (final p in report.points) {
      buf.writeln(
        cols
            .map((c) {
              if (c.isMeasure) return (p.measures[c.id] ?? '').toString();
              return esc(p.dimensions[c.id] ?? '');
            })
            .join(';'),
      );
    }
    if (report.totals.isNotEmpty) {
      buf.writeln(
        cols
            .map((c) {
              if (c.isMeasure) return (report.totals[c.id] ?? '').toString();
              return c == cols.first ? esc(s['rep.totals']) : '';
            })
            .join(';'),
      );
    }
    final bytes = utf8.encode('﻿${buf.toString()}');
    final name = 'adpocket_${Fmt.isoDate(DateTime.now())}.csv';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
        fileNameOverrides: [name],
        text:
            '${s['rep.title']} · ${_period.label(lang)} · ${Fmt.count(report.points.length, lang)} ${s['rep.rows']}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final s = settings.strings;
    final lang = settings.lang;
    final scheme = Theme.of(context).colorScheme;
    final catalog = _catalog;
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: Text(s['rep.title']),
        actions: [
          IconButton(
            onPressed: _openPresets,
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: s['rep.presets'],
          ),
          if (report != null && report.points.isNotEmpty && catalog != null)
            IconButton(
              onPressed: () => _shareCsv(catalog, report, s, lang),
              icon: const Icon(Icons.ios_share),
              tooltip: s['rep.share'],
            ),
        ],
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                s['rep.type'],
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: StatType.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = StatType.values[i];
                  return ChoiceChip(
                    label: Text(t.label(lang)),
                    selected: _statType == t,
                    onSelected: (_) => _changeStatType(t),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                s['rep.period'],
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            PeriodChips(
              selected: _period,
              lang: lang,
              onChanged: (p) {
                setState(() => _period = p);
                if (_catalog != null) _run();
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
                  catalog == null
                      ? SectionCard(
                        child:
                            _catalogLoading
                                ? LoadingView(text: s['rep.loadingFields'])
                                : ErrorView(
                                  title: s['rep.fieldsError'],
                                  details: _catalogError,
                                  retryLabel: s['common.retry'],
                                  onRetry: () => _loadCatalog(lang),
                                ),
                      )
                      : _buildConfig(catalog, s, scheme),
            ),
            const SizedBox(height: 16),
            if (_loading)
              LoadingView(text: s['rep.results'])
            else if (_error != null)
              ErrorView(
                title: s['rep.error'],
                details: _error,
                retryLabel: s['rep.retry'],
                onRetry: _run,
              )
            else if (report != null && catalog != null)
              _buildResults(catalog, report, s, lang, scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildConfig(TreeCatalog catalog, AppStrings s, ColorScheme scheme) {
    String metricsSummary() {
      if (_metricIds.isEmpty) return s['rep.none'];
      final names =
          _metricIds.map((id) => catalog.byId(id)?.title ?? id).toList();
      return names.join(', ');
    }

    String groupsSummary() {
      if (_groups.isEmpty) return s['rep.none'];
      return _groups.entries
          .map((e) {
            final f = catalog.byId(e.key);
            if (f == null) return e.key;
            if (f.isDimension && e.value != null) {
              return '${f.title}: ${f.copy(selectedChildId: e.value).selectedChildLabel ?? e.value}';
            }
            return f.title;
          })
          .join(', ');
    }

    String filtersSummary() {
      if (_filters.isEmpty) return s['rep.noFilters'];
      return _filters.map((f) => f.describe(s[f.op.labelKey])).join(' · ');
    }

    Widget row(
      IconData icon,
      String title,
      String subtitle,
      int count,
      VoidCallback onTap,
    ) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(icon, color: scheme.onSurfaceVariant),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: Brand.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Brand.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
    }

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          row(
            Icons.functions,
            s['rep.metrics'],
            metricsSummary(),
            _metricIds.length,
            _pickMetrics,
          ),
          const Divider(indent: 56),
          row(
            Icons.account_tree_outlined,
            s['rep.groups'],
            groupsSummary(),
            _groups.length,
            _pickGroups,
          ),
          const Divider(indent: 56),
          row(
            Icons.filter_alt_outlined,
            s['rep.filters'],
            filtersSummary(),
            _filters.length,
            _pickFilters,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _hasValidSelection && !_loading ? _run : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(s['rep.apply']),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(s['rep.reset']),
                ),
              ],
            ),
          ),
          if (catalog.metrics.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                s['rep.typeEmpty'],
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            )
          else if (!_hasValidSelection)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                s['rep.needSelection'],
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(
    TreeCatalog catalog,
    ReportResponse report,
    AppStrings s,
    String lang,
    ColorScheme scheme,
  ) {
    final cols = _columns(catalog, report);
    final periodText =
        report.periods.isNotEmpty
            ? Fmt.range(
              report.periods.first.start,
              report.periods.first.end,
              lang,
            )
            : _period.label(lang);
    final canChart =
        _dimensionFields.containsKey('date') && _entityFields.isEmpty ||
        _entityFields.length == 1 && _dimensionFields.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['rep.results'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      periodText,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.table_rows_outlined, size: 16),
                    tooltip: s['rep.table'],
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.show_chart, size: 16),
                    tooltip: s['rep.chart'],
                  ),
                ],
                selected: {_chartMode},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (v) => setState(() => _chartMode = v.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report.totals.isNotEmpty) ...[
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _metricIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final id = _metricIds[i];
                  final meta = report.measures[id];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(minWidth: 120),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          meta?.title ?? id,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Fmt.measure(
                            report.totals[id],
                            unit: meta?.unit ?? 'count',
                            currency: meta?.currency,
                            lang: lang,
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (report.points.isEmpty)
            SectionCard(
              child: EmptyView(text: s['rep.empty'], icon: Icons.search_off),
            )
          else if (_chartMode)
            SectionCard(
              child:
                  !canChart
                      ? EmptyView(
                        text: s['rep.tooManyForChart'],
                        icon: Icons.show_chart,
                      )
                      : _buildChart(report, s, lang),
            )
          else
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ReportTable(
                report: report,
                columns: cols,
                lang: lang,
                sortField: _orderBy?.field,
                sortDesc: _orderBy?.desc ?? true,
                onSort: (field, desc) {
                  setState(() => _orderBy = OrderBy(field, desc: desc));
                  _run();
                },
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s['rep.showing']} ${Fmt.count(report.points.length, lang)} ${s['rep.of']} ${Fmt.count(report.totalRows, lang)} ${s['rep.rows']}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!report.isLastPage)
                _loadingMore
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : TextButton.icon(
                      onPressed: () => _run(append: true),
                      icon: const Icon(Icons.expand_more),
                      label: Text(s['rep.loadMore']),
                    ),
            ],
          ),
          if (!_chartMode && report.points.isNotEmpty)
            Text(
              s['rep.sortHint'],
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildChart(ReportResponse report, AppStrings s, String lang) {
    final metric = _chartMetric ?? _metricIds.first;
    final meta = report.measures[metric];
    final unit = meta?.unit ?? 'count';
    Widget chart;
    if (_dimensionFields.containsKey('date')) {
      final samples = <ChartSample>[];
      for (final p in report.points) {
        final raw = p.dimensions['date'] ?? '';
        final d = DateTime.tryParse(raw.split(' ').first);
        if (d != null) samples.add(ChartSample(d, p.measures[metric] ?? 0));
      }
      samples.sort((a, b) => a.date.compareTo(b.date));
      chart = TrendLineChart(
        samples: samples,
        unit: unit,
        currency: meta?.currency,
        lang: lang,
        height: 220,
      );
    } else {
      final entity = _entityFields.first;
      final entries =
          report.points
              .map(
                (p) => MapEntry(
                  p.dimensions[entity] ?? '—',
                  p.measures[metric] ?? 0,
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      chart = RankingBars(
        entries: entries.take(15).toList(),
        unit: unit,
        currency: meta?.currency,
        lang: lang,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final id in _metricIds)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(report.measures[id]?.title ?? id),
                    selected: metric == id,
                    onSelected: (_) => setState(() => _chartMetric = id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        chart,
      ],
    );
  }
}
