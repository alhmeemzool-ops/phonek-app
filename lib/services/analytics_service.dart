import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central live analytics collector for PhoneK.
///
/// Events are queued locally and flushed in batches so analytics never blocks
/// the UI. Sensitive payloads such as passwords, tokens and message text are
/// never recorded.
class AnalyticsService with WidgetsBindingObserver {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final List<Map<String, dynamic>> _queue = [];
  final Random _random = Random();
  final List<RealtimeChannel> _channels = [];
  Timer? _flushTimer;
  Timer? _heartbeatTimer;
  String? _sessionId;
  String? _currentScreen;
  bool _initialized = false;
  bool _flushInProgress = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _sessionId = _newUuid();

    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(flush());
    });
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(track('heartbeat', screenName: _currentScreen));
    });

    _subscribeToLiveSources();
    await track('app_open');
    await flush();
  }

  String _newUuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  bool _isUuid(String? value) {
    if (value == null) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(value);
  }

  Future<void> track(
    String eventName, {
    String? screenName,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized || _sessionId == null) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    _queue.add({
      'user_id': _isUuid(userId) ? userId : null,
      'session_id': _sessionId,
      'event_name': eventName,
      'screen_name': screenName ?? _currentScreen,
      'entity_type': entityType,
      'entity_id': _isUuid(entityId) ? entityId : null,
      'metadata': metadata ?? const <String, dynamic>{},
    });

    if (_queue.length >= 10) unawaited(flush());
  }

  Future<void> screenView(String screenName) async {
    _currentScreen = screenName;
    await track('screen_view', screenName: screenName);
  }

  void _subscribeToLiveSources() {
    const sources = <String, String>{
      'listings': 'listing',
      'favorites': 'favorite',
      'chat_threads': 'chat_thread',
      'chat_messages': 'chat_message',
      'profiles': 'profile',
      'shop_verification_requests': 'shop_verification_request',
      'shop_verification_audit': 'shop_verification_audit',
    };

    for (final entry in sources.entries) {
      final channel = Supabase.instance.client.channel('phonek-analytics-${entry.key}');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: entry.key,
            callback: (payload) {
              final record = payload.newRecord.isNotEmpty
                  ? payload.newRecord
                  : payload.oldRecord;
              final entityId = record['id']?.toString();
              unawaited(track(
                'db_${payload.eventType.name.toLowerCase()}',
                entityType: entry.value,
                entityId: entityId,
                metadata: {
                  'source': 'realtime',
                  'operation': payload.eventType.name,
                },
              ));
            },
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  Future<void> flush() async {
    if (_flushInProgress || _queue.isEmpty) return;
    _flushInProgress = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.removeRange(0, batch.length);

    try {
      await Supabase.instance.client.from('analytics_events').insert(batch);
    } catch (_) {
      _queue.insertAll(0, batch.take(100).toList());
    } finally {
      _flushInProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(track('app_resumed', screenName: _currentScreen));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        unawaited(track('app_inactive', screenName: _currentScreen));
        unawaited(flush());
        break;
      case AppLifecycleState.paused:
        unawaited(track('app_paused', screenName: _currentScreen));
        unawaited(flush());
        break;
      case AppLifecycleState.detached:
        unawaited(track('app_detached', screenName: _currentScreen));
        unawaited(flush());
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    _heartbeatTimer?.cancel();
    for (final channel in _channels) {
      Supabase.instance.client.removeChannel(channel);
    }
    _channels.clear();
  }
}

class AnalyticsNavigatorObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty || name == '/') return;
    unawaited(AnalyticsService.instance.screenView(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _track(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _track(previousRoute);
}
