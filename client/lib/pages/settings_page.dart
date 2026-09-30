import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/pages/connect_device_page.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _openConnect(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ConnectDevicePage()));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceState>();
    return ListView(
      children: [
        const PageHeader(title: 'Settings', showSwitcher: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                onPressed: () => _openConnect(context),
                icon: const Icon(Icons.add_link),
                label: const Text('Connect a device'),
              ),
              const SizedBox(height: 24),
              Text(
                'Connected devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (state.devices.isEmpty)
                SimpleCard(
                  child: Text(
                    'No devices are connected on this app yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ...state.devices.map(
                (device) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SimpleCard(
                    child: Row(
                      children: [
                        const Icon(Icons.devices_other, color: brandTeal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                device.deviceId,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _disconnect(context, device.deviceId),
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.sessionMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.sessionMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _disconnect(BuildContext context, String deviceId) async {
    try {
      await context.read<DeviceState>().disconnect(deviceId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to disconnect this device.')),
        );
      }
    }
  }
}
