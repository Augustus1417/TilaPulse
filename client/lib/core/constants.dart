const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://tilapulse.onrender.com',
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
