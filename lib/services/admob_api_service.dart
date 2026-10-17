import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:http/http.dart' as http;

import 'package:adpocket/core/day_zone.dart';
import 'package:adpocket/core/period.dart';
import 'package:adpocket/models/account.dart';
import 'package:adpocket/models/dashboard_data.dart';
import 'package:adpocket/models/filter_field.dart';
import 'package:adpocket/models/report_point.dart';
import 'package:adpocket/models/report_response.dart';
import 'package:adpocket/models/tree_catalog.dart';
import 'package:adpocket/models/tree_field.dart';
import 'package:adpocket/services/api_exception.dart';
import 'package:adpocket/services/dashboard_loader.dart' show DailySeries;
import 'package:adpocket/services/google_auth.dart';
import 'package:adpocket/services/yandex_api_service.dart' show OrderBy;

/// An AdMob publisher account the signed-in Google user can read.
class AdMobPublisher {
  final String publisherId;
  final String currencyCode;
  final String timeZone;
  const AdMobPublisher({
    required this.publisherId,
    required this.currencyCode,
    required this.timeZone,
  });
}

/// AdMob report types, shown in Reports where Yandex shows Main/MM/SSP/DSP.
enum AdMobReportKind { network, mediation }

class AdMobMetric {
  final String id; // AdPocket id, lower case
  final String api; // AdMob API name
  final String unit; // count | money | percent
  final String en;
  final String ru;
  final bool network;
  final bool mediation;
  const AdMobMetric(
    this.id,
    this.api,
    this.unit,
    this.en,
    this.ru, {
    this.network = true,
    this.mediation = true,
  });
}

class AdMobDimension {
  final String id;
  final String api;
  final String en;
  final String ru;
  final bool network;
  final bool mediation;
  const AdMobDimension(
    this.id,
    this.api,
    this.en,
    this.ru, {
    this.network = true,
    this.mediation = true,
  });
}

/// Metrics, groupings and ratio formulas of the AdMob Reporting API v1.
class AdMobSchema {
  static const metrics = [
    AdMobMetric(
      'estimated_earnings',
      'ESTIMATED_EARNINGS',
      'money',
      'Estimated earnings',
      'Расчётный доход',
    ),
    AdMobMetric('impressions', 'IMPRESSIONS', 'count', 'Impressions', 'Показы'),
    AdMobMetric('clicks', 'CLICKS', 'count', 'Clicks', 'Клики'),
    AdMobMetric('ad_requests', 'AD_REQUESTS', 'count', 'Requests', 'Запросы'),
    AdMobMetric(
      'matched_requests',
      'MATCHED_REQUESTS',
      'count',
      'Matched requests',
      'Выполненные запросы',
    ),
    AdMobMetric(
      'match_rate',
      'MATCH_RATE',
      'percent',
      'Match rate',
      'Процент выполнения',
    ),
    AdMobMetric(
      'show_rate',
      'SHOW_RATE',
      'percent',
      'Show rate',
      'Процент показов',
      mediation: false,
    ),
    AdMobMetric('impression_ctr', 'IMPRESSION_CTR', 'percent', 'CTR', 'CTR'),
    AdMobMetric(
      'impression_rpm',
      'IMPRESSION_RPM',
      'money',
      'Impression RPM',
      'RPM показов',
      mediation: false,
    ),
    AdMobMetric(
      'observed_ecpm',
      'OBSERVED_ECPM',
      'money',
      'Observed eCPM',
      'Наблюдаемая eCPM',
      network: false,
    ),
  ];

