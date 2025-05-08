import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yapartner/models/report_point.dart';
import 'package:yapartner/models/report_response.dart';
import 'package:yapartner/models/tree_field.dart';
import 'package:yapartner/services/yandex_api_service.dart';
import 'package:yapartner/widgets/field_selector_panel.dart';
import 'package:yapartner/widgets/main_screen_table.dart';
import 'package:yapartner/widgets/period_selector.dart';
import 'package:yapartner/widgets/summary_card.dart';

// Constants for shared prefs and labels
const String _kSelectedIndicatorsKey = 'selected_indicators';
const String _kSelectedGroupsKey = 'selected_groups';
const String _kSelectedFiltersKey = 'selected_filters';
const String _kSelectedPeriodKey = 'selected_period';
const String _kCustomPeriodStartKey = 'custom_period_start';
const String _kCustomPeriodEndKey = 'custom_period_end';

const String _defaultSource = 'source';

const String _kWarningText =
    '⚠️ Нужно выбрать хотя бы один показатель, группу и фильтр.';
const String _kLoadingText = 'Загрузка данных...';
const String _kTitle = 'Yandex Main Stats';

class MainPage extends StatefulWidget {
  final String token;
  final YandexApiService apiService;
  MainPage({super.key, required this.token, YandexApiService? apiService})
    : apiService = apiService ?? YandexApiService();

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late Future<ReportResponse> _statsFuture = Future.value(
    ReportResponse(reportTitle: '', points: [], periods: []),
  );

  List<TreeField> allFields = [];
  List<TreeField> selectedIndicators = [];
  List<TreeField> selectedGroups = <TreeField>[];
  List<String> selectedFilters = [];
  PeriodOption selectedPeriod = PeriodOption.today;
  DateTimeRange? customRange;
  bool loadingData = true;
  bool loadingFields = true;
  bool filtersInitialized = false;
  bool statsError = false;
  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = false;
  final List<ReportPoint> _accumulatedPoints = [];
  final ScrollController _scrollController = ScrollController();
  bool _loadingMore = false;

