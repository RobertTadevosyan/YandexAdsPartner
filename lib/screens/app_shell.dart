import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adpocket/core/layout.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/models/report_preset.dart';
import 'package:adpocket/screens/ad_units_screen.dart';
import 'package:adpocket/screens/dashboard_screen.dart';
import 'package:adpocket/screens/reports_screen.dart';
import 'package:adpocket/screens/settings_screen.dart';

/// Bottom-navigation container for the four main sections.
/// Build-time switch for the Ad units tab: `--dart-define=ADPOCKET_AD_UNITS=true`.
const bool kAdUnitsEnabled = bool.fromEnvironment('ADPOCKET_AD_UNITS');

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;
  ReportPreset? _pendingPreset;
  final _reportsKey = GlobalKey<ReportsScreenState>();

  /// Switches to the Reports tab pre-configured with [preset].
  void openReport(ReportPreset preset) {
    setState(() {
      _pendingPreset = preset;
      _index = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportsKey.currentState?.applyPreset(preset, run: true);
      _pendingPreset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>().strings;
    // The Ad units tab (Inventory API) stays hidden until the feature is
    // switched on at build time or the user already holds an inventory
    // token; Yandex issues those tokens to few partners, and store reviewers
    // cannot exercise the tab.
    final showAdUnits =
        kAdUnitsEnabled || context.watch<AppSession>().hasInventoryToken;
    final pages = <Widget>[
      DashboardScreen(onOpenReport: openReport),
      ReportsScreen(key: _reportsKey, initialPreset: _pendingPreset),
      if (showAdUnits) const AdUnitsScreen(),
      const SettingsScreen(),
    ];
    if (_index >= pages.length) _index = pages.length - 1;
    final body = IndexedStack(index: _index, children: pages);
    final tabs = <({IconData icon, IconData selected, String label})>[
      (
        icon: Icons.dashboard_outlined,
        selected: Icons.dashboard,
        label: s['tab.dashboard'],
      ),
      (
        icon: Icons.table_chart_outlined,
        selected: Icons.table_chart,
        label: s['tab.reports'],
      ),
      if (showAdUnits)
        (
          icon: Icons.view_quilt_outlined,
          selected: Icons.view_quilt,
          label: s['tab.adunits'],
        ),
      (
        icon: Icons.settings_outlined,
        selected: Icons.settings,
        label: s['tab.settings'],
      ),
    ];

    // Phones: bottom bar. Tablets, unfolded foldables and landscape phones:
    // a side rail, so the content keeps a sensible width.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Layout.of(constraints.maxWidth) == FormFactor.compact) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selected),
                    label: t.label,
                  ),
              ],
            ),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.9,
                  destinations: [
                    for (final t in tabs)
                      NavigationRailDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.selected),
                        label: Text(t.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}
