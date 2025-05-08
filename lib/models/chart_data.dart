class ChartData {
  final DateTime date;
  final double value;

  ChartData(this.date, this.value);

  static ChartData fromMap(Map<String, dynamic> map, String metric) {
    return ChartData(
      DateTime.parse(map['date']),
      (map[metric] is int) ? (map[metric] as int).toDouble() : (map[metric] as num).toDouble(),
    );
  }
}
