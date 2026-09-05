import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import 'admin_shop_verifications_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Timer? _refreshTimer;
  RealtimeChannel? _analyticsChannel;
  bool _loading = true;
  String? _error;
  int _events = 0;
  int _users = 0;
  int _sessions = 0;
  int _screenViews = 0;
  int _actions = 0;
  DateTime? _lastEvent;
  List<Map<String, dynamic>> _recentEvents = [];

  bool _isAdmin() => Supabase.instance.client.auth.currentUser?.appMetadata['role']
          ?.toString()
          .toLowerCase() ==
      'admin';

  @override
  void initState() {
    super.initState();
    if (_isAdmin()) {
      unawaited(_loadAnalytics());
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        unawaited(_loadAnalytics());
      });
      _analyticsChannel = Supabase.instance.client
          .channel('phonek-admin-analytics')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'analytics_events',
            callback: (_) => unawaited(_loadAnalytics()),
          )
          .subscribe();
    }
  }

  Future<void> _loadAnalytics() async {
    if (!_isAdmin()) return;
    try {
      final rows = await Supabase.instance.client
          .from('analytics_events')
          .select('id,event_name,screen_name,user_id,session_id,created_at')
          .order('created_at', ascending: false)
          .limit(1000);

      final events = (rows as List).whereType<Map<String, dynamic>>().toList();
      final userIds = events
          .map((e) => e['user_id'])
          .whereType<String>()
          .toSet();
      final sessionIds = events
          .map((e) => e['session_id'])
          .whereType<String>()
          .toSet();
      final views = events.where((e) => e['event_name'] == 'screen_view').length;
      final actions = events.where((e) {
        final name = e['event_name']?.toString() ?? '';
        return !name.startsWith('app_') &&
            name != 'heartbeat' &&
            name != 'screen_view';
      }).length;
      DateTime? latest;
      if (events.isNotEmpty) {
        latest = DateTime.tryParse(events.first['created_at']?.toString() ?? '');
      }

      if (!mounted) return;
      setState(() {
        _events = events.length;
        _users = userIds.length;
        _sessions = sessionIds.length;
        _screenViews = views;
        _actions = actions;
        _lastEvent = latest;
        _recentEvents = events.take(30).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر قراءة الإحصائيات المباشرة';
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _analyticsChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin()) {
      return const Scaffold(body: Center(child: Text('غير مصرح لك بالدخول')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الأدمن'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('مباشر', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => unawaited(_loadAnalytics()),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(child: _statCard('الأحداث', '$_events', Icons.insights)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('المستخدمون', '$_users', Icons.people_outline)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _statCard('الجلسات', '$_sessions', Icons.devices)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('مشاهدات الصفحات', '$_screenViews', Icons.remove_red_eye_outlined)),
              ],
            ),
            const SizedBox(height: 8),
            _statCard('حركات المستخدمين', '$_actions', Icons.touch_app_outlined),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time, color: AppColors.gold),
                title: const Text('آخر حركة'),
                subtitle: Text(_lastEvent == null
                    ? 'لا توجد أحداث مسجلة بعد'
                    : _lastEvent!.toLocal().toString()),
              ),
            ),
            const SizedBox(height: 20),
            const Text('آخر الحركات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_recentEvents.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('لم تُسجل أي حركة حتى الآن.'),
                ),
              )
            else
              ..._recentEvents.map(_eventTile),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: AppColors.gold),
                title: const Text('طلبات توثيق المحلات'),
                subtitle: const Text('مراجعة صورة الهوية وفيديو الوجه والموقع قبل التفعيل.'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminShopVerificationsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('التتبع يعمل تلقائياً'),
                subtitle: Text('يتم إرسال الأحداث إلى Supabase على دفعات، مع تحديث اللوحة تلقائياً كل 5 ثوانٍ.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventTile(Map<String, dynamic> event) {
    final name = event['event_name']?.toString() ?? 'event';
    final screen = event['screen_name']?.toString();
    final created = DateTime.tryParse(event['created_at']?.toString() ?? '');
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.bolt_outlined, size: 20),
        title: Text(name),
        subtitle: Text([
          if (screen != null && screen.isNotEmpty) screen,
          if (created != null) created.toLocal().toString(),
        ].join(' • ')),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: AppColors.gold),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      );
}
