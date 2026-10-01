import 'dart:async';

import 'package:flutter/material.dart';
import 'package:client/core/constants.dart';
import 'package:client/models/device.dart';
import 'package:client/models/reading.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({super.key, required this.device});

  final Device device;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  Future<Reading?>? _readingFuture;
  late Device _device;
  Timer? _statusTimer;
  bool _updatingReadingState = false;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _refreshReading();
    _statusTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _refreshReading() {
    setState(() {
      _readingFuture = _loadReading();
    });
  }

  Future<void> _refreshStatus() async {
    final state = context.read<DeviceState>();
    await state.refresh();
    final updated = state.deviceForId(_device.deviceId);
    if (mounted && updated != null) setState(() => _device = updated);
  }

  Future<void> _setReadingEnabled(bool enabled) async {
    final previous = _device.readingEnabled;
    setState(() {
      _device = _device.copyWith(readingEnabled: enabled);
      _updatingReadingState = true;
    });
    try {
      final updated = await apiService.updateReadingState(
        _device.deviceId,
        enabled,
      );
      if (!mounted) return;
      setState(() => _device = updated);
      context.read<DeviceState>().replaceDevice(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _device = _device.copyWith(readingEnabled: previous));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update reading state.')),
      );
    } finally {
      if (mounted) setState(() => _updatingReadingState = false);
    }
  }

  Future<Reading?> _loadReading() async {
    try {
      return await apiService.fetchLatest(widget.device.deviceId);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _disconnect() async {
    try {
      await context.read<DeviceState>().disconnect(_device.deviceId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to disconnect this device.')),
        );
      }
    }
  }

  Future<void> _configureWifi() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WifiSetupPage()));
    if (mounted) {
      _refreshReading();
      _refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_device.name)),
    body: RefreshIndicator(
      onRefresh: () async {
        _refreshReading();
        await Future.wait([_readingFuture!, _refreshStatus()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _device.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Icon(
                _device.online ? Icons.wifi : Icons.wifi_off,
                color: _device.online ? farmGreen : StatusTone.critical.color,
                semanticLabel: _device.online ? 'Online' : 'Offline',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_device.deviceId, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          SimpleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _device.lastSeen == null
                      ? 'No readings reported yet'
                      : 'Last seen ${_formatLastSeen(_device.lastSeen!)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SimpleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _device.readingEnabled ? 'Reading enabled' : 'Paused',
                  ),
                  subtitle: Text(
                    _device.online
                        ? 'Controls whether this device samples readings.'
                        : 'Device is offline',
                  ),
                  value: _device.readingEnabled,
                  onChanged: _device.online && !_updatingReadingState
                      ? _setReadingEnabled
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Latest reading', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          FutureBuilder<Reading?>(
            future: _readingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const SimpleCard(
                  child: Text(
                    'Unable to load the latest reading. Pull to retry.',
                  ),
                );
              }
              final reading = snapshot.data;
              if (reading == null) {
                return const SimpleCard(
                  child: Text(
                    'No sensor readings yet. Configure the device WiFi, then refresh this page.',
                  ),
                );
              }
              return Column(
                children: [
                  MetricTile(
                    title: 'Temperature',
                    value: reading.temperature.toStringAsFixed(1),
                    unit: 'C',
                    normal:
                        reading.temperature >= 24 && reading.temperature <= 32,
                  ),
                  const SizedBox(height: 10),
                  MetricTile(
                    title: 'pH level',
                    value: reading.ph.toStringAsFixed(2),
                    unit: '',
                    normal: reading.ph >= 6.5 && reading.ph <= 8.5,
                  ),
                  const SizedBox(height: 10),
                  MetricTile(
                    title: 'Dissolved oxygen',
                    value: reading.dissolvedOxygen.toStringAsFixed(1),
                    unit: 'mg/L',
                    normal: reading.dissolvedOxygen >= 5,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Updated ${formatTimestamp(reading.timestamp)}',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _configureWifi,
            icon: const Icon(Icons.wifi),
            label: const Text('Configure WiFi'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('Disconnect'),
          ),
        ],
      ),
    ),
  );

  String _formatLastSeen(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : formatTimestamp(date.toLocal());
  }
}

class WifiSetupPage extends StatefulWidget {
  const WifiSetupPage({super.key});

  @override
  State<WifiSetupPage> createState() => _WifiSetupPageState();
}

class _WifiSetupPageState extends State<WifiSetupPage> {
  int _step = 0;
  bool _webViewFailed = false;
  Timer? _loadTimeout;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _webViewFailed = false);
            _startLoadTimeout();
          },
          onPageFinished: (_) => _loadTimeout?.cancel(),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) _showWebViewError();
          },
        ),
      )
      ..loadRequest(Uri.parse('http://192.168.4.1'));
  }

  void _startLoadTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 12), _showWebViewError);
  }

  void _showWebViewError() {
    if (mounted) setState(() => _webViewFailed = true);
  }

  void _retry() {
    setState(() => _webViewFailed = false);
    _controller.reload();
    _startLoadTimeout();
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configure WiFi')),
    body: Stepper(
      currentStep: _step,
      onStepCancel: _step == 0
          ? () => Navigator.of(context).pop()
          : () => setState(() => _step--),
      onStepContinue: () {
        if (_step < 2) {
          setState(() => _step++);
        } else {
          Navigator.of(context).pop();
        }
      },
      controlsBuilder: (context, details) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            FilledButton(
              onPressed: details.onStepContinue,
              child: Text(
                _step == 0
                    ? "I've connected"
                    : _step == 2
                    ? 'Done'
                    : 'Continue',
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: details.onStepCancel,
              child: Text(_step == 0 ? 'Close' : 'Back'),
            ),
          ],
        ),
      ),
      steps: [
        Step(
          title: const Text('Join the device network'),
          isActive: _step >= 0,
          content: const Text(
            'Make sure the physical device is powered on. In your phone WiFi settings, connect to TilaPulse-Setup. The network may be open or password-protected. This app cannot join it silently because iOS and Android restrict programmatic WiFi changes without special entitlements.',
          ),
        ),
        Step(
          title: const Text('Enter WiFi details'),
          isActive: _step >= 1,
          content: SizedBox(
            height: 460,
            child: _webViewFailed
                ? _WebViewError(onRetry: _retry)
                : Column(
                    children: [
                      const Text(
                        'Complete the WiFiManager form below. If it does not load, confirm you are connected to TilaPulse-Setup and turn mobile data off.',
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: WebViewWidget(controller: _controller)),
                    ],
                  ),
          ),
        ),
        Step(
          title: const Text('Reconnect your phone'),
          isActive: _step >= 2,
          content: const Text(
            'After you submit the form, the device will reboot and connect to your normal WiFi. Reconnect your phone to your normal WiFi, then tap Done to return to this device and refresh its latest reading.',
          ),
        ),
      ],
    ),
  );
}

class _WebViewError extends StatelessWidget {
  const _WebViewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off, size: 42, color: brandTeal),
        const SizedBox(height: 12),
        const Text(
          'The device setup page could not be loaded. Confirm you are connected to TilaPulse-Setup and mobile data is off.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}
