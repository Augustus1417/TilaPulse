import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class ConnectDevicePage extends StatefulWidget {
  const ConnectDevicePage({super.key});

  @override
  State<ConnectDevicePage> createState() => _ConnectDevicePageState();
}

class _ConnectDevicePageState extends State<ConnectDevicePage> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _deviceKeyController = TextEditingController();
  bool _loading = false;
  bool _obscureKey = true;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _deviceKeyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<DeviceState>().connect(
        deviceId: _deviceIdController.text.trim(),
        deviceKey: _deviceKeyController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException && error.statusCode == 401
          ? 'Invalid device ID or key.'
          : 'Unable to connect to this device. Check the connection and try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<_ScannedDevice>(
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (!mounted || result == null) return;
    _deviceIdController.text = result.deviceId;
    _deviceKeyController.text = result.deviceKey;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connect a device')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.link, size: 44, color: brandTeal),
        const SizedBox(height: 16),
        Text(
          'Connect to your pond device',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the device ID and key provided with the registered device.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SimpleCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _deviceIdController,
                  decoration: const InputDecoration(
                    labelText: 'Device ID',
                    prefixIcon: Icon(Icons.devices_other),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a device ID.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _deviceKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: 'Device key',
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off,
                      ),
                      tooltip: _obscureKey ? 'Show key' : 'Hide key',
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a device key.'
                      : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _connect,
                    icon: const Icon(Icons.link),
                    label: Text(_loading ? 'Connecting...' : 'Connect'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _scanQr,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR code'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScannedDevice {
  const _ScannedDevice(this.deviceId, this.deviceKey);
  final String deviceId;
  final String deviceKey;
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _handled = false;

  void _handleScan(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      final scanned = _parse(raw);
      if (scanned != null) {
        _handled = true;
        Navigator.of(context).pop(scanned);
        return;
      }
    }
  }

  _ScannedDevice? _parse(String raw) {
    try {
      final payload = jsonDecode(raw);
      if (payload is Map<String, dynamic>) {
        final deviceId = payload['device_id']?.toString().trim();
        final deviceKey = payload['device_key']?.toString().trim();
        if (deviceId?.isNotEmpty == true && deviceKey?.isNotEmpty == true) {
          return _ScannedDevice(deviceId!, deviceKey!);
        }
      }
    } catch (_) {
      // A QR code may contain the key only; the device ID can be entered next.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan device QR code')),
    body: MobileScanner(onDetect: _handleScan),
  );
}
