import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/services/api_service.dart';
import 'package:client/state/device_state.dart';

const _channelId = 'pond_alerts';

/*
 * FCM data contract:
 * type: alert | risk_high | device_offline | test
 * device_id: the backend device identifier
 * alert_id: present for alert notifications
 */
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  NotificationService({
    ApiService? api,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _api = api ?? apiService,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final ApiService _api;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  DeviceState? _deviceState;
  Future<void> Function(String type, String deviceId)? onNotificationTap;
  VoidCallback? onSelectedDeviceMessage;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Map<String, dynamic>? _pendingTap;
  bool _initialized = false;

  Future<void> initialize(DeviceState deviceState) async {
    if (_initialized || defaultTargetPlatform != TargetPlatform.android) return;
    _initialized = true;
    _deviceState = deviceState;
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_tilapulse'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _handleData(jsonDecode(payload));
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Pond alerts',
            description: 'TilaPulse pond notifications',
            importance: Importance.high,
          ),
        );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_showForeground);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleData(message.data),
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (_) => registerForConnectedDevices(),
    );
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _pendingTap = initialMessage.data;
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }

  Future<void> registerForConnectedDevices() async {
    if (!_initialized) return;
    final token = await _safeFcmToken();
    if (token == null) return;
    for (final deviceId in await _api.connectedDeviceIds()) {
      await _register(deviceId, token);
    }
  }

  Future<void> onDeviceConnected(String deviceId, BuildContext context) async {
    if (!await _permissionGranted()) {
      if (!context.mounted) return;
      final granted = await requestPermission(context);
      if (!granted) {
        await setEnabled(deviceId, false);
        return;
      }
    }
    await setEnabled(deviceId, true);
  }

  Future<bool> setEnabled(String deviceId, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey(deviceId), enabled);
    if (!enabled) {
      try {
        await _api.deletePushToken(deviceId);
      } catch (_) {}
      return true;
    }
    if (!await _permissionGranted()) return false;
    final token = await _safeFcmToken();
    if (token == null) return false;
    await _register(deviceId, token);
    return true;
  }

  Future<bool> enabledFor(String deviceId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_preferenceKey(deviceId)) ?? true;
  }

  Future<void> disconnectDevice(String deviceId) async {
    try {
      await _api.deletePushToken(deviceId);
    } catch (_) {}
  }

  Future<bool> requestPermission(BuildContext context) async {
    if (!await _permissionGranted()) {
      if (!context.mounted) return false;
      final shouldAsk = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stay informed'),
          content: const Text(
            'Get alerts about water quality, risk, and when your device goes offline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (shouldAsk != true) return false;
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }
    }
    return true;
  }

  Future<void> showPermissionSettings(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('app-settings:'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open Android Settings to enable notifications.')),
      );
    }
  }

  void attachTapHandler(
    Future<void> Function(String type, String deviceId) handler,
  ) {
    onNotificationTap = handler;
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleData(pending));
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Pond alerts',
          channelDescription: 'TilaPulse pond notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_tilapulse',
        ),
      ),
      payload: jsonEncode(message.data),
    );
    final deviceId = message.data['device_id']?.toString();
    if (deviceId != null && _deviceState?.selected?.deviceId == deviceId) {
      onSelectedDeviceMessage?.call();
    }
  }

  Future<void> _handleData(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    final deviceId = data['device_id']?.toString();
    if (type == null || deviceId == null) return;
    final device = _deviceState?.deviceForId(deviceId);
    if (device == null) {
      await onNotificationTap?.call('home', deviceId);
      return;
    }
    _deviceState?.select(device);
    await onNotificationTap?.call(type, deviceId);
  }

  Future<void> _register(String deviceId, String token) async {
    try {
      if (await enabledFor(deviceId)) await _api.registerPushToken(deviceId, token);
    } catch (_) {}
  }

  Future<String?> _safeFcmToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _permissionGranted() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  String _preferenceKey(String deviceId) => 'push_enabled_$deviceId';
}

final notificationService = NotificationService();
