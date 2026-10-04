import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async { await Firebase.initializeApp(); }

class NotificationService {
  NotificationService._();
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel('phonek_high','إشعارات PhoneK',description:'رسائل وعروض وتنبيهات PhoneK',importance:Importance.high);

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
      await _local.initialize(settings);
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      await _messaging.requestPermission(alert:true,badge:true,sound:true,provisional:false);
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m)=>debugPrint('PhoneK notification opened: ${m.data}'));
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
      _messaging.onTokenRefresh.listen(_saveToken);
      Supabase.instance.client.auth.onAuthStateChange.listen((_) async {
        final token = await _messaging.getToken();
        if (token != null) await _saveToken(token);
      });
    } catch(e) { debugPrint('PhoneK notification init failed: $e'); }
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final n=message.notification;
    if(n==null)return;
    await _local.show(n.hashCode,n.title??'PhoneK',n.body??'',const NotificationDetails(
      android: AndroidNotificationDetails('phonek_high','إشعارات PhoneK',channelDescription:'رسائل وعروض وتنبيهات PhoneK',importance:Importance.high,priority:Priority.high,icon:'@mipmap/ic_launcher')));
  }

  static Future<void> _saveToken(String token) async {
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null||token.isEmpty)return;
    try { await Supabase.instance.client.from('push_tokens').upsert({
      'user_id':user.id,'token':token,'platform':Platform.isAndroid?'android':'unknown','enabled':true,
      'last_seen_at':DateTime.now().toUtc().toIso8601String(),
    },onConflict:'user_id,token'); } catch(e){debugPrint('PhoneK token save failed: $e');}
  }

  static Future<void> setEnabled(bool enabled) async {
    final user=Supabase.instance.client.auth.currentUser;
    if(user==null)return;
    final token=await _messaging.getToken();
    if(token==null)return;
    await Supabase.instance.client.from('push_tokens').update({'enabled':enabled,'last_seen_at':DateTime.now().toUtc().toIso8601String()}).eq('user_id',user.id).eq('token',token);
  }
}