/// Report types of the Statistics API (`stat_type`). Each has its own metric
/// catalogue; the app fetches the tree per type.
enum StatType {
  main('main', 'Основная', 'Main'),
  mm('mm', 'Мобильная медиация', 'Mobile Mediation'),
  ssp('ssp', 'SSP', 'SSP'),
  dsp('dsp', 'DSP', 'DSP'),

  // AdMob accounts only (their own built-in catalogue).
  admobNetwork('admob_network', 'Сеть AdMob', 'AdMob Network'),
  admobMediation('admob_mediation', 'Медиация', 'Mediation');

  final String value;
  final String labelRu;
  final String labelEn;
  const StatType(this.value, this.labelRu, this.labelEn);

  String label(String lang) => lang == 'ru' ? labelRu : labelEn;

  bool get isAdMob => this == admobNetwork || this == admobMediation;

  /// Types offered for an account: Yandex's four, or AdMob's two.
  static List<StatType> forAccount({required bool admob}) =>
      values.where((t) => t.isAdMob == admob).toList();

  static StatType defaultFor({required bool admob}) =>
      admob ? StatType.admobNetwork : StatType.main;

  static StatType fromValue(String? v) => StatType.values.firstWhere(
    (t) => t.value == v,
    orElse: () => StatType.main,
  );

  /// Metrics chosen when the user first opens a report type.
  List<String> get preferredMetrics {
    switch (this) {
      case StatType.main:
        return const [
          'partner_wo_nds',
          'shows',
          'clicks',
          'ecpm_partner_wo_nds',
        ];
      case StatType.mm:
        return const ['revenue_mm', 'impressions_mm', 'ecpm_mm', 'requests_mm'];
      case StatType.ssp:
        return const ['ssp_price', 'shows', 'ssp_cpm', 'fillrate'];
      case StatType.dsp:
        return const ['impressions'];
      case StatType.admobNetwork:
        return const [
          'estimated_earnings',
          'impressions',
          'clicks',
          'impression_rpm',
        ];
      case StatType.admobMediation:
        return const [
          'estimated_earnings',
          'impressions',
          'clicks',
          'observed_ecpm',
        ];
    }
  }
}
