import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

class ShopAccountScreen extends StatefulWidget {
  const ShopAccountScreen({super.key});

  @override
  State<ShopAccountScreen> createState() => _ShopAccountScreenState();
}

class _ShopAccountScreenState extends State<ShopAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _shopNameController.text = state.shopName ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'display_name': user.userMetadata?['full_name'] ?? user.email ?? 'مستخدم PhoneK',
        'account_type': 'shop',
        'shop_name': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات المحل بنجاح')));
      Navigator.pop(context);
    } on PostgrestException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: ${error.message}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حساب صاحب محل')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.storefront, size: 64, color: AppColors.gold),
            const SizedBox(height: 12),
            const Text('أنشئ صفحة محلك', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('اعرض إعلاناتك، استقبل استفسارات العملاء، وابنِ تقييمًا موثوقًا.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            TextFormField(controller: _shopNameController, decoration: const InputDecoration(labelText: 'اسم المحل', prefixIcon: Icon(Icons.store)), validator: (value) => value == null || value.trim().length < 2 ? 'أدخل اسم المحل' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم التواصل', prefixIcon: Icon(Icons.phone)), validator: (value) => value == null || value.trim().length < 7 ? 'أدخل رقمًا صحيحًا' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'المدينة', prefixIcon: Icon(Icons.location_city)), validator: (value) => value == null || value.trim().isEmpty ? 'أدخل المدينة' : null),
            const SizedBox(height: 24),
            const _FeatureTile(icon: Icons.campaign, title: 'إدارة الإعلانات', subtitle: 'إضافة وتعديل وإيقاف إعلانات محلك.'),
            const _FeatureTile(icon: Icons.chat_bubble_outline, title: 'استفسارات العملاء', subtitle: 'متابعة المحادثات والعروض الواردة.'),
            const _FeatureTile(icon: Icons.insights, title: 'إحصائيات المحل', subtitle: 'مشاهدات الإعلانات والتقييمات والمبيعات.'),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ وتفعيل حساب المحل'))),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: AppColors.surfaceLight, child: Icon(icon, color: AppColors.gold)),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}
