import 'package:flutter/material.dart';

const Color brandTeal = Color(0xFF006666);
const Color waterBlue = Color(0xFF0099CC);
const Color farmGreen = Color(0xFF4D8B31);
const Color appSurface = Color(0xFFF7FAF9);
const Color surfaceContainer = Color(0xFFE6E9E8);
const Color surfaceContainerLow = Color(0xFFFFFFFF);
const Color onSurface = Color(0xFF181C1C);
const Color onSurfaceVariant = Color(0xFF3F4948);
const Color outlineVariant = Color(0xFFBEC9C8);
const Color tealTint = Color(0xFFA2F0EF);

enum StatusTone { normal, warning, critical, resolved, info }

extension StatusToneX on StatusTone {
  Color get color {
    switch (this) {
      case StatusTone.normal:
        return farmGreen;
      case StatusTone.warning:
        return const Color(0xFFF39A00);
      case StatusTone.critical:
        return const Color(0xFFC62828);
      case StatusTone.resolved:
        return const Color(0xFF6BA84E);
      case StatusTone.info:
        return waterBlue;
    }
  }

  Color get border => color;

  Color get background {
    switch (this) {
      case StatusTone.normal:
        return const Color(0xFFEAF4E4);
      case StatusTone.warning:
        return const Color(0xFFFFF4D6);
      case StatusTone.critical:
        return const Color(0xFFFDE8E7);
      case StatusTone.resolved:
        return const Color(0xFFE7F3E5);
      case StatusTone.info:
        return const Color(0xFFE6F5FB);
    }
  }

  IconData get icon {
    switch (this) {
      case StatusTone.normal:
        return Icons.check_circle_outline;
      case StatusTone.warning:
        return Icons.warning_amber_outlined;
      case StatusTone.critical:
        return Icons.error_outline;
      case StatusTone.resolved:
        return Icons.check_circle;
      case StatusTone.info:
        return Icons.info_outline;
    }
  }
}

class MetricData {
  const MetricData({
    required this.title,
    required this.value,
    required this.unit,
    required this.statusLabel,
    required this.trendLabel,
    required this.updatedAt,
    required this.sparklineValues,
    required this.tone,
    required this.trendIcon,
  });

  final String title;
  final String value;
  final String unit;
  final String statusLabel;
  final String trendLabel;
  final String updatedAt;
  final List<double> sparklineValues;
  final StatusTone tone;
  final IconData trendIcon;
}

class AlertData {
  const AlertData({
    required this.severityLabel,
    required this.timeLabel,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.primaryActionLabel,
    required this.tone,
    required this.resolved,
  });

  final String severityLabel;
  final String timeLabel;
  final String title;
  final String description;
  final String actionLabel;
  final String primaryActionLabel;
  final StatusTone tone;
  final bool resolved;
}

class RecommendationData {
  const RecommendationData({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.tone,
  });

  final String title;
  final String body;
  final String actionLabel;
  final StatusTone tone;
}

class RiskEventData {
  const RiskEventData({
    required this.timeLabel,
    required this.title,
    required this.description,
    required this.tone,
  });

  final String timeLabel;
  final String title;
  final String description;
  final StatusTone tone;
}

