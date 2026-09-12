import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../features/merchant_badges/merchant_badges_screen.dart';
import 'login_screen.dart';
import 'my_listings_screen.dart';
import 'shop_account_screen.dart';
import 'admin_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('حسابي')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('تسجيل الدخول'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.surfaceLight,
            child: Text(AppFormatters.firstChar(appState.userName), style: const TextStyle(color: AppColors.gold, fontSize: 24)),
          ),
          const SizedBox(height: 8),
          Center(child: Text(appState.userName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          if (appState.userEmail != null) ...[
            const SizedBox(height: 4),
            Center(child: Text(appState.userEmail!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          ],
          const SizedBox(height: 20),
          _tile(
            context,
            Icons.list_alt,
            'إعلاناتي',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
          ),
          _tile(
            context,
            Icons.storefront,
            appState.isShopOwner ? 'لوحة المحل: ${appState.shopName ?? ''}' : 'إنشاء حساب صاحب محل',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopAccountScreen())),
          ),
          if (appState.isShopOwner)
            _tile(
              context,
              Icons.workspace_premium,
              'شارات المتجر',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantBadgesScreen())),
              ),
          if (appState.isAdmin)
            _tile(
              context,
              Icons.admin_panel_settings,
              'لوحة الإدارة',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
            ),
          _tile(context, Icons.bookmark, 'عمليات البحث المحفوظة', () => _showComingSoon(context, 'عمليات البحث المحفوظة')),
          _tile(context, Icons.notifications, 'إعدادات الإشعارات', () => _showComingSoon(context, 'إعدادات الإشعارات')),
          // لا نعرض لوحة الأدمن حتى يوجد تفويض حقيقي من قاعدة البيانات/RLS.
          _tile(context, Icons.help_outline, 'الأسئلة الشائعة', () => _showComingSoon(context, 'الأسئلة الشائعة')),
          _tile(context, Icons.description_outlined, 'الشروط والأحكام وسياسة الخصوصية', () => _showComingSoon(context, 'الشروط والأحكام وسياسة الخصوصية')),
          const Divider(height: 32),
          _tile(context, Icons.logout, 'تسجيل الخروج', () => appState.logout(), color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.gold),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ميزة $feature لم تُربط بعد بقاعدة البيانات. لن نعرض حالة نجاح وهمية.')),
    );
  }
}
