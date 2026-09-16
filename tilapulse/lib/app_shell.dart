import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tilapulse/mock_data.dart';

class TilapulseApp extends StatelessWidget {
  const TilapulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandTeal,
      brightness: Brightness.light,
    ).copyWith(
      primary: brandTeal,
      secondary: waterBlue,
      tertiary: farmGreen,
      surface: appSurface,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tilapulse',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: appSurface,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: appSurface,
          surfaceTintColor: Colors.transparent,
          foregroundColor: brandTeal,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
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
          bodyLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: onSurfaceVariant,
          ),
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
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _pages = [
    HomeScreen(),
    MonitoringScreen(),
    RiskScreen(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: appSurface,
          indicatorColor: brandTeal.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? brandTeal : onSurfaceVariant,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Monitor'),
            NavigationDestination(icon: Icon(Icons.stacked_line_chart_outlined), selectedIcon: Icon(Icons.stacked_line_chart), label: 'Risk'),
            NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ===== HOME SCREEN =====
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final overview = mockOverview;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.waves, size: 24, color: brandTeal),
                        const SizedBox(width: 8),
                        Text(
                          'Tilapulse',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: brandTeal),
                        ),
                      ],
                    ),
                    const Icon(Icons.notifications_none, size: 24, color: onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  overview.pondName,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                StatusIndicator(label: overview.statusLabel, tone: overview.statusTone),
              ],
            ),
          ),
          // Risk Score - Hero Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SimpleCard(
              child: Column(
                children: [
                  Text(
                    'Disease Risk Score',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 150,
                    child: RiskGaugeSimple(
                      progress: overview.riskScore / 100,
                      valueLabel: overview.riskScore.toString(),
                      label: overview.riskLabel,
                      tone: overview.riskTone,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    overview.summary,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Quick Sensor Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water Quality', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...overview.homeMetrics.map((metric) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CompactMetricCard(metric: metric),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Top Alert
          if (overview.recentAlert case AlertData alert)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AlertBannerSimple(alert: alert),
            ),
          const SizedBox(height: 20),
          // Recommendation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RecommendationCardSimple(recommendation: overview.homeRecommendation),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ===== MONITORING SCREEN =====
class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  int _selectedPeriodIndex = 0;

  @override
  Widget build(BuildContext context) {
    final period = monitoringPeriods[_selectedPeriodIndex];

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.waves, size: 24, color: brandTeal),
                    const SizedBox(width: 8),
                    Text('Tilapulse', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: brandTeal)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Water Quality Monitoring', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          // Time Period Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SimplePeriodSelector(
              labels: monitoringPeriods.map((p) => p.label).toList(),
              selectedIndex: _selectedPeriodIndex,
              onChanged: (index) => setState(() => _selectedPeriodIndex = index),
            ),
          ),
          const SizedBox(height: 20),
          // Sensor Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: period.metrics.map((metric) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SensorCard(metric: metric),
              )).toList(),
            ),
          ),
          // Trend Chart
          if (period.chartSeries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trend Overview', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SimpleCard(
                    child: SizedBox(
                      height: 140,
                      child: SimpleTrendChart(series: period.chartSeries),
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

// ===== RISK SCREEN =====
class RiskScreen extends StatelessWidget {
  const RiskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final analysis = mockRiskAnalysis;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.waves, size: 24, color: brandTeal),
                    const SizedBox(width: 8),
                    Text('Tilapulse', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: brandTeal)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Disease Risk', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Risk Score Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SimpleCard(
              child: Column(
                children: [
                  SizedBox(
                    height: 170,
                    child: RiskGaugeSimple(
                      progress: analysis.riskScore / 100,
                      valueLabel: analysis.riskScore.toString(),
                      label: analysis.riskLabel,
                      tone: analysis.tone,
                      showPercent: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_up, size: 16, color: onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(analysis.changeLabel, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Explanation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Why is the risk changing?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SimpleCard(
                  child: Text(
                    analysis.summary,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Recommendations
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recommendations', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...analysis.recommendations.take(2).map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RecommendationCardSimple(recommendation: rec),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ===== ALERTS SCREEN =====
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.waves, size: 24, color: brandTeal),
                    const SizedBox(width: 8),
                    Text('Tilapulse', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: brandTeal)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Alerts', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Alert List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: mockAlerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AlertCardSimple(alert: alert),
              )).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ===== PROFILE SCREEN =====
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = mockProfile;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.waves, size: 24, color: brandTeal),
                        const SizedBox(width: 8),
                        Text('Tilapulse', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: brandTeal)),
                      ],
                    ),
                    const Icon(Icons.settings_outlined, size: 24, color: onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Operator Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SimpleCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: tealTint,
                    child: const Icon(Icons.person, size: 28, color: brandTeal),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.operatorName, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(profile.farmName, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        StatusIndicator(label: profile.syncStatus, tone: profile.syncTone),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Stats Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: profile.stats.map((stat) => SimpleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(stat.icon, size: 20, color: stat.color),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stat.value, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(stat.label, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // Menu Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...profile.menuItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SimpleCard(
                    child: Row(
                      children: [
                        Icon(item.icon, size: 20, color: brandTeal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                              Text(item.subtitle, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20, color: onSurfaceVariant),
                      ],
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ===== SIMPLIFIED WIDGETS =====

// Simple card container
class SimpleCard extends StatelessWidget {
  const SimpleCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// Status indicator (replaces StatusRow)
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: tone.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
        ),
      ],
    );
  }
}

// Simple risk gauge for hero display
class RiskGaugeSimple extends StatelessWidget {
  const RiskGaugeSimple({
    super.key,
    required this.progress,
    required this.valueLabel,
    required this.label,
    required this.tone,
    this.showPercent = false,
  });

  final double progress;
  final String valueLabel;
  final String label;
  final StatusTone tone;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 110,
          width: 140,
          child: CustomPaint(
            painter: RiskGaugePainterSimple(progress: progress, tone: tone),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    valueLabel,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                        ),
                  ),
                  Text(
                    showPercent ? '%' : '/100',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tone.color),
          ),
        ),
      ],
    );
  }
}

