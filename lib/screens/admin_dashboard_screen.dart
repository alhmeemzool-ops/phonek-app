import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  bool _authorized = false;
  String? _error;
  int _totalListings = 0;
  int _totalViews = 0;
  int _featured = 0;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw const AuthException('يجب تسجيل الدخول أولاً');
      }

      final profile = await client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();

      if (profile?['is_admin'] != true) {
        if (mounted) {
          setState(() {
            _authorized = false;
            _loading = false;
          });
        }
        return;
      }

      final rows = await client
          .from('listings')
          .select('status, view_count, is_featured');

      var views = 0;
      var featured = 0;
      var pending = 0;
      for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
        views += (row['view_count'] as num?)?.toInt() ?? 0;
        if (row['is_featured'] == true) featured++;
        final status = row['status'] as String?;
        if (status == 'pendingReview' || status == 'pending_review') pending++;
      }

      if (!mounted) return;
      setState(() {
        _authorized = true;
        _totalListings = rows.length;
        _totalViews = views;
        _featured = featured;
        _pending = pending;
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل لوحة الإدارة: ${error.message}';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الأدمن')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_authorized
              ? _message(Icons.lock_outline, 'ليس لديك صلاحية للوصول إلى لوحة الإدارة.')
              : _error != null
                  ? _errorView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Expanded(child: _statCard('الإعلانات', '$_totalListings', Icons.list_alt)),
                              const SizedBox(width: 10),
                              Expanded(child: _statCard('المشاهدات', '$_totalViews', Icons.remove_red_eye)),
                              const SizedBox(width: 10),
                              Expanded(child: _statCard('المميزة', '$_featured', Icons.star)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _statusCard(
                            Icons.pending_actions,
                            'إعلانات بانتظار المراجعة',
                            '$_pending إعلان يحتاج إلى مراجعة.',
                          ),
                          const SizedBox(height: 12),
                          _statusCard(
                            Icons.flag_outlined,
                            'البلاغات',
                            'قسم البلاغات يحتاج جدول البلاغات قبل عرض بيانات حقيقية.',
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'الإحصائيات أعلاه تُقرأ الآن من Supabase. صلاحية الأدمن يجب أن تكون مفروضة أيضًا بسياسات RLS في قاعدة البيانات.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 52, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(IconData icon, String title, String subtitle) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.gold),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
}
