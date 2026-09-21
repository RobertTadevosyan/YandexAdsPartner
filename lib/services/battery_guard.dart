import 'dart:io';

import 'package:flutter/services.dart';

/// Android battery-optimisation state. Vendors (Samsung, Xiaomi, Huawei,
/// Oppo, Vivo, OnePlus…) stop WorkManager jobs of apps they consider idle;
/// the widget's background refresh needs an exemption to be reliable.
class BatteryGuard {
  static const _channel = MethodChannel('app.adpocket.yan/battery');

  static bool get supported => Platform.isAndroid;

  static Future<bool> isExempt() async {
    if (!supported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Shows the system "allow to run in background" dialog. Returns false when
  /// the intent could not be launched (some vendors hide it).
  static Future<bool> requestExemption() async {
    if (!supported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> openAppSettings() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('openAppSettings');
    } on MissingPluginException {
      // ignore
    }
  }

  /// Lower-case manufacturer id: samsung, xiaomi, huawei, honor, oppo,
  /// realme, oneplus, vivo, … Empty when unknown.
  static Future<String> manufacturer() async {
    if (!supported) return '';
    try {
      return (await _channel.invokeMethod<String>('manufacturer') ?? '')
          .toLowerCase();
    } on MissingPluginException {
      return '';
    }
  }

  /// Key of the vendor-specific hint string, or null for stock Android.
  static String? hintKey(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('samsung')) return 'battery.hint.samsung';
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return 'battery.hint.xiaomi';
    }
    if (m.contains('huawei') || m.contains('honor')) {
      return 'battery.hint.huawei';
    }
    if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) {
      return 'battery.hint.oppo';
    }
    if (m.contains('vivo') || m.contains('iqoo')) return 'battery.hint.vivo';
    return null;
  }
}
