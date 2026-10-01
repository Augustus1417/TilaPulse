import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/pages/connect_device_page.dart';
import 'package:client/pages/device_detail_page.dart';
import 'package:client/state/device_state.dart';
import 'package:client/widgets/design_system.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      context.read<DeviceState>().refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeviceDetailPage(device: device),
                      ),
                    ),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  device.deviceId,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            device.online ? Icons.wifi : Icons.wifi_off,
                            size: 20,
                            color: device.online
                                ? farmGreen
                                : StatusTone.critical.color,
                            semanticLabel: device.online ? 'Online' : 'Offline',
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
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
}
