import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = const [];
  bool _loading = true;
  bool _promotionsMuted = false;
  String? _error;
  bool _notificationsTableMissing = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final rows = await _client
          .from('notifications')
          .select('id, title, body, type, is_read, created_at, action_route')
          .or('user_id.eq.${user.id},user_id.is.null')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _notifications = (rows as List)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        _loading = false;
        _error = null;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.message.toLowerCase();
      final tableMissing =
          error.code == 'PGRST205' ||
          message.contains("could not find the table") ||
          message.contains('schema cache') ||
          message.contains('notifications');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notificationsTableMissing = tableMissing;
        _error = tableMissing
            ? 'خدمة الإشعارات غير مفعلة على قاعدة البيانات بعد.'
            : 'تعذر تحميل الإشعارات الآن.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الإشعارات الآن';
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _client.from('notifications').update({'is_read': true}).eq('id', id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => item['id'] == id ? {...item, 'is_read': true} : item)
            .toList(growable: false);
      });
    } catch (_) {
      // The item remains visible if the optional notification migration is absent.
    }
  }

  Future<void> _markAllAsRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => {...item, 'is_read': true})
            .toList(growable: false);
      });
    } catch (_) {
      // Keep the current view usable when the backend is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((item) => item['is_read'] != true).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(unread == 0 ? 'الإشعارات' : 'الإشعارات ($unread)'),
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'تحديد الكل كمقروء',
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile.adaptive(
                value: _promotionsMuted,
                onChanged: (value) => setState(() => _promotionsMuted = value),
                title: const Text('كتم الإشعارات الترويجية'),
                subtitle: const Text('ستظل إشعارات الحساب والطلبات ظاهرة.'),
                secondary: const Icon(Icons.volume_off_outlined, color: AppColors.gold),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _MessageState(
                message: _error!,
                details: _notificationsTableMissing
                    ? 'سيتم عرض الإشعارات بعد تطبيق ترحيل قاعدة البيانات من مجلد supabase/migrations.'
                    : null,
                onRetry: _loadNotifications,
              )
            else if (_notifications.isEmpty)
              const _MessageState(message: 'لا توجد إشعارات حاليًا')
            else
              ..._notifications.map(_notificationTile),
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(Map<String, dynamic> item) {
    final isRead = item['is_read'] == true;
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isRead ? null : AppColors.surfaceLight,
      child: ListTile(
        onTap: () => _markAsRead(item['id'].toString()),
        leading: Icon(
          isRead ? Icons.notifications_none : Icons.notifications_active,
          color: isRead ? AppColors.textSecondary : AppColors.gold,
        ),
        title: Text(item['title']?.toString() ?? 'إشعار PhoneK', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('${item['body'] ?? ''}${createdAt == null ? '' : '\n${createdAt.toLocal()}'}'),
        ),
        trailing: isRead ? null : const CircleAvatar(radius: 4, backgroundColor: AppColors.gold),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, this.details, this.onRetry});

  final String message;
  final String? details;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Center(
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(details!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ],
        ),
      ),
    );
  }
}
