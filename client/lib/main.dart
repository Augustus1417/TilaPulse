import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/pages/alerts_page.dart';
import 'package:client/pages/connect_device_page.dart';
import 'package:client/pages/home_page.dart';
import 'package:client/pages/monitor_page.dart';
import 'package:client/pages/risk_page.dart';
import 'package:client/pages/settings_page.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deviceState = DeviceState();
  await deviceState.load();
  deviceState.onReconnectRequired = () {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ConnectDevicePage()),
    );
  };
  runApp(
    ChangeNotifierProvider.value(
      value: deviceState,
      child: const TilaPulseApp(),
    ),
  );
}

class TilaPulseApp extends StatelessWidget {
  const TilaPulseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: appNavigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'Tilapulse',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: appSurface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandTeal,
      ).copyWith(primary: brandTeal, secondary: waterBlue, tertiary: farmGreen),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: TextStyle(fontSize: 15, color: onSurface),
        bodyMedium: TextStyle(fontSize: 13, color: onSurfaceVariant),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
    ),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _homeKey = GlobalKey<HomePageState>();
  final _riskKey = GlobalKey<RiskPageState>();
  late final List<Widget> _pages = [
    HomePage(key: _homeKey, onOpenRisk: () => setState(() => _index = 2)),
    const MonitorPage(),
    RiskPage(key: _riskKey),
    const AlertsPage(),
    const SettingsPage(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _index, children: _pages),
    bottomNavigationBar: NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: appSurface,
        indicatorColor: brandTeal.withValues(alpha: .14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? brandTeal
                : onSurfaceVariant,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          if (value == 0 && _index != 0) {
            _homeKey.currentState?.refresh();
          }
          if (value == 2 && _index != 2) {
            _riskKey.currentState?.refresh();
          }
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.stacked_line_chart_outlined),
            selectedIcon: Icon(Icons.stacked_line_chart),
            label: 'Risk',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    ),
  );
}
