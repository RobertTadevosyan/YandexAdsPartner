import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:adpocket/core/settings.dart';
import 'package:adpocket/services/long_period_guard.dart';

/// Tells the user that data was (or is being) assembled from short requests
/// because Yandex refuses long periods. Shown on the dashboard and in Reports.
class FallbackNotice extends StatelessWidget {
  const FallbackNotice({
    super.key,
    this.progress,
    this.requests,
    this.unavailable = const [],
  });

  /// (done, total) pieces while assembling; null once finished.
  final (int, int)? progress;

  /// Requests the finished result needed.
  final int? requests;

  /// Display names of metrics left empty because periods were combined.
  final List<String> unavailable;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>().strings;
    final scheme = Theme.of(context).colorScheme;
    String fill(String t, List<Object> v) {
      for (final x in v) {
        t = t.replaceFirst('%d', '$x').replaceFirst('%s', '$x');
      }
      return t;
    }

    final lines = <String>[
      fill(s['fallback.notice'], [LongPeriodGuard.maxSpanDays]),
      if (progress != null)
        fill(s['fallback.progress'], [progress!.$1, progress!.$2])
      else if (requests != null)
        fill(s['fallback.requests'], [requests!]),
      if (unavailable.isNotEmpty)
        fill(s['fallback.unavailable'], [unavailable.join(', ')]),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['fallback.title'],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value:
                          progress!.$2 == 0
                              ? null
                              : progress!.$1 / progress!.$2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
