import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _timer;
  int _resendSeconds = 0;
  bool _isLoading = false;
  bool _codeSent = false;

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8 || digits.length > 15) {
      throw const AuthException('أدخل رقم الهاتف بصيغة دولية صحيحة، مثال: 2499XXXXXXXX');
    }
    return '+$digits';
  }

  Future<void> _sendCode() async {
    if (_isLoading || _resendSeconds > 0) return;
    setState(() => _isLoading = true);
    try {
      final phone = _normalizePhone(_phoneController.text);
      final response = await Supabase.instance.client.functions.invoke(
        'phone-otp',
        body: {'action': 'send', 'phone': phone},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['error'] != null) throw AuthException(data['error'].toString());

      setState(() => _codeSent = true);
      _startResendTimer((data['resendAfterSeconds'] as num?)?.toInt() ?? 60);
      _showMessage('تم إرسال رمز التحقق إلى WhatsApp');
    } catch (error) {
      _showMessage(error is AuthException ? error.message : 'تعذر إرسال رمز التحقق');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final phone = _normalizePhone(_phoneController.text);
      final code = _codeController.text.trim();
      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
        throw const AuthException('أدخل رمز التحقق المكوّن من 6 أرقام');
      }

      final response = await Supabase.instance.client.functions.invoke(
        'phone-otp',
        body: {'action': 'verify', 'phone': phone, 'code': code},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['error'] != null) throw AuthException(data['error'].toString());

      final accessToken = data['accessToken']?.toString();
      final refreshToken = data['refreshToken']?.toString();
      if (accessToken == null || refreshToken == null) {
        throw const AuthException('تعذر إنشاء جلسة الدخول');
      }
      await Supabase.instance.client.auth.setSession(refreshToken);
      // The audit row contains only login metadata; it never stores OTP codes.
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('login_events').insert({
          'user_id': userId,
          'phone_e164': phone,
          'method': 'whatsapp_otp',
          'success': true,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _showMessage(error is AuthException ? error.message : 'رمز التحقق غير صحيح أو انتهت صلاحيته');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startResendTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await context.read<AppState>().signInWithGoogle();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _showMessage('تعذر تسجيل الدخول عبر Google: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 36),
              const Icon(Icons.phone_android, size: 72, color: AppColors.gold),
              const SizedBox(height: 12),
              const Text('فونك | PhoneK', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gold)),
              const SizedBox(height: 6),
              const Text('سجّل دخولك برقم هاتفك عبر WhatsApp', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  hintText: '2499XXXXXXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              if (_codeSent) ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'رمز التحقق',
                    hintText: '000000',
                    prefixIcon: Icon(Icons.lock_outline),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    child: Text(_isLoading ? 'جارٍ التحقق...' : 'تحقق ودخول'),
                  ),
                ),
                TextButton(
                  onPressed: (_isLoading || _resendSeconds > 0) ? null : _sendCode,
                  child: Text(_resendSeconds > 0 ? 'إعادة الإرسال بعد $_resendSeconds ثانية' : 'إعادة إرسال الرمز'),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.mark_chat_unread_outlined),
                    label: Text(_isLoading ? 'جارٍ الإرسال...' : 'إرسال رمز عبر WhatsApp'),
                    onPressed: _isLoading ? null : _sendCode,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.g_mobiledata, size: 26),
                  label: const Text('الدخول عبر Google'),
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text('تصفح بدون تسجيل دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
