import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:adpocket/core/formatters.dart';
import 'package:adpocket/theme.dart';

/// A labelled (x, y) sample for the time-series chart.
class ChartSample {
  final DateTime date;
  final double value;
  const ChartSample(this.date, this.value);
}

/// Smooth area line chart for a daily series.
class TrendLineChart extends StatelessWidget {
  final List<ChartSample> samples;
  final String unit;
  final String? currency;
  final String lang;
  final Color color;
  final double height;

  const TrendLineChart({
    required this.samples,
    required this.unit,
    required this.lang,
    this.currency,
    this.color = Brand.chartLine,
    this.height = 180,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (samples.isEmpty) return SizedBox(height: height);
    final maxY = samples.fold<double>(0, (m, s) => s.value > m ? s.value : m);
    final top = maxY == 0 ? 1.0 : maxY * 1.15;
    final n = samples.length;
    final labelEvery =
        n <= 7 ? 1 : (n <= 14 ? 2 : (n <= 31 ? 6 : (n / 6).ceil()));

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (n - 1).toDouble(),
          minY: 0,
          maxY: top,
          clipData: const FlClipData.none(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine:
                (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: top / 4,
                getTitlesWidget: (v, meta) {
                  if (v == 0 || v >= top) return const SizedBox.shrink();
                  return Text(
                    Fmt.measure(v, unit: unit, lang: lang, compact: true),
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= n || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      Fmt.dayMonth(samples[i].date, lang),
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems:
                  (spots) =>
                      spots.map((s) {
                        final sample = samples[s.x.round().clamp(0, n - 1)];
                        return LineTooltipItem(
                          '${Fmt.date(sample.date, lang)}\n',
                          TextStyle(
                            color: scheme.onInverseSurface,
                            fontSize: 11,
                          ),
                          children: [
                            TextSpan(
                              text: Fmt.measure(
                                sample.value,
                                unit: unit,
                                currency: currency,
                                lang: lang,
                              ),
                              style: TextStyle(
                                color: scheme.onInverseSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < n; i++)
                  FlSpot(i.toDouble(), samples[i].value),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, bar) => n <= 14 || spot.x == n - 1,
                getDotPainter:
                    (spot, _, bar, __) => FlDotCirclePainter(
                      radius: 3,
                      color: color,
                      strokeWidth: 1.5,
                      strokeColor: scheme.surface,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.35),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }
}

/// Horizontal ranking bars for categorical breakdowns (top apps, countries).
class RankingBars extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final String unit;
  final String? currency;
  final String lang;
  final Color color;
  final void Function(String label)? onTap;

  const RankingBars({
    required this.entries,
    required this.unit,
    required this.lang,
    this.currency,
    this.color = Brand.chartLine,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    return Column(
      children: [
        for (final e in entries)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(e.key),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key.isEmpty ? '—' : e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Fmt.measure(
                          e.value,
                          unit: unit,
                          currency: currency,
                          lang: lang,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : (e.value / max).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
