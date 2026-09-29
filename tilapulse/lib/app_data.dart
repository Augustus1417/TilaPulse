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
  const MetricData({required this.title, required this.value, required this.unit, required this.statusLabel, required this.trendLabel, required this.updatedAt, required this.sparklineValues, required this.tone, required this.trendIcon});
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
  const AlertData({required this.severityLabel, required this.timeLabel, required this.title, required this.description, required this.actionLabel, required this.primaryActionLabel, required this.tone, required this.resolved});
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
  const RecommendationData({required this.title, required this.body, required this.actionLabel, required this.tone});
  final String title;
  final String body;
  final String actionLabel;
  final StatusTone tone;
}

class TrendSeriesData {
  const TrendSeriesData({required this.label, required this.values, required this.color});
  final String label;
  final List<double> values;
  final Color color;
}

class ProfileStatData {
  const ProfileStatData({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class ProfileMenuItemData {
  const ProfileMenuItemData({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
}
