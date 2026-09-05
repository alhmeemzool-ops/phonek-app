import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central live analytics collector for PhoneK.
///
/// Events are queued locally and flushed in batches so analytics never blocks
/// the UI. No passwords, tokens, message text, or other sensitive payloads are
/// recorded here.
class AnalyticsService with WidgetsBindingObserver {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final List<Map<String, dynamic>> _queue = [];
  final Random _random = Random();
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
    _sessionId = _newId();

    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(flush());
    });
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(track('heartbeat', screenName: _currentScreen));
    });

    await track('app_open');
    await flush();
  }

  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$now-${_random.nextInt(1 << 32)}';
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
      'user_id': userId,
      'session_id': _sessionId,
      'event_name': eventName,
      'screen_name': screenName ?? _currentScreen,
      'entity_type': entityType,
      'entity_id': entityId,
      'metadata': metadata ?? const <String, dynamic>{},
    });

    if (_queue.length >= 10) unawaited(flush());
  }

  Future<void> screenView(String screenName) async {
    _currentScreen = screenName;
    await track('screen_view', screenName: screenName);
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
