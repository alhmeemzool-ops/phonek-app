import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import 'shop_application_screen.dart';

class ShopAccountScreen extends StatelessWidget {
  const ShopAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('حساب صاحب محل')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.storefront, size: 64, color: AppColors.gold),
          const SizedBox(height: 12),
          const Text('أنشئ صفحة محلك', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('قدّم طلب المحل بخطوات سريعة: بيانات المحل، موقع Google Maps، التحقق الحيوي، وثيقة الهوية، ثم المراجعة.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.store)), title: Text(state.shopName ?? 'حساب التاجر'), subtitle: const Text('طلب فتح محل والتحقق من الهوية والموقع')),
          const SizedBox(height: 16),
          const _FeatureTile(icon: Icons.map, title: 'موقع المحل على الخريطة', subtitle: 'تحديد الموقع الدقيق وتثبيت العلامة على المدخل.'),
          const _FeatureTile(icon: Icons.face, title: 'Face Capture + Liveness', subtitle: 'التقاط الوجه وفيديو حيوية قصير للتحقق الآمن.'),
          const _FeatureTile(icon: Icons.badge_outlined, title: 'مطابقة الهوية', subtitle: 'تجهيز وثيقة الهوية للمطابقة عبر مزود eKYC.'),
          const _FeatureTile(icon: Icons.verified_user, title: 'مراجعة واعتماد', subtitle: 'لا يتم اعتماد التوثيق قبل صدور نتيجة تحقق موثوقة.'),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopApplicationScreen())), icon: const Icon(Icons.arrow_forward), label: const Text('ابدأ التقديم للمحل'))),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: AppColors.surfaceLight, child: Icon(icon, color: AppColors.gold)), title: Text(title), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)));
}
