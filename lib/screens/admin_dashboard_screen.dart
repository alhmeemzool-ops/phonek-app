import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import 'admin_shop_verifications_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  bool _isAdmin() => Supabase.instance.client.auth.currentUser?.appMetadata['role']?.toString().toLowerCase() == 'admin';

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin()) {
      return const Scaffold(body: Center(child: Text('غير مصرح لك بالدخول')));
    }
    final totalListings = MockData.listings.length;
    final totalViews = MockData.listings.fold<int>(0, (sum, p) => sum + p.viewCount);
    final featured = MockData.listings.where((p) => p.isFeatured).length;

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الأدمن')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: _statCard('الإعلانات', '$totalListings', Icons.list_alt)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('المشاهدات', '$totalViews', Icons.remove_red_eye)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('المميزة', '$featured', Icons.star)),
          ]),
          const SizedBox(height: 20),
          Card(child: ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: AppColors.gold),
            title: const Text('طلبات توثيق المحلات'),
            subtitle: const Text('مراجعة صورة الهوية وفيديو الوجه والموقع قبل التفعيل.'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminShopVerificationsScreen())),
          )),
          const SizedBox(height: 20),
          const Text('إعلانات بانتظار المراجعة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.check_circle_outline, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('لا توجد إعلانات معلّقة حالياً', style: TextStyle(color: AppColors.textSecondary)),
          ]))),
          const SizedBox(height: 20),
          const Text('البلاغات', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.flag_outlined, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('لا توجد بلاغات جديدة', style: TextStyle(color: AppColors.textSecondary)),
          ]))),
          const SizedBox(height: 24),
          const Text('تنبيه: إحصائيات هذه الصفحة ما زالت تجريبية وليست بيانات الإنتاج.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [Icon(icon, color: AppColors.gold), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))])));
}
