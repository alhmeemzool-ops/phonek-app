import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'shop_account_screen.dart';
import 'my_listings_screen.dart';
import 'phone_requests_screen.dart';

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
            child: Text(
              AppFormatters.firstChar(appState.userName),
              style: const TextStyle(color: AppColors.gold, fontSize: 24),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(appState.userName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          _tile(
            context,
            Icons.list_alt,
            'إعلاناتي وتحديث الأسعار',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
          ),
          _tile(
            context,
            Icons.campaign_outlined,
            'طلبات الهواتف',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneRequestsScreen())),
          ),
          _tile(
            context,
            Icons.storefront,
            appState.isShopOwner ? 'لوحة المحل: ${appState.shopName ?? ''}' : 'إنشاء حساب صاحب محل',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopAccountScreen())),
          ),
          _tile(context, Icons.bookmark, 'عمليات البحث المحفوظة', () {}),
          _tile(context, Icons.notifications, 'إعدادات الإشعارات', () {}),
          _tile(context, Icons.admin_panel_settings, 'لوحة تحكم الأدمن', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
          }),
          _tile(context, Icons.help_outline, 'الأسئلة الشائعة', () {}),
          _tile(context, Icons.description_outlined, 'الشروط والأحكام وسياسة الخصوصية', () {}),
          const Divider(height: 32),
          _tile(context, Icons.logout, 'تسجيل الخروج', () => appState.logout(), color: AppColors.textSecondary),
          _tile(
            context,
            Icons.delete_forever,
            'حذف الحساب نهائياً',
            () => _confirmDelete(context),
            color: AppColors.danger,
          ),
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف الحساب نهائياً'),
        content: const Text('سيتم حذف حسابك وكل إعلاناتك نهائياً ولا يمكن التراجع بعد 30 يوماً. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppState>().logout();
            },
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );
  }
}
