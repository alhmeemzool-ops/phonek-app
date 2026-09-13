import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../features/merchant_badges/merchant_badges_screen.dart';
import '../theme/app_theme.dart';
import 'my_listings_screen.dart';
import 'shop_application_screen.dart';

class ShopAccountScreen extends StatelessWidget {
  const ShopAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final myListings = state.currentUser == null ? const [] : state.listings.where((listing) => listing.seller.id == state.currentUser!.id).toList();
    if (state.isShopOwner) {
      return Scaffold(
        appBar: AppBar(title: Text('لوحة متجر ${state.shopName ?? ''}')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const CircleAvatar(radius: 28, backgroundColor: AppColors.surfaceLight, child: Icon(Icons.storefront, color: AppColors.gold)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(state.shopName ?? 'متجري', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const Text('متجر مفعّل', style: TextStyle(color: AppColors.success))])), const Icon(Icons.verified, color: AppColors.gold)]),
            const SizedBox(height: 18),
            Row(children: [Expanded(child: _metric('كتلوجي', '${myListings.length}')), Expanded(child: _metric('مشاهدات', '${myListings.fold<int>(0, (sum, item) => sum + item.viewCount.toInt())}')), Expanded(child: _metric('إعلانات نشطة', '${myListings.where((item) => item.status.name == 'active').length}'))]),
          ]))),
          const SizedBox(height: 12),
          const Text('أدوات المتجر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _tool(context, Icons.inventory_2_outlined, 'كتلوجي وإعلاناتي', 'تعديل أو حذف الإعلان من نفس التدفق الحالي', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen()))),
          _tool(context, Icons.workspace_premium_outlined, 'شارات المتجر', 'المستوى والتقدم وشروط كل شارة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantBadgesScreen()))),
          _tool(context, Icons.favorite_border, 'الإعجابات والتقييمات', 'تابع تفاعل العملاء والتقييمات المنشورة', () => _showRatings(context, myListings)),
          _tool(context, Icons.chat_bubble_outline, 'محادثات العملاء', 'الرد على العملاء من تبويب المحادثات', () => Navigator.pop(context)),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('حساب التاجر')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.storefront, size: 64, color: AppColors.gold),
        const SizedBox(height: 12),
        const Text('أنشئ صفحة متجرك', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('قدّم طلب المتجر بخطوات سريعة: بيانات المتجر، موقع Google Maps، التحقق الحيوي، وثيقة الهوية، ثم المراجعة.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.store)), title: Text(state.shopName ?? 'حساب التاجر'), subtitle: const Text('طلب فتح متجر والتحقق من الهوية والموقع')),
        const SizedBox(height: 16),
        const _FeatureTile(icon: Icons.map, title: 'موقع المتجر على الخريطة', subtitle: 'تحديد الموقع الدقيق وتثبيت العلامة على المدخل.'),
        const _FeatureTile(icon: Icons.face, title: 'Face Capture + Liveness', subtitle: 'التقاط الوجه وفيديو حيوية قصير للتحقق الآمن.'),
        const _FeatureTile(icon: Icons.badge_outlined, title: 'مطابقة الهوية', subtitle: 'تجهيز وثيقة الهوية للمطابقة عبر مزود eKYC.'),
        const _FeatureTile(icon: Icons.verified_user, title: 'مراجعة واعتماد', subtitle: 'لا يتم اعتماد التوثيق قبل صدور نتيجة تحقق موثوقة.'),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopApplicationScreen())), icon: const Icon(Icons.arrow_forward), label: const Text('ابدأ التقديم للمتجر'))),
      ]),
    );
  }

  Widget _metric(String label, String value) => Column(children: [Text(value, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 18)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))]);

  Widget _tool(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) => Card(child: ListTile(leading: Icon(icon, color: AppColors.gold), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)), trailing: const Icon(Icons.chevron_left), onTap: onTap));

  void _showRatings(BuildContext context, List listings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الإعجابات والتقييمات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            Text('سيظهر هنا متوسط التقييم وعدد الإعجابات من بيانات العملاء المنشورة بعد ربط جداول التقييمات.', style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 20),
          ]),
        ),
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
