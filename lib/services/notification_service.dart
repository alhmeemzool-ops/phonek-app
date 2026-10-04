import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _soundChannel = AndroidNotificationChannel(
    'phonek_alerts_v2',
    'إشعارات PhoneK',
    description: 'رسائل وعروض وإعلانات وتنبيهات PhoneK',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const _silentChannel = AndroidNotificationChannel(
    'phonek_alerts_silent_v1',
    'إشعارات PhoneK بدون صوت',
    description: 'إشعارات PhoneK بدون صوت',
    importance: Importance.max,
    playSound: false,
    enableVibration: true,
    showBadge: true,
  );

  static const _soundPreferenceKey = 'phonek_notification_sound_enabled';
  static const _accountRefreshTokenPrefix = 'phonek_account_refresh_token_';
  static const _secureStorage = FlutterSecureStorage();
  static bool _soundEnabled = true;
  static bool get soundEnabled => _soundEnabled;

  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundPreferenceKey, enabled);
  }

  static Future<void> rememberCurrentAccountSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;
    final refreshToken = session?.refreshToken;
    if (userId == null || refreshToken == null || refreshToken.isEmpty) return;
    try {
      await _secureStorage.write(
        key: '$_accountRefreshTokenPrefix$userId',
        value: refreshToken,
      );
    } catch (e) {
      debugPrint('PhoneK account session save failed: $e');
    }
  }

  static Future<bool> switchToAccount(String userId) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == userId) return true;
    try {
      final refreshToken = await _secureStorage.read(
        key: '$_accountRefreshTokenPrefix$userId',
      );
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final response =
          await Supabase.instance.client.auth.setSession(refreshToken);
      return response.user?.id == userId;
    } catch (e) {
      debugPrint('PhoneK notification account switch failed: $e');
      return false;
    }
  }

  static Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_soundPreferenceKey) ?? true;
  }

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
      await _loadSoundPreference();
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

      await android?.createNotificationChannel(_soundChannel);
      await android?.createNotificationChannel(_silentChannel);

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
        await rememberCurrentAccountSession();
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

    final channelId =
        _soundEnabled ? _soundChannel.id : _silentChannel.id;

    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: n.title ?? 'PhoneK',
      body: n.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _soundEnabled ? 'إشعارات PhoneK' : 'إشعارات PhoneK بدون صوت',
          channelDescription: _soundEnabled
              ? 'رسائل وعروض وإعلانات وتنبيهات PhoneK'
              : 'إشعارات PhoneK بدون صوت',
          importance: Importance.max,
          priority: Priority.max,
          playSound: _soundEnabled,
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