  static const dimensions = [
    AdMobDimension('app', 'APP', 'App', 'Приложение'),
    AdMobDimension('ad_unit', 'AD_UNIT', 'Ad unit', 'Рекламный блок'),
    AdMobDimension('format', 'FORMAT', 'Format', 'Формат'),
    AdMobDimension('platform', 'PLATFORM', 'Platform', 'Платформа'),
    AdMobDimension('country', 'COUNTRY', 'Country', 'Страна'),
    AdMobDimension(
      'ad_type',
      'AD_TYPE',
      'Ad type',
      'Тип рекламы',
      mediation: false,
    ),
    AdMobDimension(
      'ad_source',
      'AD_SOURCE',
      'Ad source',
      'Источник рекламы',
      network: false,
    ),
    AdMobDimension(
      'mediation_group',
      'MEDIATION_GROUP',
      'Mediation group',
      'Группа медиации',
      network: false,
    ),
  ];

  /// ratio = numerator / denominator * scale; recomputed for totals and
  /// whenever rows are combined.
  static const ratios = {
    'match_rate': ('matched_requests', 'ad_requests', 100.0),
    'show_rate': ('impressions', 'matched_requests', 100.0),
    'impression_ctr': ('clicks', 'impressions', 100.0),
    'impression_rpm': ('estimated_earnings', 'impressions', 1000.0),
    'observed_ecpm': ('estimated_earnings', 'impressions', 1000.0),
  };

  static const dateGroups = {'day': 'DATE', 'week': 'WEEK', 'month': 'MONTH'};

  static AdMobMetric? metric(String id) {
    for (final m in metrics) {
      if (m.id == id) return m;
    }
    return null;
  }

  static AdMobDimension? dimension(String id) {
    for (final d in dimensions) {
      if (d.id == id) return d;
    }
    return null;
  }

  static List<String> defaultMetrics(AdMobReportKind kind) =>
      kind == AdMobReportKind.network
          ? const [
            'estimated_earnings',
            'impressions',
            'clicks',
            'impression_rpm',
          ]
          : const [
            'estimated_earnings',
            'impressions',
            'clicks',
            'observed_ecpm',
          ];

  static const formats = [
    'BANNER',
    'INTERSTITIAL',
    'REWARDED',
    'REWARDED_INTERSTITIAL',
    'NATIVE',
    'APP_OPEN',
  ];

  /// Report catalogue in the same shape as the Yandex statistics tree, so the
  /// Reports screen works unchanged.
  static TreeCatalog catalog(
    AdMobReportKind kind,
    String lang, {
    List<FilterFieldValue> apps = const [],
  }) {
    final ru = lang == 'ru';
    bool fits(bool network, bool mediation) =>
        kind == AdMobReportKind.network ? network : mediation;
    var i = 0;
    final metricFields = [
      for (final m in metrics)
        if (fits(m.network, m.mediation))
          TreeField(
            id: m.id,
            title: ru ? m.ru : m.en,
            source: TreeField.kSourceFields,
            type: 'number',
            unit: m.unit,
            hint: '',
            categoryName: 'AdMob',
            category: 0,
            index: i++,
          ),
    ];
    final date = TreeField(
      id: 'date',
      title: ru ? 'Дата' : 'Date',
      source: TreeField.kSourceDimension,
      type: TreeField.kTypeSelect,
      unit: '',
      hint: '',
      categoryName: null,
      category: 0,
      index: 0,
      values: [
        ['day', ru ? 'по дням' : 'by day'],
        ['week', ru ? 'по неделям' : 'by week'],
        ['month', ru ? 'по месяцам' : 'by month'],
      ],
      selectedChildId: 'day',
    );
    var j = 0;
    final entities = [
      for (final d in dimensions)
        if (fits(d.network, d.mediation))
          TreeField(
            id: d.id,
            title: ru ? d.ru : d.en,
            source: TreeField.kSourceEntityFields,
            type: 'string',
            unit: '',
            hint: '',
            categoryName: 'AdMob',
            category: 0,
            index: j++,
          ),
    ];
    final filters = [
      if (apps.isNotEmpty)
        FilterField(
          id: 'app',
          label: ru ? 'Приложение' : 'App',
          type: FilterField.kTypeChoice,
          categoryName: 'AdMob',
          index: 0,
          values: apps,
        ),
      FilterField(
        id: 'platform',
        label: ru ? 'Платформа' : 'Platform',
        type: FilterField.kTypeChoice,
        categoryName: 'AdMob',
        index: 1,
        values: const [
          FilterFieldValue('Android', 'Android'),
          FilterFieldValue('iOS', 'iOS'),
        ],
      ),
      FilterField(
        id: 'format',
        label: ru ? 'Формат' : 'Format',
        type: FilterField.kTypeChoice,
        categoryName: 'AdMob',
        index: 2,
        values: [for (final f in formats) FilterFieldValue(f, f)],
      ),
    ];
    return TreeCatalog(
      metrics: metricFields,
      dimensions: [date],
      entities: entities,
      filters: filters,
    );
  }
}

