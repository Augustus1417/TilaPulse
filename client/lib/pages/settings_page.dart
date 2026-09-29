import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:client/models/device.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _keyController = TextEditingController();
  Future<List<Device>>? _adminDevices;
  bool _loading = false;
  String? _newDeviceKey;
  final Set<String> _revealed = {};

  @override
  void initState() {
    super.initState();
    _loadAdminDevices();
  }

  void _loadAdminDevices() {
    _adminDevices = apiService.fetchAdminDevices().catchError((error) {
      throw error is ApiException
          ? error
          : ApiException(0, 'Unable to load admin devices: $error');
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final device = await context.read<DeviceState>().register(
        deviceId: _idController.text.trim(),
        name: _nameController.text.trim(),
        deviceKey: _keyController.text.trim(),
      );
      setState(() {
        _newDeviceKey = device?.deviceKey;
        _nameController.clear();
        _idController.clear();
        _keyController.clear();
        _loadAdminDevices();
      });
    } catch (error) {
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'Unable to register device: $error';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const PageHeader(title: 'Settings', showSwitcher: false),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register a device',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SimpleCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Pond name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a name.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _idController,
                      decoration: const InputDecoration(labelText: 'Device ID'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a device ID.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'Device key (optional)',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _register,
                        icon: const Icon(Icons.add_link),
                        label: Text(
                          _loading ? 'Registering...' : 'Register device',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_newDeviceKey != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SimpleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device key',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Flash this key into the matching ESP32 firmware.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _newDeviceKey!,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: _newDeviceKey!),
                            ),
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copy device key',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Registered devices',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Device>>(
              future: _adminDevices,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Text(
                    snapshot.error is ApiException
                        ? (snapshot.error! as ApiException).message
                        : 'Admin device list unavailable: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.isEmpty)
                  return Text(
                    'No devices registered.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                return Column(
                  children: snapshot.data!.map(_deviceCard).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ],
  );

  Widget _deviceCard(Device device) {
    final visible = _revealed.contains(device.deviceId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SimpleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              device.deviceId,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Last seen: ${device.lastSeen ?? 'Never'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    visible
                        ? device.deviceKey ?? 'No key'
                        : 'Device key hidden',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => visible
                        ? _revealed.remove(device.deviceId)
                        : _revealed.add(device.deviceId),
                  ),
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                  tooltip: visible ? 'Hide key' : 'Reveal key',
                ),
                if (visible && device.deviceKey != null)
                  IconButton(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: device.deviceKey!),
                    ),
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy device key',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
