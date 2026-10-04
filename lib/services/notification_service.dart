import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  // New channel id intentionally replaces the old one so Android can apply
  // the sound configuration on devices that already created the old channel.
  static const _channel = AndroidNotificationChannel(
    'phonek_alerts_v2',
    'إشعارات PhoneK',
    description: 'رسائل وعروض وإعلانات وتنبيهات PhoneK',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static Future<void> Function(Map<String, dynamic> data)? _onTap;
  static Map<String, dynamic>? _pendingTap;

  static void setOnNotificationTap(
    Future<void> Function(Map<String, dynamic> data) handler,
  ) {
    _onTap = handler;
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) {
      unawaited(handler(pending));
    }
  }

  static void _dispatchTap(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    final handler = _onTap;
    if (handler == null) {
      _pendingTap = normalized;
    } else {
      unawaited(handler(normalized));
    }
  }

  static Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _local.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final raw = response.payload;
          if (raw == null || raw.isEmpty) return;
          try {
            _dispatchTap(jsonDecode(raw) as Map<String, dynamic>);
          } catch (e) {
            debugPrint('PhoneK notification payload parse failed: $e');
          }
        },
      );

      final android =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await android?.createNotificationChannel(_channel);
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      FirebaseMessaging.onMessage.listen(_showForeground);

      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _dispatchTap(message.data),
      );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _dispatchTap(initialMessage.data);
      }

      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
      _messaging.onTokenRefresh.listen(_saveToken);

      Supabase.instance.client.auth.onAuthStateChange.listen((_) async {
        final token = await _messaging.getToken();
        if (token != null) await _saveToken(token);
      });
    } catch (e) {
      debugPrint('PhoneK notification init failed: $e');
    }
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    final payload = jsonEncode({
      ...message.data,
      if (message.messageId != null) 'message_id': message.messageId,
    });

    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: n.title ?? 'PhoneK',
      body: n.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'phonek_alerts_v2',
          'إشعارات PhoneK',
          channelDescription: 'رسائل وعروض وإعلانات وتنبيهات PhoneK',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || token.isEmpty) return;

    try {
      await Supabase.instance.client.from('push_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'unknown',
          'enabled': true,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
    } catch (e) {
      debugPrint('PhoneK token save failed: $e');
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await Supabase.instance.client
        .from('push_tokens')
        .update({
          'enabled': enabled,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id)
        .eq('token', token);
  }
}