/// Client for the AdMob API v1 (accounts, apps, network and mediation
/// reports), producing the same models as the Yandex client.
class AdMobApiService {
  AdMobApiService({GoogleAuth? auth, http.Client? client})
    : auth = auth ?? GoogleSignInAuth.instance,
      _client = client ?? http.Client();

  final GoogleAuth auth;
  final http.Client _client;
  static const _base = 'https://admob.googleapis.com/v1';
  static const _timeout = Duration(seconds: 40);

  /// The last full report, so paging through it costs no requests.
  String? _cacheKey;
  ReportResponse? _cache;
  DateTime? _cacheAt;

  // ---- transport -------------------------------------------------------

  Future<dynamic> _call(
    String email,
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retried = false,
  }) async {
    final token = await auth.accessToken(email: email);
    final uri = Uri.parse('$_base/$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final http.Response r;
    try {
      r =
          method == 'POST'
              ? await _client
                  .post(uri, headers: headers, body: jsonEncode(body))
                  .timeout(_timeout)
              : await _client.get(uri, headers: headers).timeout(_timeout);
    } catch (e) {
      throw ApiException(0, e.toString());
    }
    final text = utf8.decode(r.bodyBytes);
    if (r.statusCode == 401 && !retried) {
      // The token expired early or was revoked: drop it and try once more.
      final a = auth;
      if (a is GoogleSignInAuth) await a.invalidate();
      return _call(email, method, path, body: body, retried: true);
    }
    if (r.statusCode != 200) {
      String msg = 'HTTP ${r.statusCode}';
      try {
        final e = (jsonDecode(text) as Map)['error'];
        if (e is Map && e['message'] is String) msg = e['message'] as String;
      } catch (_) {}
      throw ApiException(r.statusCode, msg);
    }
    return jsonDecode(text);
  }

  // ---- accounts and inventory -----------------------------------------

  Future<List<AdMobPublisher>> listPublishers(String email) async {
    final j = await _call(email, 'GET', 'accounts') as Map<String, dynamic>;
    return [
      for (final a in (j['account'] as List? ?? []).cast<Map>())
        AdMobPublisher(
          publisherId: (a['publisherId'] ?? '').toString(),
          currencyCode: (a['currencyCode'] ?? 'USD').toString(),
          timeZone: (a['reportingTimeZone'] ?? '').toString(),
        ),
    ];
  }

  /// Apps of the account as filter values (id, display name).
  Future<List<FilterFieldValue>> listApps(Account account) async {
    final j =
        await _call(
              account.googleEmail!,
              'GET',
              'accounts/${account.publisherId}/apps?pageSize=1000',
            )
            as Map<String, dynamic>;
    return [
      for (final a in (j['apps'] as List? ?? []).cast<Map>())
        FilterFieldValue(
          (a['appId'] ?? '').toString(),
          ((a['linkedAppInfo'] as Map?)?['displayName'] ??
                  (a['manualAppInfo'] as Map?)?['displayName'] ??
                  a['appId'])
              .toString(),
        ),
    ];
  }

  // ---- reports ----------------------------------------------------------

  static Map<String, int> _ymd(DateTime d) => {
    'year': d.year,
    'month': d.month,
    'day': d.day,
  };

  /// Runs a report and returns rows as AdPocket ids: dimension -> label,
  /// metric -> value (percent metrics in percent, money in currency units).
  Future<List<(Map<String, String>, Map<String, String>, Map<String, double>)>>
  _rows(
    Account account, {
    required AdMobReportKind kind,
    required DateTimeRange range,
    required List<String> metrics,
    String? dateGroup,
    List<String> entities = const [],
    List<ReportFilter> filters = const [],
    required String currency,
    required String lang,
  }) async {
    final dims = [
      if (dateGroup != null) AdMobSchema.dateGroups[dateGroup] ?? 'DATE',
      for (final e in entities)
        if (AdMobSchema.dimension(e) != null) AdMobSchema.dimension(e)!.api,
    ];
    final spec = {
      'dateRange': {'startDate': _ymd(range.start), 'endDate': _ymd(range.end)},
      'dimensions': dims,
      'metrics': [for (final m in metrics) AdMobSchema.metric(m)!.api],
      if (filters.isNotEmpty)
        'dimensionFilters': [
          for (final f in filters)
            if (AdMobSchema.dimension(f.fieldId) != null)
              {
                'dimension': AdMobSchema.dimension(f.fieldId)!.api,
                'matchesAny': {'values': f.values},
              },
        ],
      'localizationSettings': {
        'currencyCode': currency,
        'languageCode': lang == 'ru' ? 'ru-RU' : 'en-US',
      },
      'maxReportRows': 100000,
      'timeZone': 'America/Los_Angeles',
    };
    final path =
        'accounts/${account.publisherId}/'
        '${kind == AdMobReportKind.network ? 'networkReport' : 'mediationReport'}'
        ':generate';
    final body = await _call(
      account.googleEmail!,
      'POST',
      path,
      body: {'reportSpec': spec},
    );
    return parseRows(body);
  }

  /// Parses the streamed report (a JSON array of header, rows and footer).
  /// Returns (dimension labels, dimension raw values, metric values).
  static List<(Map<String, String>, Map<String, String>, Map<String, double>)>
  parseRows(dynamic body) {
    final out =
        <(Map<String, String>, Map<String, String>, Map<String, double>)>[];
    final items = body is List ? body : [body];
    final byApiDim = {
      for (final d in AdMobSchema.dimensions) d.api: d.id,
      'DATE': 'date',
      'WEEK': 'date',
      'MONTH': 'date',
    };
    final byApiMetric = {for (final m in AdMobSchema.metrics) m.api: m};
    for (final item in items) {
      final row = (item as Map)['row'];
      if (row is! Map) continue;
      final labels = <String, String>{};
      final raw = <String, String>{};
      ((row['dimensionValues'] as Map?) ?? {}).forEach((k, v) {
        final id = byApiDim[k];
        if (id == null || v is! Map) return;
        final value = (v['value'] ?? '').toString();
        raw[id] = value;
        labels[id] =
            id == 'date'
                ? _isoDate(value)
                : ((v['displayLabel'] as String?)?.isNotEmpty == true
                    ? v['displayLabel'] as String
                    : value);
      });
      final metrics = <String, double>{};
      ((row['metricValues'] as Map?) ?? {}).forEach((k, v) {
        final m = byApiMetric[k];
        if (m == null || v is! Map) return;
        double? x;
        if (v['microsValue'] != null) {
          x = double.parse(v['microsValue'].toString()) / 1e6;
        } else if (v['integerValue'] != null) {
          x = double.parse(v['integerValue'].toString());
        } else if (v['doubleValue'] != null) {
          x = (v['doubleValue'] as num).toDouble();
        }
        if (x == null) return;
        if (m.unit == 'percent') x *= 100; // the API returns fractions
        metrics[m.id] = x;
      });
      out.add((labels, raw, metrics));
    }
    return out;
  }

  /// '20261017' -> '2026-10-17'; '202610' (month) -> '2026-10-01'.
  static String _isoDate(String v) {
    if (v.length == 8) {
      return '${v.substring(0, 4)}-${v.substring(4, 6)}-${v.substring(6, 8)}';
    }
    if (v.length == 6) return '${v.substring(0, 4)}-${v.substring(4, 6)}-01';
    return v;
  }

  /// Adds the components every requested ratio needs.
  static List<String> withComponents(List<String> metrics) {
    final out = [...metrics];
    for (final m in metrics) {
      final r = AdMobSchema.ratios[m];
      if (r == null) continue;
      for (final c in [r.$1, r.$2]) {
        if (!out.contains(c)) out.add(c);
      }
    }
    return out;
  }

  static Map<String, double> totalsOf(
    Iterable<Map<String, double>> rows,
    List<String> metrics,
  ) {
    final sum = <String, double>{};
    for (final r in rows) {
      r.forEach((k, v) {
        if (AdMobSchema.ratios.containsKey(k)) return;
        sum[k] = (sum[k] ?? 0) + v;
      });
    }
    final out = <String, double>{};
    for (final m in metrics) {
      final r = AdMobSchema.ratios[m];
      if (r == null) {
        out[m] = sum[m] ?? 0;
      } else {
        final d = sum[r.$2] ?? 0;
        if (d > 0) out[m] = (sum[r.$1] ?? 0) / d * r.$3;
      }
    }
    return out;
  }

  // ---- dashboard -------------------------------------------------------

  /// 90 Pacific days of daily totals, in the dashboard's series format.
  Future<DailySeries> loadDaily(
    Account account, {
    required String currency,
    required String lang,
    DateTime? now,
  }) async {
    final today = DayZone.pacific.dayOf(now ?? DateTime.now());
    final start = DashboardData.addDays(today, -89);
    final rows = await _rows(
      account,
      kind: AdMobReportKind.network,
      range: DateTimeRange(start: start, end: today),
      metrics: const [
        'estimated_earnings',
        'impressions',
        'clicks',
        'ad_requests',
        'matched_requests',
      ],
      dateGroup: 'day',
      currency: currency,
      lang: lang,
    );
    final points = <DailyPoint>[
      for (final (labels, _, m) in rows)
        if (DateTime.tryParse(labels['date'] ?? '') != null)
          DailyPoint(
            date: DateTime.parse(labels['date']!),
            revenue: m['estimated_earnings'] ?? 0,
            shows: m['impressions'] ?? 0,
            hits: m['ad_requests'] ?? 0,
            hitsRender: m['matched_requests'] ?? 0,
            clicks: m['clicks'] ?? 0,
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return DailySeries(
      points: points,
      currency: currency,
      coveredFrom: start,
      coveredTo: today,
    );
  }

  /// Top apps for a dashboard preset, in the dashboard's top-list format.
  Future<ReportResponse> loadTop(
    Account account, {
    required PeriodPreset preset,
    required String currency,
    required String lang,
    DateTime? now,
    int limit = 10,
  }) async {
    final today = DayZone.pacific.dayOf(now ?? DateTime.now());
    final range = ReportPeriod.preset(preset).resolve(today);
    final rows = await _rows(
      account,
      kind: AdMobReportKind.network,
      range: range,
      metrics: const ['estimated_earnings', 'impressions', 'clicks'],
      entities: const ['app'],
      currency: currency,
      lang: lang,
    );
    final points = [
      for (final (labels, raw, m) in rows)
        ReportPoint(
          dimensions: {
            'page_caption': labels['app'] ?? '',
            'page_id': raw['app'] ?? '',
          },
          measures: {
            DashMetrics.revenue: m['estimated_earnings'] ?? 0,
            DashMetrics.shows: m['impressions'] ?? 0,
            DashMetrics.clicks: m['clicks'] ?? 0,
            DashMetrics.ecpm:
                (m['impressions'] ?? 0) > 0
                    ? (m['estimated_earnings'] ?? 0) / m['impressions']! * 1000
                    : 0,
          },
        ),
    ]..sort(
      (a, b) => (b.measures[DashMetrics.revenue] ?? 0).compareTo(
        a.measures[DashMetrics.revenue] ?? 0,
      ),
    );
    return ReportResponse(
      reportTitle: 'AdMob',
      points: points.take(limit).toList(),
      periods: [range],
      totalRows: points.length,
      measures: {
        DashMetrics.revenue: MeasureMeta(
          id: DashMetrics.revenue,
          title: lang == 'ru' ? 'Доход' : 'Earnings',
          unit: 'money',
          currency: currency,
        ),
      },
    );
  }

  // ---- reports screen --------------------------------------------------

  /// Same contract as the Yandex client's fetchReport: one page of rows,
  /// totals, metadata. The full result is fetched once and paged locally.
  Future<ReportResponse> fetchReport(
    Account account, {
    required AdMobReportKind kind,
    required ReportPeriod period,
    required List<String> fields,
    Map<String, String> dimensionFields = const {},
    List<String> entityFields = const [],
    List<ReportFilter> filters = const [],
    OrderBy? orderBy,
    int limit = 50,
    int offset = 0,
    required String lang,
    required String currency,
    DateTime? now,
  }) async {
    final today = DayZone.pacific.dayOf(now ?? DateTime.now());
    final range = period.resolve(today);
    final key = jsonEncode([
      account.id,
      kind.name,
      range.start.toIso8601String(),
      range.end.toIso8601String(),
      fields,
      dimensionFields,
      entityFields,
      [
        for (final f in filters) [f.fieldId, f.op.api, f.values],
      ],
      lang,
      currency,
    ]);
    ReportResponse full;
    if (offset > 0 &&
        _cacheKey == key &&
        _cache != null &&
        DateTime.now().difference(_cacheAt!) < const Duration(minutes: 10)) {
      full = _cache!;
    } else {
      final query = withComponents(fields);
      final rows = await _rows(
        account,
        kind: kind,
        range: range,
        metrics: query,
        dateGroup: dimensionFields['date'],
        entities: entityFields,
        filters: filters,
        currency: currency,
        lang: lang,
      );
      final ru = lang == 'ru';
      final points = [
        for (final (labels, _, m) in rows)
          ReportPoint(
            dimensions: labels,
            measures: {
              for (final f in fields)
                if (m[f] != null) f: m[f]!,
            },
          ),
      ];
      final order =
          orderBy ??
          (dimensionFields.containsKey('date')
              ? const OrderBy('date', desc: true)
              : const OrderBy('estimated_earnings', desc: true));
      full = ReportResponse(
        reportTitle: 'AdMob',
        points: sortReportPoints(points, order.field, desc: order.desc),
        periods: [range],
        totalRows: points.length,
        totals: totalsOf(rows.map((r) => r.$3), fields),
        measures: {
          for (final f in fields)
            if (AdMobSchema.metric(f) != null)
              f: MeasureMeta(
                id: f,
                title:
                    ru ? AdMobSchema.metric(f)!.ru : AdMobSchema.metric(f)!.en,
                unit: AdMobSchema.metric(f)!.unit,
                currency:
                    AdMobSchema.metric(f)!.unit == 'money' ? currency : null,
              ),
        },
        dimensions: {
          if (dimensionFields.containsKey('date'))
            'date': DimensionMeta(
              id: 'date',
              title: ru ? 'Дата' : 'Date',
              type: 'date',
            ),
          for (final e in entityFields)
            if (AdMobSchema.dimension(e) != null)
              e: DimensionMeta(
                id: e,
                title:
                    ru
                        ? AdMobSchema.dimension(e)!.ru
                        : AdMobSchema.dimension(e)!.en,
                type: 'string',
              ),
        },
      );
      _cacheKey = key;
      _cache = full;
      _cacheAt = DateTime.now();
    }
    final page = full.points.skip(offset).take(limit).toList();
    return ReportResponse(
      reportTitle: full.reportTitle,
      points: page,
      periods: full.periods,
      isLastPage: offset + page.length >= full.points.length,
      totalRows: full.totalRows,
      totals: full.totals,
      measures: full.measures,
      dimensions: full.dimensions,
    );
  }
}
