import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Window-size classes (Material 3 breakpoints). Phones are compact;
/// phones in landscape, small tablets and unfolded foldables are medium;
/// large tablets, desktops and Pixel Fold inner screens are expanded.
enum FormFactor { compact, medium, expanded }

class Layout {
  static const double compactMax = 600;
  static const double mediumMax = 840;

  static FormFactor of(double width) =>
      width < compactMax
          ? FormFactor.compact
          : (width < mediumMax ? FormFactor.medium : FormFactor.expanded);

  static FormFactor ofContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);

  /// Widest a column of cards should get before it stops looking like a phone
  /// app stretched across a tablet.
  static double contentMaxWidth(FormFactor f) {
    switch (f) {
      case FormFactor.compact:
        return double.infinity;
      case FormFactor.medium:
        return 720;
      case FormFactor.expanded:
        return 960;
    }
  }

  /// Number of grid columns for tiles of roughly [tileWidth] logical pixels.
  static int columns(
    double width, {
    required double tileWidth,
    int min = 1,
    int max = 6,
  }) => math.max(min, math.min(max, (width / tileWidth).floor()));
}

/// Centres [child] and caps its width on wide screens; a no-op on phones.
class PageBody extends StatelessWidget {
  final Widget child;
  const PageBody({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final f = Layout.of(constraints.maxWidth);
        if (f == FormFactor.compact) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Layout.contentMaxWidth(f)),
            child: child,
          ),
        );
      },
    );
  }
}