// Simple risk gauge painter
class RiskGaugePainterSimple extends CustomPainter {
  const RiskGaugePainterSimple({required this.progress, required this.tone});

  final double progress;
  final StatusTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final radius = size.width * 0.35;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = outlineVariant.withValues(alpha: 0.3);

    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = tone.color;

    canvas.drawArc(rect, math.pi, -math.pi, false, background);
    canvas.drawArc(rect, math.pi, -math.pi * progress.clamp(0.0, 1.0), false, foreground);
  }

  @override
  bool shouldRepaint(covariant RiskGaugePainterSimple oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.tone != tone;
  }
}

// Compact metric card for home screen
class CompactMetricCard extends StatelessWidget {
  const CompactMetricCard({super.key, required this.metric});

  final MetricData metric;

  @override
  Widget build(BuildContext context) {
    return SimpleCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
                    children: [
                      TextSpan(text: metric.value),
                      if (metric.unit.isNotEmpty)
                        TextSpan(
                          text: ' ${metric.unit}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: metric.tone.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  metric.statusLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        color: metric.tone.color,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(metric.trendIcon, size: 14, color: metric.tone.color),
                  const SizedBox(width: 4),
                  Text(
                    metric.trendLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: metric.tone.color,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Sensor card for monitoring screen
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.metric});

  final MetricData metric;

  @override
  Widget build(BuildContext context) {
    return SimpleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(metric.title, style: Theme.of(context).textTheme.bodyMedium),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: metric.tone.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  metric.statusLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        color: metric.tone.color,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
              children: [
                TextSpan(text: metric.value),
                if (metric.unit.isNotEmpty)
                  TextSpan(
                    text: ' ${metric.unit}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(metric.trendIcon, size: 16, color: metric.tone.color),
              const SizedBox(width: 6),
              Text(
                metric.trendLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: metric.tone.color),
              ),
              const Spacer(),
              Text(
                metric.updatedAt,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Simple time period selector
class SimplePeriodSelector extends StatelessWidget {
  const SimplePeriodSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? brandTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    labels[index],
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: selected ? Colors.white : onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Simple trend chart for monitoring screen
class SimpleTrendChart extends StatelessWidget {
  const SimpleTrendChart({super.key, required this.series});

  final List<TrendSeriesData> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Center(
        child: Text(
          'No trend data',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: series
          .map(
            (line) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        line.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: line.values
                            .map(
                              (value) => Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: Container(
                                  width: 10,
                                  height: 20 + (value * 6),
                                  decoration: BoxDecoration(
                                    color: line.color.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// Simple alert banner for home screen
class AlertBannerSimple extends StatelessWidget {
  const AlertBannerSimple({super.key, required this.alert});

  final AlertData alert;

  @override
  Widget build(BuildContext context) {
    return SimpleCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            alert.tone.icon,
            size: 20,
            color: alert.tone.color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: alert.tone.color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  alert.timeLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simple recommendation card
class RecommendationCardSimple extends StatelessWidget {
  const RecommendationCardSimple({super.key, required this.recommendation});

  final RecommendationData recommendation;

  @override
  Widget build(BuildContext context) {
    return SimpleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: recommendation.tone.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: recommendation.tone.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {},
              child: Text(recommendation.actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple alert card for alerts screen
class AlertCardSimple extends StatelessWidget {
  const AlertCardSimple({super.key, required this.alert});

  final AlertData alert;

  @override
  Widget build(BuildContext context) {
    return SimpleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alert.tone.icon, size: 18, color: alert.tone.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: alert.tone.color,
                        decoration: alert.resolved ? TextDecoration.lineThrough : null,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: alert.tone.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Action: ${alert.actionLabel}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: alert.tone.color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                alert.timeLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: alert.tone.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  alert.severityLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        color: alert.tone.color,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