class TrendSeriesData {
  const TrendSeriesData({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<double> values;
  final Color color;
}

class MonitoringPeriodData {
  const MonitoringPeriodData({
    required this.label,
    required this.metrics,
    required this.chartSeries,
  });

  final String label;
  final List<MetricData> metrics;
  final List<TrendSeriesData> chartSeries;
}

class ProfileStatData {
  const ProfileStatData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class ProfileMenuItemData {
  const ProfileMenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class ProfileData {
  const ProfileData({
    required this.operatorName,
    required this.farmName,
    required this.syncStatus,
    required this.syncTone,
    required this.stats,
    required this.menuItems,
  });

  final String operatorName;
  final String farmName;
  final String syncStatus;
  final StatusTone syncTone;
  final List<ProfileStatData> stats;
  final List<ProfileMenuItemData> menuItems;
}

class FarmOverviewData {
  const FarmOverviewData({
    required this.appName,
    required this.pondName,
    required this.statusLabel,
    required this.statusTone,
    required this.riskScore,
    required this.riskLabel,
    required this.riskTone,
    required this.summary,
    required this.homeMetrics,
    required this.recentAlert,
    required this.homeRecommendation,
  });

  final String appName;
  final String pondName;
  final String statusLabel;
  final StatusTone statusTone;
  final int riskScore;
  final String riskLabel;
  final StatusTone riskTone;
  final String summary;
  final List<MetricData> homeMetrics;
  final AlertData? recentAlert;
  final RecommendationData homeRecommendation;
}

class RiskAnalysisData {
  const RiskAnalysisData({
    required this.subtitle,
    required this.riskScore,
    required this.riskLabel,
    required this.changeLabel,
    required this.summary,
    required this.tone,
    required this.events,
    required this.recommendations,
  });

  final String subtitle;
  final int riskScore;
  final String riskLabel;
  final String changeLabel;
  final String summary;
  final StatusTone tone;
  final List<RiskEventData> events;
  final List<RecommendationData> recommendations;
}

const mockOverview = FarmOverviewData(
  appName: 'Tilapulse',
  pondName: 'Green Valley Pond',
  statusLabel: 'Overall Status: Normal',
  statusTone: StatusTone.normal,
  riskScore: 15,
  riskLabel: 'Low Risk',
  riskTone: StatusTone.normal,
  summary: 'Conditions are stable. No immediate action needed.',
  homeMetrics: [
    MetricData(
      title: 'Water Temp',
      value: '28',
      unit: '°C',
      statusLabel: 'Normal',
      trendLabel: 'Stable',
      updatedAt: 'Updated 5m ago',
      sparklineValues: [6, 7, 6.5, 7.2, 7, 7.4],
      tone: StatusTone.normal,
      trendIcon: Icons.trending_flat,
    ),
    MetricData(
      title: 'pH',
      value: '7.2',
      unit: '',
      statusLabel: 'Normal',
      trendLabel: 'Stable',
      updatedAt: 'Updated 5m ago',
      sparklineValues: [6.8, 7.0, 7.1, 7.2, 7.1, 7.2],
      tone: StatusTone.normal,
      trendIcon: Icons.trending_flat,
    ),
    MetricData(
      title: 'Dissolved Oxygen',
      value: '6.5',
      unit: 'mg/L',
      statusLabel: 'Warning',
      trendLabel: 'Decreasing',
      updatedAt: 'Updated 5m ago',
      sparklineValues: [8.0, 7.8, 7.4, 7.0, 6.8, 6.5],
      tone: StatusTone.warning,
      trendIcon: Icons.trending_down,
    ),
  ],
  recentAlert: AlertData(
    severityLabel: 'Recent Alert',
    timeLabel: '10 mins ago',
    title: 'Oxygen level slightly dipping.',
    description: 'Sensor trend is moving down. Aeration may need to be increased if the fall continues.',
    actionLabel: 'Increase aeration gradually',
    primaryActionLabel: 'View details',
    tone: StatusTone.warning,
    resolved: false,
  ),
  homeRecommendation: RecommendationData(
    title: 'Keep the current aeration schedule',
    body: 'The pond still reads inside the safe operating band, but the oxygen trend should be watched over the next few hours.',
    actionLabel: 'Apply',
    tone: StatusTone.normal,
  ),
);

const monitoringPeriods = [
  MonitoringPeriodData(
    label: 'Today',
    metrics: [
      MetricData(
        title: 'Temperature',
        value: '28',
        unit: '°C',
        statusLabel: 'Normal',
        trendLabel: 'Stable',
        updatedAt: 'Updated 5m ago',
        sparklineValues: [5, 6, 5.5, 6.2, 6.3, 6.4],
        tone: StatusTone.normal,
        trendIcon: Icons.trending_flat,
      ),
      MetricData(
        title: 'pH Level',
        value: '7.2',
        unit: '',
        statusLabel: 'Normal',
        trendLabel: 'Stable',
        updatedAt: 'Updated 5m ago',
        sparklineValues: [6.7, 6.9, 7.1, 7.2, 7.2, 7.1],
        tone: StatusTone.normal,
        trendIcon: Icons.trending_flat,
      ),
      MetricData(
        title: 'Dissolved Oxygen',
        value: '6.5',
        unit: 'mg/L',
        statusLabel: 'Warning',
        trendLabel: 'Decreasing',
        updatedAt: 'Updated 5m ago',
        sparklineValues: [7.8, 7.4, 7.2, 7.0, 6.7, 6.5],
        tone: StatusTone.warning,
        trendIcon: Icons.trending_down,
      ),
    ],
    chartSeries: [
      TrendSeriesData(label: 'Temp', values: [2.1, 2.8, 3.1, 3.4, 3.6], color: brandTeal),
      TrendSeriesData(label: 'Oxygen', values: [3.0, 2.8, 2.6, 2.4, 2.1], color: waterBlue),
    ],
  ),
  MonitoringPeriodData(
    label: '7 Days',
    metrics: [
      MetricData(
        title: 'Average Temp',
        value: '27.4',
        unit: '°C',
        statusLabel: 'Normal',
        trendLabel: 'Flat',
        updatedAt: 'Updated 1h ago',
        sparklineValues: [4.6, 4.9, 5.2, 5.1, 5.0, 5.3],
        tone: StatusTone.normal,
        trendIcon: Icons.trending_flat,
      ),
      MetricData(
        title: 'Average pH',
        value: '7.1',
        unit: '',
        statusLabel: 'Normal',
        trendLabel: 'Flat',
        updatedAt: 'Updated 1h ago',
        sparklineValues: [6.8, 6.9, 7.0, 7.1, 7.1, 7.0],
        tone: StatusTone.normal,
        trendIcon: Icons.trending_flat,
      ),
      MetricData(
        title: 'Average DO',
        value: '6.8',
        unit: 'mg/L',
        statusLabel: 'Warning',
        trendLabel: 'Soft decline',
        updatedAt: 'Updated 1h ago',
        sparklineValues: [7.6, 7.4, 7.1, 6.9, 6.8, 6.7],
        tone: StatusTone.warning,
        trendIcon: Icons.trending_down,
      ),
    ],
    chartSeries: [
      TrendSeriesData(label: 'Temp', values: [2.2, 2.4, 2.9, 3.0, 3.2], color: brandTeal),
      TrendSeriesData(label: 'Oxygen', values: [3.4, 3.2, 3.0, 2.8, 2.7], color: waterBlue),
    ],
  ),
  MonitoringPeriodData(
    label: '30 Days',
    metrics: [
      MetricData(
        title: 'Monthly Temp',
        value: '27.8',
        unit: '°C',
        statusLabel: 'Normal',
        trendLabel: 'Seasonal',
        updatedAt: 'Updated today',
        sparklineValues: [4.1, 4.4, 4.8, 5.0, 5.1, 5.4],
        tone: StatusTone.normal,
        trendIcon: Icons.trending_flat,
      ),
      MetricData(
        title: 'Monthly pH',
        value: '7.0',
        unit: '',
        statusLabel: 'Normal',
        trendLabel: 'Seasonal',
        updatedAt: 'Updated today',
        sparklineValues: [6.7, 6.8, 6.9, 7.0, 7.1, 7.0],
        tone: StatusTone.normal,
        trendIcon: Icons.trending_flat,
      ),
      MetricData(
        title: 'Monthly DO',
        value: '6.6',
        unit: 'mg/L',
        statusLabel: 'Warning',
        trendLabel: 'Under watch',
        updatedAt: 'Updated today',
        sparklineValues: [7.5, 7.2, 7.0, 6.9, 6.7, 6.5],
        tone: StatusTone.warning,
        trendIcon: Icons.trending_down,
      ),
    ],
    chartSeries: [
      TrendSeriesData(label: 'Temp', values: [2.1, 2.5, 2.6, 2.9, 3.0], color: brandTeal),
      TrendSeriesData(label: 'Oxygen', values: [3.5, 3.1, 2.9, 2.8, 2.6], color: waterBlue),
    ],
  ),
];

const mockRiskAnalysis = RiskAnalysisData(
  subtitle: 'Real-time environmental stress assessment.',
  riskScore: 38,
  riskLabel: 'Risk: Moderate',
  changeLabel: 'Risk Increasing',
  summary:
      'Water temperature has risen by 2°C over the last 4 hours while Dissolved Oxygen has dropped. These changes increase the likelihood of stress-induced disease.',
  tone: StatusTone.warning,
  events: [
    RiskEventData(
      timeLabel: '11:30 AM',
      title: 'Temperature peak detected.',
      description: 'A short spike was observed across the north sampling line.',
      tone: StatusTone.critical,
    ),
    RiskEventData(
      timeLabel: '10:00 AM',
      title: 'Oxygen levels began to drop.',
      description: 'The decline has continued without recovery across two sensor clusters.',
      tone: StatusTone.warning,
    ),
  ],
  recommendations: [
    RecommendationData(
      title: 'Review aeration coverage',
      body: 'Expand aeration for the evening window to reduce oxygen stress and slow the risk climb.',
      actionLabel: 'View plan',
      tone: StatusTone.normal,
    ),
    RecommendationData(
      title: 'Check inflow temperature',
      body: 'Validate the incoming water source and compare it with the pond average to isolate the heat shift.',
      actionLabel: 'Dismiss',
      tone: StatusTone.info,
    ),
  ],
);

const mockAlerts = [
  AlertData(
    severityLabel: 'Critical',
    timeLabel: '10 mins ago',
    title: 'Low Dissolved Oxygen',
    description: 'Pond 3 oxygen levels dropped below safe threshold (3.2 mg/L).',
    actionLabel: 'Increase aeration immediately.',
    primaryActionLabel: 'Resolve',
    tone: StatusTone.critical,
    resolved: false,
  ),
  AlertData(
    severityLabel: 'Warning',
    timeLabel: '2 hours ago',
    title: 'Temperature Spike',
    description: 'Surface temperature reaching 32°C in Sector A.',
    actionLabel: 'Monitor pond surface activity.',
    primaryActionLabel: 'Acknowledge',
    tone: StatusTone.warning,
    resolved: false,
  ),
  AlertData(
    severityLabel: 'Resolved',
    timeLabel: '5 hours ago',
    title: 'pH Stabilized',
    description: 'pH returned to the safe band after the morning correction cycle.',
    actionLabel: 'No further action required.',
    primaryActionLabel: 'Review',
    tone: StatusTone.resolved,
    resolved: true,
  ),
];

const mockProfile = ProfileData(
  operatorName: 'Jed Cruz',
  farmName: 'TilaPulse Mock Farm',
  syncStatus: 'Last sync 3 minutes ago',
  syncTone: StatusTone.info,
  stats: [
    ProfileStatData(icon: Icons.sensors, value: '12', label: 'Sensors online', color: brandTeal),
    ProfileStatData(icon: Icons.water_drop_outlined, value: '4', label: 'Ponds monitored', color: waterBlue),
    ProfileStatData(icon: Icons.warning_amber_outlined, value: '3', label: 'Open alerts', color: Color(0xFFF39A00)),
    ProfileStatData(icon: Icons.check_circle_outline, value: '98%', label: 'Data health', color: farmGreen),
  ],
  menuItems: [
    ProfileMenuItemData(icon: Icons.account_tree_outlined, title: 'Farm hierarchy', subtitle: 'Manage ponds, sectors, and sensors'),
    ProfileMenuItemData(icon: Icons.notifications_active_outlined, title: 'Alert routing', subtitle: 'Configure SMS and in-app thresholds'),
    ProfileMenuItemData(icon: Icons.download_outlined, title: 'Export reports', subtitle: 'Generate weekly PDF summaries'),
  ],
);
