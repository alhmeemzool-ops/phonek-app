import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await context.read<AppState>().signInWithGoogle();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الدخول عبر Google: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
            const Text('سجّل دخولك لإضافة إعلانات والتواصل مع البائعين', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.g_mobiledata, size: 26, color: Colors.black),
                label: Text(_isLoading ? 'جارٍ فتح Google...' : 'الدخول عبر Google'),
                onPressed: _isLoading ? null : _handleGoogleSignIn,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('تصفح بدون تسجيل دخول'),
            ),
          ],
        ),
      ),
    );
  }
}
