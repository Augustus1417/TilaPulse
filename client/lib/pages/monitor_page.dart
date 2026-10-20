import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/core/constants.dart';
import 'package:client/models/reading.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

enum _ReadingRange { today, days7, days30, all }

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});
  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  static const _rowsPerPage = 15;

  String? _deviceId;
  List<Reading>? _readings;
  Object? _error;
  bool _refreshing = false;
  _ReadingRange _range = _ReadingRange.today;
  int _page = 1;

  void _sync(String? id) {
    if (id != null && id != _deviceId) {
      _deviceId = id;
      _readings = null;
      _page = 1;
      _load(id);
    }
  }

  Future<List<Reading>> _load(String id) async {
    try {
      final results = await Future.wait([
        apiService.fetchLatest(id),
        apiService.fetchReadings(id, limit: 200),
      ]);
      final readings = results[1] as List<Reading>;
      if (mounted && id == _deviceId) {
        setState(() {
          _readings = readings;
          _error = null;
        });
      }
      return readings;
    } catch (error) {
      if (mounted && id == _deviceId) setState(() => _error = error);
      rethrow;
    }
  }

  Future<void> _refresh() async {
    final id = _deviceId;
    if (id == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _load(id);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<Reading> _filteredReadings(List<Reading> readings) {
    if (_range == _ReadingRange.all) return readings.reversed.toList();
    final now = DateTime.now();
    final start = _range == _ReadingRange.today
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(Duration(days: _range == _ReadingRange.days7 ? 7 : 30));
    return readings
        .where((reading) => !reading.timestamp.toLocal().isBefore(start))
        .toList()
        .reversed
        .toList();
  }

  void _selectRange(_ReadingRange range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceState>();
    _sync(state.selected?.deviceId);
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.devices.isEmpty) {
      return const EmptyState(
        title: 'No devices connected',
        body: 'Open Settings to connect a device and start monitoring.',
      );
    }
    return Builder(
      builder: (context) {
        if (_error != null && _readings == null) {
          return const EmptyState(
            title: 'Unable to load history',
            body: 'Check the API connection and try again.',
          );
        }
        if (_readings == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final readings = _readings!;
        final filtered = _filteredReadings(readings);
        final pageCount = filtered.isEmpty
            ? 1
            : (filtered.length / _rowsPerPage).ceil();
        final currentPage = _page.clamp(1, pageCount);
        final start = (currentPage - 1) * _rowsPerPage;
        final pageReadings = filtered.skip(start).take(_rowsPerPage).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                PageHeader(
                  title: 'Water Quality Monitoring',
                  onRefresh: _refresh,
                  refreshing: _refreshing,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Refresh failed. Showing previously loaded readings.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: StatusTone.critical.color),
                    ),
                  ),
                _LatestReadingCard(
                  reading: readings.isEmpty ? null : readings.last,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _RangeSelector(
                    selected: _range,
                    onSelected: _selectRange,
                  ),
                ),
                if (pageReadings.isEmpty)
                  const EmptyState(
                    title: 'No readings in this range',
                    body:
                        'Try a wider time range or wait for the next reading.',
                  )
                else ...[
                  _ReadingTable(
                    readings: pageReadings,
                    today: _range == _ReadingRange.today,
                  ),
                  _Pagination(
                    page: currentPage,
                    pageCount: pageCount,
                    onPrevious: currentPage > 1
                        ? () => setState(() => _page = currentPage - 1)
                        : null,
                    onNext: currentPage < pageCount
                        ? () => setState(() => _page = currentPage + 1)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LatestReadingCard extends StatelessWidget {
  const _LatestReadingCard({required this.reading});
  final Reading? reading;

  @override
  Widget build(BuildContext context) {
    final current = reading;
    final age = current == null
        ? null
        : DateTime.now().difference(current.timestamp.toLocal());
    final stale = age != null && age.inMinutes > 5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outlineVariant.withValues(alpha: .4)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Latest reading',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (current == null)
                  Text(
                    'No readings yet',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Tooltip(
                    message: formatTimestamp(current.timestamp),
                    child: Text(
                      formatRelativeTime(current.timestamp),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: stale ? StatusTone.warning.color : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _HeroMetric(
                      label: 'Temperature',
                      value: current?.temperature.toStringAsFixed(1) ?? '--',
                      unit: '°C',
                      tone: current == null
                          ? null
                          : _temperatureTone(current.temperature),
                    ),
                  ),
                  _HeroDivider(),
                  Expanded(
                    child: _HeroMetric(
                      label: 'pH',
                      value: current?.ph.toStringAsFixed(2) ?? '--',
                      unit: '',
                      tone: current == null ? null : _phTone(current.ph),
                    ),
                  ),
                  _HeroDivider(),
                  Expanded(
                    child: _HeroMetric(
                      label: 'Dissolved oxygen',
                      value:
                          current?.dissolvedOxygen.toStringAsFixed(2) ?? '--',
                      unit: 'mg/L',
                      tone: current == null
                          ? null
                          : _oxygenTone(current.dissolvedOxygen),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 2),
    color: outlineVariant,
  );
}

StatusTone _temperatureTone(double value) =>
    value < temperatureMin || value > temperatureMax
    ? (value < temperatureMin ? StatusTone.warning : StatusTone.critical)
    : StatusTone.normal;

StatusTone _phTone(double value) => value < phMin || value > phMax
    ? (value < phMin ? StatusTone.warning : StatusTone.critical)
    : StatusTone.normal;

StatusTone _oxygenTone(double value) =>
    value < dissolvedOxygenMin ? StatusTone.warning : StatusTone.normal;

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.tone,
  });
  final String label;
  final String value;
  final String unit;
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 32,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: TextSpan(
                text: value,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                children: [
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (tone == null)
          const Text('—')
        else
          StatusPill(
            label: tone == StatusTone.normal
                ? 'Normal'
                : tone == StatusTone.warning
                ? 'Low'
                : 'High',
            tone: tone!,
          ),
      ],
    ),
  );
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});
  final _ReadingRange selected;
  final ValueChanged<_ReadingRange> onSelected;

  @override
  Widget build(BuildContext context) => SegmentedButton<_ReadingRange>(
    segments: const [
      ButtonSegment(value: _ReadingRange.today, label: Text('Today')),
      ButtonSegment(value: _ReadingRange.days7, label: Text('7 days')),
      ButtonSegment(value: _ReadingRange.days30, label: Text('30 days')),
      ButtonSegment(value: _ReadingRange.all, label: Text('All')),
    ],
    selected: {selected},
    onSelectionChanged: (values) => onSelected(values.first),
    showSelectedIcon: false,
    style: const ButtonStyle(
      visualDensity: VisualDensity(horizontal: -2, vertical: -2),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
    ),
  );
}

class _ReadingTable extends StatelessWidget {
  const _ReadingTable({required this.readings, required this.today});
  final List<Reading> readings;
  final bool today;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant.withValues(alpha: .4)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: const TableBorder(
          horizontalInside: BorderSide(color: outlineVariant, width: .6),
        ),
        children: [
          const TableRow(
            children: [
              _TableCell('Time', header: true),
              _TableCell('Temp °C', header: true, numeric: true),
              _TableCell('pH', header: true, numeric: true),
              _TableCell('DO mg/L', header: true, numeric: true),
            ],
          ),
          ...readings.map(
            (reading) => TableRow(
              children: [
                _TableCell(_compactTimestamp(reading.timestamp, today: today)),
                _TableCell(
                  reading.temperature.toStringAsFixed(1),
                  numeric: true,
                  invalid:
                      reading.temperature < temperatureMin ||
                      reading.temperature > temperatureMax,
                ),
                _TableCell(
                  reading.ph.toStringAsFixed(2),
                  numeric: true,
                  invalid: reading.ph < phMin || reading.ph > phMax,
                ),
                _TableCell(
                  reading.dissolvedOxygen.toStringAsFixed(2),
                  numeric: true,
                  invalid: reading.dissolvedOxygen < dissolvedOxygenMin,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  static String _compactTimestamp(DateTime timestamp, {required bool today}) {
    final local = timestamp.toLocal();
    if (today) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(
    this.text, {
    this.header = false,
    this.numeric = false,
    this.invalid = false,
  });
  final String text;
  final bool header;
  final bool numeric;
  final bool invalid;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: header ? 44 : 52,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: numeric ? TextAlign.right : TextAlign.left,
          style:
              (header
                      ? Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontSize: 11)
                      : Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                    color: invalid ? StatusTone.critical.color : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
        ),
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });
  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(onPressed: onPrevious, child: const Text('Previous')),
        Text(
          'Page $page of $pageCount',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        OutlinedButton(onPressed: onNext, child: const Text('Next')),
      ],
    ),
  );
}
