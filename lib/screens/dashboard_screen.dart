import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adpocket/core/formatters.dart';
import 'package:adpocket/core/layout.dart';
import 'package:adpocket/core/period.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/report_preset.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/notification_service.dart';
import 'package:adpocket/services/report_cache.dart';
import 'package:adpocket/services/widget_service.dart';
import 'package:adpocket/theme.dart';
import 'package:adpocket/widgets/account_switcher.dart';
import 'package:adpocket/widgets/kpi_card.dart';
import 'package:adpocket/widgets/revenue_chart.dart';
import 'package:adpocket/widgets/section_card.dart';
import 'package:adpocket/widgets/state_views.dart';

/// At-a-glance overview: today's revenue, period cards, 30-day trend,
/// period ratios and the top apps / sites.
class DashboardScreen extends StatefulWidget {
  final void Function(ReportPreset preset)? onOpenReport;

  /// Current time; injectable so tests and golden renders are deterministic.
  /// "Today" is derived from it in Moscow time.
  final DateTime Function() clock;

  const DashboardScreen({
    this.onOpenReport,
    this.clock = DateTime.now,
    super.key,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  DashboardData? _data;
  bool _loading = false;
  bool _loadingTop = false;
  String? _error;
  bool _showShows = false;
  DashWindow _detailWindow = DashWindow.days7;
  PeriodPreset _topPeriod = PeriodPreset.thisMonth;
  String? _fetchKey;
  String? _accountId;

  static const _topPresets = [
    PeriodPreset.today,
    PeriodPreset.yesterday,
    PeriodPreset.days7,
    PeriodPreset.thisMonth,
    PeriodPreset.lastMonth,
  ];

  static const _staleAfter = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreThenFetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app after a while should show current numbers, not
  /// whatever was fetched at the last launch.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _loading) return;
    final fetchedAt = _data?.fetchedAt;
    if (fetchedAt == null ||
        widget.clock().difference(fetchedAt) >= _staleAfter) {
      _fetch();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch when language / currency / VAT changes; reload from the
    // account's own cache when the active account changes.
    final settings = context.watch<AppSettings>();
    final accountId = context.watch<AppSession>().accountId;
    final key = '${settings.lang}|${settings.currency}|${settings.vat}';
    if (_accountId != null && _accountId != accountId) {
      _accountId = accountId;
      _fetchKey = key;
      setState(() {
        _data = null;
        _error = null;
      });
      _restoreThenFetch();
      return;
    }
    _accountId ??= accountId;
    if (_fetchKey != null && _fetchKey != key) {
      _fetchKey = key;
      _fetch();
    } else {
      _fetchKey ??= key;
    }
  }

  Future<void> _restoreThenFetch() async {
    final cached = await ReportCache.loadDashboard(
      accountId: context.read<AppSession>().accountId,
    );
    if (cached != null && mounted) {
      setState(() {
        _data = cached;
        _topPeriod = PeriodPreset.fromValue(cached.topPeriodValue);
      });
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    final session = context.read<AppSession>();
    final settings = context.read<AppSettings>();
    final token = session.token;
    final accountId = session.accountId;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    // Results for an account the user has since switched away from must not
    // be shown, cached or pushed under the new account.
    bool stale() => !mounted || session.accountId != accountId;
    try {
      final daily = await session.api.fetchDailySeries(
        token: token,
        lang: settings.lang,
        currency: settings.currency,
        vat: settings.vat,
      );
      final top = await session.api.fetchTopEntities(
        token: token,
        period: ReportPeriod.preset(_topPeriod),
        lang: settings.lang,
        currency: settings.currency,
        vat: settings.vat,
      );
      if (stale()) return;
      final series =
          daily.points
              .map(DailyPoint.fromPoint)
              .whereType<DailyPoint>()
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      final data = DashboardData(
        series: series,
        currency: daily.currency ?? settings.currency,
        fetchedAt: widget.clock(),
        topEntities: top,
        topPeriodValue: _topPeriod.value,
      );
      await ReportCache.saveDashboard(data, accountId: accountId);
      WidgetService.push(
        data,
        lang: settings.lang,
        currency: settings.currency,
        vat: settings.vat,
      );
      NotificationService.onDataRefreshed(data, settings);
      if (stale()) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (stale()) return;
      setState(
        () =>
            _error =
                e.isUnauthorized
                    ? settings.strings['common.unauthorized']
                    : (e.isNetwork
                        ? settings.strings['common.noInternet']
                        : e.message),
      );
    } catch (e) {
      if (stale()) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && !stale()) setState(() => _loading = false);
    }
  }

  Future<void> _fetchTop(PeriodPreset preset) async {
    final session = context.read<AppSession>();
    final settings = context.read<AppSettings>();
    final token = session.token;
    final accountId = session.accountId;
    if (token == null || _data == null) return;
    setState(() {
      _topPeriod = preset;
      _loadingTop = true;
    });
    try {
      final top = await session.api.fetchTopEntities(
        token: token,
        period: ReportPeriod.preset(preset),
        lang: settings.lang,
        currency: settings.currency,
        vat: settings.vat,
      );
      if (!mounted || session.accountId != accountId || _data == null) return;
      final data = _data!.copyWith(
        topEntities: top,
        topPeriodValue: preset.value,
        fetchedAt: widget.clock(),
      );
      await ReportCache.saveDashboard(data, accountId: accountId);
      if (mounted && session.accountId == accountId) {
        setState(() => _data = data);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingTop = false);
    }
  }

  void _openTopEntityReport(String pageId, String caption) {
    widget.onOpenReport?.call(
      ReportPreset(
        name: caption,
        period: ReportPeriod.preset(_topPeriod),
        metricIds: const [
          DashMetrics.revenue,
          DashMetrics.shows,
          DashMetrics.clicks,
          DashMetrics.ecpm,
        ],
        groups: const {'date': 'day'},
        filters: [
          ReportFilter(
            fieldId: 'page_id',
            fieldLabel: 'page_id',
            op: FilterOp.eq,
            values: [pageId],
            valueLabels: [caption],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final s = settings.strings;
    final lang = settings.lang;
    final data = _data;

    return Scaffold(
      appBar: AppBar(
        title: Text(s['dash.title']),
        actions: [
          const AccountButton(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh),
              tooltip: s['dash.refresh'],
            ),
        ],
      ),
      body: PageBody(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child:
              data == null
                  ? ListView(
                    children: [
                      if (_error != null)
                        ErrorView(
                          title: s['rep.error'],
                          details: _error,
                          retryLabel: s['common.retry'],
                          onRetry: _fetch,
                        )
                      else
                        const LoadingView(),
                    ],
                  )
                  : LayoutBuilder(
                    builder:
                        (context, c) =>
                            _buildContent(context, data, s, lang, c.maxWidth),
                  ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardData data,
    dynamic s,
    String lang,
    double width,
  ) {
    final kpiColumns = Layout.columns(width, tileWidth: 175, min: 2, max: 4);
    // Six metrics: 3 or 6 columns so the grid never leaves an orphan row.
    final statColumns = (width - 32 - 36 - 40) / 6 >= 104 ? 6 : 3;
    // Fixed tile height regardless of column count: the grid is inside the
    // 16 px page padding with 10 px gaps.
    final kpiTileWidth = (width - 32 - 10 * (kpiColumns - 1)) / kpiColumns;
    final kpiAspect = kpiTileWidth / 122;
    // Stat tiles sit inside a section card (18 px padding) with 8 px gaps.
    final statTileWidth =
        (width - 32 - 36 - 8 * (statColumns - 1)) / statColumns;
    final statAspect = statTileWidth / 108;
    final scheme = Theme.of(context).colorScheme;
    final cur = data.currency;
    final now = DashboardData.moscowToday(widget.clock());
    final (today, yesterday) = data.window(DashWindow.today, now: now);
    final (yest, beforeYest) = data.window(DashWindow.yesterday, now: now);
    final (week, prevWeek) = data.window(DashWindow.days7, now: now);
    final (month, prevMonth) = data.window(DashWindow.thisMonth, now: now);
    final (lastMonth, prevLastMonth) = data.window(
      DashWindow.lastMonth,
      now: now,
    );
    final (detail, prevDetail) = data.window(_detailWindow, now: now);
    final trend = data.trend(days: 30, now: now);

    String money(num v) =>
        Fmt.measure(v, unit: 'money', currency: cur, lang: lang);
    String moneyAuto(num v) =>
        Fmt.measureAuto(v, unit: 'money', currency: cur, lang: lang);
    String countAuto(num v) => Fmt.measureAuto(v, unit: 'count', lang: lang);
    String pct(num v) => Fmt.measure(v, unit: 'percent', lang: lang);

    String vsLabel(DashWindow w) {
      final r = data.ranges(w, now: now);
      return '${s['dash.vs']} ${Fmt.baseline(r.prevStart, r.prevEnd, lang)}';
    }

    KpiCard periodCard(
      String label,
      DashWindow w,
      PeriodSummary cur,
      PeriodSummary prev, {
      IconData? icon,
    }) {
      final d = Fmt.delta(cur.revenue, prev.revenue, lang);
      return KpiCard(
        label: label,
        value: moneyAuto(cur.revenue),
        delta: d,
        deltaPositive: d == null ? null : cur.revenue >= prev.revenue,
        deltaHint: d == null ? null : vsLabel(w),
        icon: icon,
      );
    }

    final topEntries = <(String, String, double)>[];
    if (data.topEntities != null) {
      for (final p in data.topEntities!.points) {
        topEntries.add((
          p.dimensions['page_caption'] ?? '',
          p.dimensions['page_id'] ?? '',
          p.measures[DashMetrics.revenue] ?? 0,
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: scheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Hero: today
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Brand.amber, Brand.amberDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s['dash.today']} · ${Fmt.date(now, lang)}',
                style: TextStyle(
                  color: Brand.navy.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(today.revenue),
                  style: const TextStyle(
                    color: Brand.navy,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (_) {
                  final d = Fmt.delta(today.revenue, yesterday.revenue, lang);
                  return Row(
                    children: [
                      if (d != null) ...[
                        Icon(
                          today.revenue >= yesterday.revenue
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 18,
                          color: Brand.navy,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          d,
                          style: const TextStyle(
                            color: Brand.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          '${s['dash.vsYesterday']} · ${money(yesterday.revenue)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Brand.navy.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _heroStat(
                    Icons.visibility_outlined,
                    s['dash.shows'],
                    countAuto(today.shows),
                  ),
                  const SizedBox(width: 18),
                  _heroStat(
                    Icons.ads_click,
                    s['dash.clicks'],
                    countAuto(today.clicks),
                  ),
                  const SizedBox(width: 18),
                  _heroStat(Icons.speed, s['dash.ecpm'], money(today.ecpm)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: kpiColumns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: kpiAspect,
          children: [
            periodCard(
              s['dash.yesterday'],
              DashWindow.yesterday,
              yest,
              beforeYest,
              icon: Icons.history,
            ),
            periodCard(
              s['dash.last7'],
              DashWindow.days7,
              week,
              prevWeek,
              icon: Icons.date_range,
            ),
            periodCard(
              s['dash.month'],
              DashWindow.thisMonth,
              month,
              prevMonth,
              icon: Icons.calendar_month,
            ),
            periodCard(
              s['dash.lastMonth'],
              DashWindow.lastMonth,
              lastMonth,
              prevLastMonth,
              icon: Icons.calendar_today,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: _showShows ? s['dash.trendShows'] : s['dash.trend'],
          trailing: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.payments_outlined, size: 16),
                tooltip: s['dash.revenue'],
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                tooltip: s['dash.shows'],
              ),
            ],
            selected: {_showShows},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (v) => setState(() => _showShows = v.first),
          ),
          child: TrendLineChart(
            samples: [
              for (final p in trend)
                ChartSample(p.date, _showShows ? p.shows : p.revenue),
            ],
            unit: _showShows ? 'count' : 'money',
            currency: cur,
            lang: lang,
            color: _showShows ? Brand.chartLineAlt : Brand.chartLine,
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: s['dash.details'],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final w in const [
                      DashWindow.today,
                      DashWindow.yesterday,
                      DashWindow.days7,
                      DashWindow.days30,
                      DashWindow.thisMonth,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_windowLabel(w, s)),
                          selected: _detailWindow == w,
                          onSelected: (_) => setState(() => _detailWindow = w),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: statColumns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: statAspect,
                children: [
                  _miniStat(
                    context,
                    s['dash.revenue'],
                    moneyAuto(detail.revenue),
                    Fmt.delta(detail.revenue, prevDetail.revenue, lang),
                    detail.revenue >= prevDetail.revenue,
                  ),
                  _miniStat(
                    context,
                    s['dash.shows'],
                    countAuto(detail.shows),
                    Fmt.delta(detail.shows, prevDetail.shows, lang),
                    detail.shows >= prevDetail.shows,
                  ),
                  _miniStat(
                    context,
                    s['dash.clicks'],
                    countAuto(detail.clicks),
                    Fmt.delta(detail.clicks, prevDetail.clicks, lang),
                    detail.clicks >= prevDetail.clicks,
                  ),
                  _miniStat(
                    context,
                    s['dash.ecpm'],
                    moneyAuto(detail.ecpm),
                    Fmt.delta(detail.ecpm, prevDetail.ecpm, lang),
                    detail.ecpm >= prevDetail.ecpm,
                  ),
                  _miniStat(
                    context,
                    s['dash.fill'],
                    pct(detail.fillRate),
                    Fmt.delta(detail.fillRate, prevDetail.fillRate, lang),
                    detail.fillRate >= prevDetail.fillRate,
                  ),
                  _miniStat(
                    context,
                    s['dash.ctr'],
                    pct(detail.ctr),
                    Fmt.delta(detail.ctr, prevDetail.ctr, lang),
                    detail.ctr >= prevDetail.ctr,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (_) {
                  final r = data.ranges(_detailWindow, now: now);
                  return Text(
                    '${Fmt.baseline(r.start, r.end, lang)} · ${s['dash.comparedWith']} ${Fmt.baseline(r.prevStart, r.prevEnd, lang)}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: s['dash.topApps'],
          trailing:
              _loadingTop
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in _topPresets)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(p.label(lang)),
                          selected: _topPeriod == p,
                          onSelected: (_) => _fetchTop(p),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (topEntries.isEmpty)
                EmptyView(text: s['dash.noData'], icon: Icons.apps_outlined)
              else
                RankingBars(
                  entries: [
                    for (final e in topEntries)
                      MapEntry(e.$1.isEmpty ? e.$2 : e.$1, e.$3),
                  ],
                  unit: 'money',
                  currency: cur,
                  lang: lang,
                  onTap:
                      widget.onOpenReport == null
                          ? null
                          : (label) {
                            final match = topEntries.firstWhere(
                              (e) => (e.$1.isEmpty ? e.$2 : e.$1) == label,
                              orElse: () => topEntries.first,
                            );
                            if (match.$2.isNotEmpty) {
                              _openTopEntityReport(match.$2, match.$1);
                            }
                          },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '${s['dash.updated']}: ${Fmt.date(data.fetchedAt, lang)} ${Fmt.time(data.fetchedAt, lang)}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
      ],
    );
  }

  String _windowLabel(DashWindow w, dynamic s) {
    switch (w) {
      case DashWindow.today:
        return s['dash.today'];
      case DashWindow.yesterday:
        return s['dash.yesterday'];
      case DashWindow.thisWeek:
        return s['dash.week'];
      case DashWindow.thisMonth:
        return s['dash.month'];
      case DashWindow.lastMonth:
        return s['dash.lastMonth'];
      case DashWindow.days7:
        return s['dash.days7'];
      case DashWindow.days30:
        return s['dash.days30'];
    }
  }

  Widget _heroStat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Brand.navy.withValues(alpha: 0.75)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Brand.navy.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Brand.navy,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    String label,
    String value,
    String? delta,
    bool positive,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: positive ? Brand.positive : Brand.negative,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
