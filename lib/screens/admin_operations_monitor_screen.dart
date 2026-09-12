import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class AdminOperationsMonitorScreen extends StatefulWidget {
  const AdminOperationsMonitorScreen({super.key});

  @override
  State<AdminOperationsMonitorScreen> createState() => _AdminOperationsMonitorScreenState();
}

class _AdminOperationsMonitorScreenState extends State<AdminOperationsMonitorScreen> {
  bool _loading = true;
  String? _error;
  final List<String> _warnings = [];
  List<Map<String, dynamic>> _logins = const [];
  List<Map<String, dynamic>> _newListings = const [];
  List<Map<String, dynamic>> _threads = const [];
  List<Map<String, dynamic>> _messages = const [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _queryRows(Future<dynamic> query, String label) async {
    try {
      return _rows(await query);
    } catch (e) {
      _warnings.add('$label: $e');
      return const [];
    }
  }

  Future<void> _load({bool silent = false}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final adminResult = user == null ? false : await client.rpc('is_admin');
    if (adminResult != true) {
      if (mounted) setState(() { _loading = false; _error = 'ليس لديك صلاحية للوصول إلى المراقبة التشغيلية.'; });
      return;
    }
    if (!silent && mounted) setState(() { _loading = true; _error = null; });
    _warnings.clear();
    try {
      final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
      final logins = await _queryRows(
        client.from('login_events').select('id,user_id,phone_e164,method,success,created_at').order('created_at', ascending: false).limit(50),
        'تسجيلات الدخول',
      );
      final listings = await _queryRows(
        client.from('listings').select('id,title,brand,price,city,status,created_at,seller_id').gte('created_at', cutoff).order('created_at', ascending: false).limit(50),
        'الإعلانات',
      );
      final threads = await _queryRows(
        client.from('chat_threads').select('id,listing_id,buyer_id,seller_id,created_at').order('created_at', ascending: false).limit(50),
        'المحادثات',
      );
      final messages = await _queryRows(
        client.from('chat_messages').select('id,thread_id,sender_id,text,type,status,created_at,offer_amount').order('created_at', ascending: false).limit(200),
        'الرسائل',
      );
      if (!mounted) return;
      setState(() {
        _logins = logins;
        _newListings = listings;
        _threads = threads;
        _messages = messages;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل المراقبة: $e'; });
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) => (value as List).whereType<Map<String, dynamic>>().toList();

  String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _short(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length <= 18) return text;
    return '${text.substring(0, 18)}…';
  }

  bool _within24h(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return false;
    final age = DateTime.now().toUtc().difference(date.toUtc());
    return age >= Duration.zero && age <= const Duration(hours: 24);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المراقبة التشغيلية'),
        actions: [IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _summary(),
                      const SizedBox(height: 8),
                      Text('تحديث تلقائي كل 20 ثانية • الإعلانات المعروضة خلال آخر 24 ساعة', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      if (_warnings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Card(child: Padding(padding: const EdgeInsets.all(12), child: Text('بعض مصادر المراقبة غير متاحة حالياً؛ تم عرض المصادر التي تعمل بدلاً من جعل اللوحة فارغة.\n${_warnings.join('\n')}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)))),
                      ],
                      const SizedBox(height: 20),
                      _section('تسجيلات الدخول', Icons.login, _loginList()),
                      const SizedBox(height: 20),
                      _section('الإعلانات الجديدة — آخر 24 ساعة', Icons.phone_android, _listingList()),
                      const SizedBox(height: 20),
                      _section('المراسلات الجارية', Icons.forum_outlined, _chatList()),
                    ],
                  ),
                ),
    );
  }

  Widget _summary() {
    final failed = _logins.where((r) => r['success'] != true).length;
    final activeThreads = _threads.where((t) {
      final id = t['id']?.toString() ?? '';
      return _messages.any((m) => m['thread_id']?.toString() == id && _within24h(m['created_at']));
    }).length;
    return Row(children: [
      Expanded(child: _stat('الدخول', _logins.length, Icons.login)),
      const SizedBox(width: 6),
      Expanded(child: _stat('فشل', failed, Icons.warning_amber_outlined)),
      const SizedBox(width: 6),
      Expanded(child: _stat('إعلانات', _newListings.length, Icons.inventory_2_outlined)),
      const SizedBox(width: 6),
      Expanded(child: _stat('نشطة', activeThreads, Icons.forum_outlined)),
    ]);
  }

  Widget _stat(String label, int value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2), child: Column(children: [Icon(icon, color: AppColors.gold), const SizedBox(height: 4), Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))])));

  Widget _section(String title, IconData icon, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, color: AppColors.gold), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]),
    const SizedBox(height: 8),
    child,
  ]);

  Widget _loginList() {
    if (_logins.isEmpty) return _empty('لا توجد تسجيلات دخول مسجلة بعد.');
    return Column(children: _logins.map((r) {
      final success = r['success'] == true;
      return Card(child: ListTile(
        leading: Icon(success ? Icons.verified_user_outlined : Icons.error_outline, color: success ? null : Colors.redAccent),
        title: Text(r['phone_e164']?.toString() ?? 'مستخدم'),
        subtitle: Text('${r['method'] ?? 'other'} • ${success ? 'ناجح' : 'فشل'}\n${_time(r['created_at'])}'),
        isThreeLine: true,
        trailing: success ? null : const Text('تنبيه', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
      ));
    }).toList());
  }

  Widget _listingList() {
    if (_newListings.isEmpty) return _empty('لا توجد إعلانات خلال آخر 24 ساعة.');
    return Column(children: _newListings.map((r) {
      final status = r['status']?.toString() ?? '—';
      return Card(child: ListTile(
        leading: const Icon(Icons.phone_android),
        title: Text(r['title']?.toString() ?? 'إعلان بدون عنوان'),
        subtitle: Text('${r['brand'] ?? ''} • ${r['city'] ?? ''}\n${_time(r['created_at'])}'),
        isThreeLine: true,
        trailing: Text(status, style: TextStyle(color: status == 'pendingReview' || status == 'pending_review' ? AppColors.gold : AppColors.textSecondary, fontSize: 11)),
      ));
    }).toList());
  }

  Widget _chatList() {
    if (_threads.isEmpty) return _empty('لا توجد محادثات.');
    final messagesByThread = <String, Map<String, dynamic>>{};
    for (final message in _messages) {
      final id = message['thread_id']?.toString() ?? '';
      if (id.isNotEmpty) messagesByThread.putIfAbsent(id, () => message);
    }
    final active = _threads.where((thread) {
      final last = messagesByThread[thread['id']?.toString() ?? ''];
      return last != null && _within24h(last['created_at']);
    }).toList();
    if (active.isEmpty) return _empty('لا توجد محادثات نشطة خلال آخر 24 ساعة.');
    return Column(children: active.map((thread) {
      final id = thread['id']?.toString() ?? '';
      final last = messagesByThread[id]!;
      return Card(child: ListTile(
        leading: const Icon(Icons.forum_outlined),
        title: Text('محادثة ${_short(id)}'),
        subtitle: Text('${_short(last['text'])}\nآخر نشاط: ${_time(last['created_at'])}'),
        isThreeLine: true,
        trailing: Icon(last['type'] == 'offer' ? Icons.local_offer_outlined : Icons.chat_bubble_outline, color: AppColors.gold),
      ));
    }).toList());
  }

  Widget _empty(String text) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(text, style: const TextStyle(color: AppColors.textSecondary))));
}
