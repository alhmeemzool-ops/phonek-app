import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final totalListings = MockData.listings.length;
    final totalViews = MockData.listings.fold<int>(0, (sum, p) => sum + p.viewCount);
    final featured = MockData.listings.where((p) => p.isFeatured).length;

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الأدمن')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _statCard('الإعلانات', '$totalListings', Icons.list_alt)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('المشاهدات', '$totalViews', Icons.remove_red_eye)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('المميزة', '$featured', Icons.star)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('إعلانات بانتظار المراجعة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('لا توجد إعلانات معلّقة حالياً', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('البلاغات', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.flag_outlined, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('لا توجد بلاغات جديدة', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ملاحظة: هذه اللوحة تعرض حالياً بيانات محلية تجريبية. بعد ربط Firestore ستُقرأ هذه '
            'الإحصائيات والبلاغات مباشرة من قاعدة البيانات الحقيقية.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
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