  bool get hasValidSelections =>
      selectedIndicators.isNotEmpty && selectedGroups.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initialize();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          _hasMore &&
          !loadingData) {
        _fetchStats(append: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedPeriod = prefs.getString(_kSelectedPeriodKey);
    final cachedIndicators = await loadTreeFields(
      prefs,
      _kSelectedIndicatorsKey,
      _defaultSource,
    );
    final cachedGroups =
        (await loadTreeFields(
          prefs,
          _kSelectedGroupsKey,
          _defaultSource,
        )).toSet();
    final cachedFilters = prefs.getStringList(_kSelectedFiltersKey) ?? [];

    if (cachedPeriod != null) {
      if (cachedPeriod == PeriodOption.custom.name) {
        final startStr = prefs.getString(_kCustomPeriodStartKey);
        final endStr = prefs.getString(_kCustomPeriodEndKey);
        if (startStr != null && endStr != null) {
          customRange = DateTimeRange(
            start: DateTime.parse(startStr),
            end: DateTime.parse(endStr),
          );
        }
      }
      selectedPeriod = PeriodOption.values.firstWhere(
        (e) => e.name == cachedPeriod,
        orElse: () => PeriodOption.today,
      );
    }

    selectedIndicators = cachedIndicators;
    selectedGroups =
        cachedGroups.where((it) {
          if (it.isSelection()) return it.selectedChildId != null;
          return true;
        }).toList();
    selectedFilters = cachedFilters;
    filtersInitialized = true;

    final fields = await widget.apiService.fetchAvailableFields(widget.token);
    setState(() {
      allFields = fields;
      loadingFields = false;
    });

    if (selectedIndicators.isEmpty) {
      selectedIndicators =
          fields
              .where(
                (f) =>
                    f.source == TreeField.kSourceFields ||
                    f.source == TreeField.kSourceIndicators,
              )
              .take(1)
              .toList();
    }

    if (selectedGroups.isEmpty) {
      selectedGroups =
          fields
              .where(
                (f) =>
                    f.source == TreeField.kSourceDimension ||
                    f.source == TreeField.kSourceEntityFields,
              )
              .take(2)
              .toList();
    }

    _fetchStats();
  }

  Future<void> saveTreeFields(
    SharedPreferences prefs,
    String key,
    List<TreeField> fields,
  ) async {
    final fieldJsonList = fields.map((f) => f.toJson()).toList();
    final encoded = jsonEncode(fieldJsonList);
    await prefs.setString(key, encoded);
  }

  Future<List<TreeField>> loadTreeFields(
    SharedPreferences prefs,
    String key,
    String source,
  ) async {
    final jsonString = prefs.getString(key);
    if (jsonString == null) return [];
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((e) => TreeField.fromJson(e as Map<String, dynamic>, source))
          .toList();
    } catch (e) {
      // print('Failed to decode TreeFields: $e');
      return [];
    }
  }

  Future<void> _fetchStats({bool append = false}) async {
    if (!hasValidSelections) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_kWarningText)));
      return;
    }

    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _offset = 0;
        _accumulatedPoints.clear();
        loadingData = true;
        statsError = false;
      });
    }

    sortSelectedByAllFieldsOrder();

    final prefs = await SharedPreferences.getInstance();
    saveTreeFields(prefs, _kSelectedIndicatorsKey, selectedIndicators);
    saveTreeFields(prefs, _kSelectedGroupsKey, selectedGroups.toList());
    prefs.setString(_kSelectedPeriodKey, selectedPeriod.name);
    if (selectedPeriod == PeriodOption.custom && customRange != null) {
      prefs.setString(
        _kCustomPeriodStartKey,
        customRange!.start.toIso8601String(),
      );
      prefs.setString(_kCustomPeriodEndKey, customRange!.end.toIso8601String());
    }
    prefs.setStringList(_kSelectedFiltersKey, selectedFilters);

    final now = DateTime.now();
    final from = selectedPeriod.isCustom() ? customRange?.start ?? now : null;
    final to = selectedPeriod.isCustom() ? customRange?.end ?? now : null;

    final iterableEntries = selectedGroups
        .where(
          (f) =>
              f.source == TreeField.kSourceDimension &&
              f.selectedChildId != null,
        )
        .map((f) => MapEntry(f.id, f.selectedChildId!));

    final dimensionFields = Map.fromEntries(iterableEntries);
    final entityFields =
        selectedGroups
            .map((f) => f.source == TreeField.kSourceEntityFields ? f.id : null)
            .whereType<String>()
            .toList();

    try {
      final stats = await widget.apiService.fetchMainStats(
        token: widget.token,
        from: from,
        to: to,
        period: !selectedPeriod.isCustom() ? selectedPeriod : null,
        fields: selectedIndicators.map((e) => e.id).toList(),
        dimensionFields: dimensionFields,
        entityFields: entityFields,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        _offset += _limit;
        _accumulatedPoints.addAll(stats.points);
        _statsFuture = Future.value(
          ReportResponse(
            reportTitle: stats.reportTitle,
            periods: stats.periods,
            points: _accumulatedPoints,
          ),
        );
        _hasMore = stats.isLastPage == false;
      });
    } catch (e) {
      if (context.mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке данных: $e')),
        );
      }
      setState(() {
        statsError = true;
        _statsFuture = Future.value(
          ReportResponse(reportTitle: '', points: [], periods: []),
        );
      });
    } finally {
      if (append) {
        setState(() => _loadingMore = false);
      } else {
        setState(() => loadingData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(_kTitle)),
      body: FutureBuilder<ReportResponse>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final report =
              snapshot.data ??
              ReportResponse(reportTitle: '', points: [], periods: []);

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PeriodSelectorWidget(
                  selected: selectedPeriod,
                  onChanged: (p) async {
                    if (p.isCustom()) {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          customRange = picked;
                          selectedPeriod = p;
                        });
                        _fetchStats();
                      }
                    } else {
                      setState(() {
                        selectedPeriod = p;
                      });
                      _fetchStats();
                    }
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    loadingFields
                        ? getLoadingWithText('Загрузка полей ... ')
                        : FieldSelectorPanel(
                          allFields: allFields,
                          selectedIndicators: selectedIndicators,
                          selectedGroups: selectedGroups,
                          selectedFilters: selectedFilters,
                          onApply: (indicators, groups, filters) {
                            setState(() {
                              selectedIndicators = indicators;
                              selectedGroups = groups;
                              selectedFilters = filters;
                            });
                            _fetchStats();
                          },
                        ),
                    if (filtersInitialized && !hasValidSelections)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          _kWarningText,
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                loadingData
                    ? getLoadingWithText(_kLoadingText)
                    : Column(
                      children: [
                        SizedBox(height: 20),
                        MainStatsTable(
                          reportResponse: report,
                          availableFields: allFields,
                          selectedFieldIds:
                              selectedIndicators.map((e) => e.id).toList(),
                          selectedGroups:
                              selectedGroups.map((e) => e.id).toList(),
                        ),
                        if (_loadingMore) getLoadingWithText(_kLoadingText),
                        SummaryCardsWidget(
                          data: report.points,
                          fields: allFields,
                        ),
                      ],
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget getLoadingWithText(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 12),
            Text(text),
          ],
        ),
      ),
    );
  }

  void sortSelectedByAllFieldsOrder() {
    final idIndexMap = {
      for (var i = 0; i < allFields.length; i++) allFields[i].id: i,
    };

    selectedGroups.sort((a, b) {
      final indexA = idIndexMap[a.id] ?? 9999;
      final indexB = idIndexMap[b.id] ?? 9999;
      return indexA.compareTo(indexB);
    });

    selectedIndicators.sort((a, b) {
      final indexA = idIndexMap[a.id] ?? 9999;
      final indexB = idIndexMap[b.id] ?? 9999;
      return indexA.compareTo(indexB);
    });
  }
}
