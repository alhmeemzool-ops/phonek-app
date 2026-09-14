import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../features/merchant_badges/merchant_badges_screen.dart';
import '../features/merchant_store/merchant_catalog_screen.dart';
import '../features/merchant_store/visitor_preview_button.dart';
import '../theme/app_theme.dart';
import 'shop_application_screen.dart';
import 'shop_profile_screen.dart';

class ShopAccountScreen extends StatelessWidget {
  const ShopAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final userId = state.currentUser?.id;
    final myListings = userId == null ? <dynamic>[] : state.listings.where((listing) => listing.seller.id == userId).toList();
    final totalViews = myListings.fold<int>(0, (sum, item) => sum + (int.tryParse('${item.viewCount}') ?? 0));

    if (state.isShopOwner || state.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('لوحة متجر ${state.shopName ?? 'PhoneK'}'),
          actions: [
            MerchantVisitorPreviewButton(
              onPressed: userId == null ? () {} : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopProfileScreen(shopId: userId))),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CircleAvatar(radius: 28, backgroundColor: AppColors.surfaceLight, child: Icon(Icons.storefront, color: AppColors.gold)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(state.shopName ?? 'متجر PhoneK الرسمي', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const Text('متجر مفعّل', style: TextStyle(color: AppColors.success)),
                    ])),
                    const Icon(Icons.verified, color: AppColors.gold),
                  ]),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: _metric('كتلوجي', '${myListings.length}')),
                    Expanded(child: _metric('مشاهدات', '$totalViews')),
                    Expanded(child: _metric('إعلانات نشطة', '${myListings.where((item) => item.status.name == 'active').length}')),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const Text('أدوات المتجر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _tool(context, Icons.inventory_2_outlined, 'كتلوجي وإعلاناتي', 'تعديل أو تجميد أو حذف إعلاناتك', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantCatalogScreen()))),
            _tool(context, Icons.workspace_premium_outlined, 'شارات المتجر', 'المستوى والتقدم وشروط كل شارة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantBadgesScreen()))),
            _tool(context, Icons.storefront_outlined, 'صفحة المتجر العامة', 'المعلومات والموقع والكتلوج', () {
              if (userId != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ShopProfileScreen(shopId: userId)));
            }),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('حساب التاجر')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.storefront, size: 64, color: AppColors.gold),
        const SizedBox(height: 12),
        const Text('أنشئ صفحة متجرك', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('قدّم طلب المتجر ثم أكمل بيانات المتجر والتحقق والمراجعة.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopApplicationScreen())), icon: const Icon(Icons.arrow_forward), label: const Text('ابدأ التقديم للمتجر')),
      ]),
    );
  }

  Widget _metric(String label, String value) => Column(children: [Text(value, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 18)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))]);

  Widget _tool(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) => Card(child: ListTile(leading: Icon(icon, color: AppColors.gold), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)), trailing: const Icon(Icons.chevron_left), onTap: onTap));
}
