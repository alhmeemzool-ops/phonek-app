import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../services/admin_store_provisioner.dart';
import 'login_screen.dart';
import 'my_listings_screen.dart';
import 'shop_account_screen.dart';
import 'admin_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.isLoggedIn) return Scaffold(appBar: AppBar(title: const Text('حسابي')), body: Center(child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())), child: const Text('تسجيل الدخول'))));
    final merchant = appState.isShopOwner || appState.isAdmin;
    return Scaffold(appBar: AppBar(title: const Text('حسابي')), body: ListView(children: [
      const SizedBox(height: 16),
      CircleAvatar(radius: 36, backgroundColor: AppColors.surfaceLight, child: Text(AppFormatters.firstChar(appState.userName), style: const TextStyle(color: AppColors.gold, fontSize: 24))),
      const SizedBox(height: 8), Center(child: Text(appState.userName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      if (appState.userEmail != null) ...[const SizedBox(height: 4), Center(child: Text(appState.userEmail!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)))],
      const SizedBox(height: 20),
      if (!merchant) _tile(context, Icons.list_alt, 'إعلاناتي', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen()))),
      _tile(context, Icons.storefront, 'متجري', () {
        // لا نعتمد على isShopOwner هنا؛ يتم تحميلها بشكل غير متزامن وقد تكون
        // ما زالت تخص الحساب السابق بعد تبديل الحساب. شاشة متجري تتحقق من
        // الحساب الحالي مباشرة وتعرض لوحة المتجر أو طلب فتح متجر.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopAccountScreen()),
        );
        if (appState.isAdmin) {
          AdminStoreProvisioner.ensure().then((_) {
            if (context.mounted) appState.loadListings();
          }).catchError((error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تعذر تجهيز متجر الأدمن: $error')),
              );
            }
          });
        }
      }),
      if (merchant) ...[
      ],
      if (appState.isAdmin) _tile(context, Icons.admin_panel_settings, 'لوحة الإدارة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()))),
      _tile(context, Icons.bookmark, 'عمليات البحث المحفوظة', () => _showComingSoon(context, 'عمليات البحث المحفوظة')),
      _tile(context, Icons.notifications, 'إعدادات الإشعارات', () => _showComingSoon(context, 'إعدادات الإشعارات')),
      _tile(context, Icons.help_outline, 'الأسئلة الشائعة', () => _showComingSoon(context, 'الأسئلة الشائعة')),
      _tile(context, Icons.description_outlined, 'الشروط والأحكام وسياسة الخصوصية', () => _showComingSoon(context, 'الشروط والأحكام وسياسة الخصوصية')),
      const Divider(height: 32),
      _tile(context, Icons.logout, 'تسجيل الخروج', () => appState.logout(), color: AppColors.textSecondary),
    ]));
  }
  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color? color}) => ListTile(leading: Icon(icon, color: color ?? AppColors.gold), title: Text(title, style: TextStyle(color: color)), trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary), onTap: onTap);
  void _showComingSoon(BuildContext context, String feature) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ميزة $feature لم تُربط بعد بقاعدة البيانات.')));
}
