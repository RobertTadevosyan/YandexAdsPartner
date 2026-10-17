import 'package:flutter/material.dart';
import 'package:adpocket/theme.dart';

/// Headline metric with an optional signed change versus a baseline.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final bool? deltaPositive;
  final String? deltaHint;
  final IconData? icon;
  final bool emphasized;

  const KpiCard({
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive,
    this.deltaHint,
    this.icon,
    this.emphasized = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = BrandPalette.of(context);
    final deltaColor =
        deltaPositive == null
            ? scheme.onSurfaceVariant
            : (deltaPositive! ? brand.positive : brand.negative);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: emphasized ? brand.heroStart : scheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: emphasized ? brand.onHero : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        emphasized
                            ? brand.onHero.withValues(alpha: 0.8)
                            : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: emphasized ? 26 : 20,
                fontWeight: FontWeight.w800,
                color: emphasized ? brand.onHero : scheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (delta != null || deltaHint != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (delta != null) ...[
                  Icon(
                    deltaPositive == null
                        ? Icons.remove
                        : (deltaPositive!
                            ? Icons.arrow_upward
                            : Icons.arrow_downward),
                    size: 13,
                    color: emphasized ? brand.onHero : deltaColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    delta!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: emphasized ? brand.onHero : deltaColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (deltaHint != null)
                  Expanded(
                    child: Text(
                      deltaHint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            emphasized
                                ? brand.onHero.withValues(alpha: 0.7)
                                : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
