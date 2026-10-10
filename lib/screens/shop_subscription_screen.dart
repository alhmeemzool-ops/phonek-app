import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/subscription_config.dart';
import '../theme/app_theme.dart';

class ShopSubscriptionScreen extends StatefulWidget {
  const ShopSubscriptionScreen({super.key});
  @override
  State<ShopSubscriptionScreen> createState() => _ShopSubscriptionScreenState();
}

class _ShopSubscriptionScreenState extends State<ShopSubscriptionScreen> {
  Map<String, dynamic>? _current;
  XFile? _document;
  XFile? _proof;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('shop_subscriptions')
          .select('*')
          .eq('shop_id', uid)
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (mounted) setState(() => _current = row);
    } catch (error) {
      if (mounted) _message('تعذر تحميل حالة الاشتراك: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<XFile?> _pickImage(String label) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image == null && mounted) _message('اختر صورة $label أولاً');
    return image;
  }

  Future<void> _submit() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _message('سجّل الدخول لإرسال طلب الاشتراك');
      return;
    }
    if (_document == null || _proof == null) {
      _message('أرفق وثيقة المتجر وإثبات الدفع قبل الإرسال');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final storage = Supabase.instance.client.storage.from('subscription-proofs');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final documentPath = '$uid/document_$stamp.jpg';
      final proofPath = '$uid/proof_$stamp.jpg';
      await storage.uploadBinary(
        documentPath,
        await _document!.readAsBytes(),
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      await storage.uploadBinary(
        proofPath,
        await _proof!.readAsBytes(),
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      await Supabase.instance.client.from('shop_subscriptions').insert({
        'shop_id': uid,
        'document_path': documentPath,
        'payment_proof_path': proofPath,
        'status': 'pending',
      });
      if (mounted) {
        _message('تم إرسال طلب الاشتراك والوثائق للمراجعة');
        setState(() {
          _document = null;
          _proof = null;
        });
        await _load();
      }
    } catch (error) {
      if (mounted) _message('تعذر إرسال طلب الاشتراك: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final price = SubscriptionConfig.priceSdg == 0
        ? 'السعر تحدده الإدارة'
        : '${SubscriptionConfig.priceSdg} ج.س';
    final status = _current?['status']?.toString() ?? 'لا يوجد طلب سابق';
    return Scaffold(
      appBar: AppBar(title: const Text('اشتراك المعرض')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('المزايا والعروض أولاً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('• ظهور أعلى للإعلانات والعروض\n• وسم معرض مميز\n• دعم عرض العروض النشطة على صفحة المتجر', style: TextStyle(height: 1.6)),
                      const SizedBox(height: 10),
                      Text('المدة: ${SubscriptionConfig.durationDays} يوماً'),
                      Text('السعر: $price'),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('خطوات الاشتراك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _uploadStep(
                        step: '1',
                        title: 'وثيقة المتجر',
                        subtitle: 'ارفع صورة واضحة من الوثيقة المطلوبة للمراجعة.',
                        selected: _document != null,
                        onTap: () async {
                          final image = await _pickImage('وثيقة المتجر');
                          if (image != null) setState(() => _document = image);
                        },
                      ),
                      const Divider(height: 24),
                      _uploadStep(
                        step: '2',
                        title: 'إثبات الدفع',
                        subtitle: 'أرفق صورة التحويل أو الإيصال.',
                        selected: _proof != null,
                        onTap: () async {
                          final image = await _pickImage('إثبات الدفع');
                          if (image != null) setState(() => _proof = image);
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                          label: Text(_saving ? 'جارٍ الإرسال...' : 'إرسال طلب الاشتراك'),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Text('الحالة الحالية: $status', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(SubscriptionConfig.paymentInstructions, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
    );
  }

  Widget _uploadStep({required String step, required String title, required String subtitle, required bool selected, required VoidCallback onTap}) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: selected ? AppColors.success : AppColors.surfaceLight, child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(selected ? 'تم اختيار الملف' : subtitle),
        trailing: Icon(selected ? Icons.check_circle : Icons.upload_file, color: selected ? AppColors.success : AppColors.gold),
        onTap: onTap,
      );
}
