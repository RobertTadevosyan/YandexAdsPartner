/// Mobile ad unit from the Advertising Inventory Management API.
class AdUnitStrategy {
  final String type; // MaxRevenueStrategy | MinECpmStrategy | MinCpmVStrategy
  final double? minCpm;

  const AdUnitStrategy({required this.type, this.minCpm});

  static const types = [
    'MaxRevenueStrategy',
    'MinECpmStrategy',
    'MinCpmVStrategy',
  ];

  bool get hasFloor => type != 'MaxRevenueStrategy';

  factory AdUnitStrategy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AdUnitStrategy(type: 'MaxRevenueStrategy');
    return AdUnitStrategy(
      type: (json['type'] as String?) ?? 'MaxRevenueStrategy',
      minCpm: (json['mincpm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (hasFloor && minCpm != null) 'mincpm': minCpm,
  };
}

class AdUnit {
  final String id;
  final String type;
  final num applicationId;
  final String caption;
  final DateTime? createDate;
  final bool editable;
  final String status; // ENABLED | ARCHIVED | UNKNOWN
  final AdUnitStrategy strategy;
  final String? currencyType;
  final num? currencyValue;

  const AdUnit({
    required this.id,
    required this.type,
    required this.applicationId,
    required this.caption,
    required this.createDate,
    required this.editable,
    required this.status,
    required this.strategy,
    this.currencyType,
    this.currencyValue,
  });

  bool get isArchived => status == 'ARCHIVED';

  /// Normalised kind: banner | interstitial | rewarded | native | appopen
  String get kind {
    final t = type.toLowerCase();
    if (t.contains('interstitial')) return 'interstitial';
    if (t.contains('reward')) return 'rewarded';
    if (t.contains('native')) return 'native';
    if (t.contains('open')) return 'appopen';
    return 'banner';
  }

  factory AdUnit.fromJson(Map<String, dynamic> json) => AdUnit(
    id: (json['id'] as String?) ?? '',
    type: (json['type'] as String?) ?? '',
    applicationId: (json['applicationId'] as num?) ?? 0,
    caption: (json['caption'] as String?) ?? '',
    createDate: DateTime.tryParse((json['createDate'] as String?) ?? ''),
    editable: json['editable'] == true,
    status: (json['status'] as String?) ?? 'UNKNOWN',
    strategy: AdUnitStrategy.fromJson(
      json['strategy'] as Map<String, dynamic>?,
    ),
    currencyType: json['currencyType'] as String?,
    currencyValue: json['currencyValue'] as num?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'applicationId': applicationId,
    'caption': caption,
    'createDate': createDate?.toIso8601String(),
    'editable': editable,
    'status': status,
    'strategy': strategy.toJson(),
    if (currencyType != null) 'currencyType': currencyType,
    if (currencyValue != null) 'currencyValue': currencyValue,
  };
}
