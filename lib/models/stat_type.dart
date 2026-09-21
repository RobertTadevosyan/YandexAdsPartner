/// Report types of the Statistics API (`stat_type`). Each has its own metric
/// catalogue; the app fetches the tree per type.
enum StatType {
  main('main', 'Основная', 'Main'),
  mm('mm', 'Мобильная медиация', 'Mobile Mediation'),
  ssp('ssp', 'SSP', 'SSP'),
  dsp('dsp', 'DSP', 'DSP');

  final String value;
  final String labelRu;
  final String labelEn;
  const StatType(this.value, this.labelRu, this.labelEn);

  String label(String lang) => lang == 'ru' ? labelRu : labelEn;

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
    }
  }
}
