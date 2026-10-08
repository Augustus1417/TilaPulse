const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.18.49:8000',
);

String get resolvedApiBaseUrl {
  return apiBaseUrl;
}

const temperatureMin = 24.0;
const temperatureMax = 32.0;
const phMin = 6.5;
const phMax = 8.5;
const dissolvedOxygenMin = 5.0;
const bocpdAlertThreshold = 0.5;

String formatTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} $hour:$minute $period';
}

String formatRelativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp.toLocal());
  if (difference.isNegative || difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) {
    final value = difference.inMinutes;
    return '$value minute${value == 1 ? '' : 's'} ago';
  }
  if (difference.inHours < 24) {
    final value = difference.inHours;
    return '$value hour${value == 1 ? '' : 's'} ago';
  }
  final value = difference.inDays;
  return '$value day${value == 1 ? '' : 's'} ago';
}
