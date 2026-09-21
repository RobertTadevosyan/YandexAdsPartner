import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adpocket/core/strings.dart';

/// User preferences shared by every screen: language, currency, VAT, theme.
class AppSettings extends ChangeNotifier {
  static const _kLang = 'settings.lang';
  static const _kCurrency = 'settings.currency';
  static const _kVat = 'settings.vat';
  static const _kTheme = 'settings.theme';
  static const _kAppLock = 'settings.appLock';
  static const _kWidgetRefresh = 'settings.widgetRefresh';
  static const _kNotifyDaily = 'settings.notifyDaily';
  static const _kNotifyMonthly = 'settings.notifyMonthly';
  static const _kNotifyAlerts = 'settings.notifyAlerts';
  static const _kNotifyHour = 'settings.notifyHour';
  static const _kNotifyMinute = 'settings.notifyMinute';

  static const currencies = ['RUB', 'USD', 'EUR', 'KZT', 'BYN', 'AMD', 'AED'];

  String _lang;
  String _currency;
  bool _vat;
  ThemeMode _themeMode;
  bool _appLock;
  bool _widgetRefresh;
  bool _notifyDaily;
  bool _notifyMonthly;
  bool _notifyAlerts;
  int _notifyHour;
  int _notifyMinute;

  AppSettings({
    String? lang,
    String currency = 'RUB',
    bool vat = false,
    ThemeMode themeMode = ThemeMode.system,
    bool appLock = false,
    bool widgetRefresh = false,
    bool notifyDaily = false,
    bool notifyMonthly = false,
    bool notifyAlerts = false,
    int notifyHour = 9,
    int notifyMinute = 0,
  }) : _lang = lang ?? _deviceLang(),
       _currency = currency,
       _vat = vat,
       _themeMode = themeMode,
       _appLock = appLock,
       _widgetRefresh = widgetRefresh,
       _notifyDaily = notifyDaily,
       _notifyMonthly = notifyMonthly,
       _notifyAlerts = notifyAlerts,
       _notifyHour = notifyHour,
       _notifyMinute = notifyMinute;

  static String _deviceLang() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return AppStrings.supported.contains(code) ? code : 'en';
  }

  String get lang => _lang;
  String get currency => _currency;
  bool get vat => _vat;
  ThemeMode get themeMode => _themeMode;
  bool get appLock => _appLock;
  bool get widgetRefresh => _widgetRefresh;
  bool get notifyDaily => _notifyDaily;
  bool get notifyMonthly => _notifyMonthly;
  bool get notifyAlerts => _notifyAlerts;
  int get notifyHour => _notifyHour;
  int get notifyMinute => _notifyMinute;
  bool get anyNotifications => _notifyDaily || _notifyMonthly || _notifyAlerts;
  AppStrings get strings => AppStrings(_lang);
  Locale get locale => Locale(_lang);

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString(_kTheme);
    return AppSettings(
      lang: prefs.getString(_kLang),
      currency: prefs.getString(_kCurrency) ?? 'RUB',
      vat: prefs.getBool(_kVat) ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == theme,
        orElse: () => ThemeMode.system,
      ),
      appLock: prefs.getBool(_kAppLock) ?? false,
      widgetRefresh: prefs.getBool(_kWidgetRefresh) ?? false,
      notifyDaily: prefs.getBool(_kNotifyDaily) ?? false,
      notifyMonthly: prefs.getBool(_kNotifyMonthly) ?? false,
      notifyAlerts: prefs.getBool(_kNotifyAlerts) ?? false,
      notifyHour: prefs.getInt(_kNotifyHour) ?? 9,
      notifyMinute: prefs.getInt(_kNotifyMinute) ?? 0,
    );
  }

  Future<void> setLang(String value) async {
    if (!AppStrings.supported.contains(value) || value == _lang) return;
    _lang = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, value);
  }

  Future<void> setCurrency(String value) async {
    if (value == _currency) return;
    _currency = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, value);
  }

  Future<void> setVat(bool value) async {
    if (value == _vat) return;
    _vat = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVat, value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, value.name);
  }

  Future<void> setAppLock(bool value) async {
    if (value == _appLock) return;
    _appLock = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAppLock, value);
  }

  Future<void> setWidgetRefresh(bool value) async {
    if (value == _widgetRefresh) return;
    _widgetRefresh = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWidgetRefresh, value);
  }

  Future<void> setNotifyDaily(bool value) async {
    if (value == _notifyDaily) return;
    _notifyDaily = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifyDaily, value);
  }

  Future<void> setNotifyMonthly(bool value) async {
    if (value == _notifyMonthly) return;
    _notifyMonthly = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifyMonthly, value);
  }

  Future<void> setNotifyAlerts(bool value) async {
    if (value == _notifyAlerts) return;
    _notifyAlerts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifyAlerts, value);
  }

  Future<void> setNotifyTime(int hour, int minute) async {
    if (hour == _notifyHour && minute == _notifyMinute) return;
    _notifyHour = hour;
    _notifyMinute = minute;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNotifyHour, hour);
    await prefs.setInt(_kNotifyMinute, minute);
  }
}
