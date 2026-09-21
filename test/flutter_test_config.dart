import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden images are generated on macOS. Other platforms rasterise text
/// slightly differently (about 3% of pixels on Ubuntu CI), so there we
/// accept a small difference instead of an exact match. Layout overflows
/// still fail the tests through the framework's error handling.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (!Platform.isMacOS) {
    final base = goldenFileComparator as LocalFileComparator;
    // LocalFileComparator takes a test-file URI and uses its directory.
    goldenFileComparator = _TolerantComparator(
      base.basedir.resolve('flutter_test_config.dart'),
      maxDiff: 0.06,
    );
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.basedir, {required this.maxDiff});

  final double maxDiff;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= maxDiff) return true;
    await generateFailureOutput(result, golden, basedir);
    throw FlutterError(
      'Golden "$golden": ${(result.diffPercent * 100).toStringAsFixed(2)}% '
      'of pixels differ, above the ${(maxDiff * 100).toStringAsFixed(0)}% '
      'allowed on ${Platform.operatingSystem}.',
    );
  }
}
