import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android, size: 72, color: AppColors.gold),
            const SizedBox(height: 12),
            const Text('فونك | PhoneK', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gold)),
            const SizedBox(height: 6),
            const Text('سجّل دخولك لإضافة إعلانات والتواصل مع البائعين',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.g_mobiledata, size: 26, color: Colors.black),
              label: const Text('الدخول عبر Google'),
              onPressed: () => _handleGoogleSignIn(context),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تصفح بدون تسجيل دخول'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleGoogleSignIn(BuildContext context) {
    // TODO: هذا زر تجريبي فقط.
    // لتفعيله فعلياً: أضف حزمتي google_sign_in و firebase_auth في pubspec.yaml
    // واربط مشروعك بـ Firebase Authentication (خطوة تتطلب حسابك الخاص - راجع الـ README).
    context.read<AppState>().login('مستخدم تجريبي');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الدخول (وضع تجريبي - يتطلب ربط Firebase للتفعيل الحقيقي)')),
    );
    Navigator.pop(context);
  }
}
