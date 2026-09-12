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

  Future<void> _load({bool silent = false}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.email?.trim().toLowerCase() != 'alhmeemzool@gmail.com') {
      if (mounted) setState(() { _loading = false; _error = 'ليس لديك صلاحية للوصول إلى المراقبة التشغيلية.'; });
      return;
    }
    if (!silent && mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        client.from('login_events').select('id,user_id,phone_e164,method,success,created_at').order('created_at', ascending: false).limit(30),
        client.from('listings').select('id,title,brand,price,city,status,created_at,seller_id').order('created_at', ascending: false).limit(30),
        client.from('chat_threads').select('id,listing_id,buyer_id,seller_id,created_at').order('created_at', ascending: false).limit(30),
        client.from('chat_messages').select('id,thread_id,sender_id,text,type,status,created_at,offer_amount').order('created_at', ascending: false).limit(50),
      ]);
      if (!mounted) return;
      setState(() {
        _logins = _rows(results[0]);
        _newListings = _rows(results[1]);
        _threads = _rows(results[2]);
        _messages = _rows(results[3]);
        _loading = false;
        _error = null;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل المراقبة: ${e.message}'; });
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
                      const SizedBox(height: 20),
                      _section('تسجيلات الدخول الأخيرة', Icons.login, _loginList()),
                      const SizedBox(height: 20),
                      _section('الإعلانات الجديدة', Icons.phone_android, _listingList()),
                      const SizedBox(height: 20),
                      _section('المراسلات الجارية', Icons.forum_outlined, _chatList()),
                    ],
                  ),
                ),
    );
  }

  Widget _summary() => Row(children: [
        Expanded(child: _stat('الدخول', _logins.length, Icons.login)),
        const SizedBox(width: 8),
        Expanded(child: _stat('إعلانات', _newListings.length, Icons.inventory_2_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _stat('محادثات', _threads.length, Icons.forum_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _stat('رسائل', _messages.length, Icons.chat_bubble_outline)),
      ]);

  Widget _stat(String label, int value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Column(children: [Icon(icon, color: AppColors.gold), const SizedBox(height: 4), Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))])));

  Widget _section(String title, IconData icon, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: AppColors.gold), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        child,
      ]);

  Widget _loginList() {
    if (_logins.isEmpty) return _empty('لا توجد تسجيلات دخول مسجلة بعد.');
    return Column(children: _logins.map((r) => Card(child: ListTile(
      leading: const Icon(Icons.verified_user_outlined),
      title: Text(r['phone_e164']?.toString() ?? 'مستخدم'),
      subtitle: Text('${r['method'] ?? 'other'} • ${r['success'] == true ? 'ناجح' : 'فشل'}\n${_time(r['created_at'])}'),
      isThreeLine: true,
    ))).toList());
  }

  Widget _listingList() {
    if (_newListings.isEmpty) return _empty('لا توجد إعلانات جديدة.');
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
    if (_threads.isEmpty) return _empty('لا توجد محادثات جارية.');
    final messagesByThread = <String, Map<String, dynamic>>{};
    for (final message in _messages) {
      messagesByThread.putIfAbsent(message['thread_id']?.toString() ?? '', () => message);
    }
    return Column(children: _threads.map((thread) {
      final id = thread['id']?.toString() ?? '';
      final last = messagesByThread[id];
      return Card(child: ListTile(
        leading: const Icon(Icons.forum_outlined),
        title: Text('محادثة ${_short(id)}'),
        subtitle: Text(last == null
            ? 'لم تصل رسالة بعد • ${_time(thread['created_at'])}'
            : '${_short(last['text'])}\n${_time(last['created_at'])}'),
        isThreeLine: true,
        trailing: last == null ? null : Icon(last['type'] == 'offer' ? Icons.local_offer_outlined : Icons.chat_bubble_outline, color: AppColors.gold),
      ));
    }).toList());
  }

  Widget _empty(String text) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(text, style: const TextStyle(color: AppColors.textSecondary))));
}
