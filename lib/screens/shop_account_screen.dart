import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _addressController = TextEditingController();
  final _imagePicker = ImagePicker();
  XFile? _identityImage;
  XFile? _identityVideo;
  bool _saving = false;
  bool _loading = true;
  String _status = 'none';

  @override
  void initState() {
    super.initState();
    _loadExistingRequest();
  }

  Future<void> _loadExistingRequest() async {
    final state = context.read<AppState>();
    final user = state.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('shop_city, shop_address, shop_verification_status, phone, name')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) {
        _shopNameController.text = row['name'] as String? ?? '';
        _phoneController.text = row['phone'] as String? ?? '';
        _cityController.text = row['shop_city'] as String? ?? '';
        _addressController.text = row['shop_address'] as String? ?? '';
        _status = row['shop_verification_status'] as String? ?? 'none';
      }
    } catch (_) {
      // The form remains usable while the optional verification migration is pending.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _captureIdentityImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file != null && mounted) setState(() => _identityImage = file);
  }

  Future<void> _captureIdentityVideo() async {
    final file = await _imagePicker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 15),
    );
    if (file != null && mounted) setState(() => _identityVideo = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_identityImage == null || _identityVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صوّر صورة الهوية وفيديو قصير للوجه قبل الإرسال')),
      );
      return;
    }
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final uploadedPaths = <String>[];
    try {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final imagePath = '${user.id}/identity_$stamp.jpg';
      final videoPath = '${user.id}/identity_$stamp.mp4';
      await client.storage.from('verification-documents').uploadBinary(
            imagePath,
            await _identityImage!.readAsBytes(),
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      uploadedPaths.add(imagePath);
      await client.storage.from('verification-documents').uploadBinary(
            videoPath,
            await _identityVideo!.readAsBytes(),
            fileOptions: const FileOptions(contentType: 'video/mp4'),
          );
      uploadedPaths.add(videoPath);
      await client.from('shop_verification_requests').insert({
        'user_id': user.id,
        'shop_name': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'identity_image_path': imagePath,
        'identity_video_path': videoPath,
        'status': 'pending',
      });
      await client.from('profiles').upsert({
        'id': user.id,
        'name': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'shop_city': _cityController.text.trim(),
        'shop_address': _addressController.text.trim(),
        'shop_verification_status': 'pending',
        'is_shop': false,
      });
      if (!mounted) return;
      setState(() => _status = 'pending');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب المحل للأدمن، وسيبقى قيد المراجعة')),
      );
    } on PostgrestException catch (error) {
      if (uploadedPaths.isNotEmpty) {
        await client.storage.from('verification-documents').remove(uploadedPaths);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الطلب: ${error.message}')),
        );
      }
    } on StorageException catch (error) {
      if (uploadedPaths.isNotEmpty) {
        await client.storage.from('verification-documents').remove(uploadedPaths);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر رفع الإثبات: ${error.message}')),
        );
      }
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        await client.storage.from('verification-documents').remove(uploadedPaths);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ غير متوقع أثناء إرسال الطلب')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isPending = _status == 'pending';
    final isApproved = _status == 'approved';
    return Scaffold(
      appBar: AppBar(title: const Text('توثيق حساب المحل')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.storefront, size: 64, color: AppColors.gold),
            const SizedBox(height: 12),
            const Text('طلب حساب محل موثّق', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              isApproved
                  ? 'تم اعتماد حساب محلك.'
                  : isPending
                      ? 'طلبك قيد المراجعة لدى الأدمن. لا ترسل طلبًا جديدًا قبل ظهور النتيجة.'
                      : 'أرسل بيانات المحل وإثبات الهوية ليقوم الأدمن بمراجعتها.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 22),
            TextFormField(controller: _shopNameController, enabled: !isPending && !isApproved, decoration: const InputDecoration(labelText: 'اسم المحل', prefixIcon: Icon(Icons.store)), validator: (value) => value == null || value.trim().length < 2 ? 'أدخل اسم المحل' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneController, enabled: !isPending && !isApproved, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم التواصل', prefixIcon: Icon(Icons.phone)), validator: (value) => value == null || value.trim().length < 7 ? 'أدخل رقمًا صحيحًا' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _cityController, enabled: !isPending && !isApproved, decoration: const InputDecoration(labelText: 'مدينة المحل', prefixIcon: Icon(Icons.location_city)), validator: (value) => value == null || value.trim().isEmpty ? 'مدينة المحل مطلوبة' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _addressController, enabled: !isPending && !isApproved, maxLines: 2, decoration: const InputDecoration(labelText: 'عنوان المحل بالتفصيل', hintText: 'الحي، الشارع، أقرب معلم', prefixIcon: Icon(Icons.location_on)), validator: (value) => value == null || value.trim().length < 5 ? 'عنوان المحل التفصيلي مطلوب' : null),
            const SizedBox(height: 18),
            const Text('إثبات الهوية إلزامي', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('يُحفظ الإثبات في مساحة خاصة ولا يراه إلا الأدمن المصرّح له بالمراجعة. استخدم الكاميرا وصوّر وجهك بوضوح.', style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: isPending || isApproved ? null : _captureIdentityImage, icon: const Icon(Icons.badge_outlined), label: Text(_identityImage == null ? 'تصوير صورة إثبات الهوية' : 'تم تصوير صورة الإثبات')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: isPending || isApproved ? null : _captureIdentityVideo, icon: const Icon(Icons.videocam_outlined), label: Text(_identityVideo == null ? 'تصوير فيديو قصير للوجه' : 'تم تصوير فيديو الإثبات')),
            const SizedBox(height: 14),
            const _SecurityNote(),
            const SizedBox(height: 22),
            if (!isPending && !isApproved)
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('إرسال طلب التوثيق للأدمن'))),
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
    _addressController.dispose();
    super.dispose();
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: AppColors.surfaceLight,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: AppColors.gold),
            SizedBox(width: 10),
            Expanded(child: Text('لا يتم تفعيل حساب المحل أو إظهار شارة التوثيق قبل موافقة الأدمن. لا ترفع مستندات غير مطلوبة، ويمكن حذف الطلب أو رفضه وفق سياسة الخصوصية.', style: TextStyle(color: AppColors.textSecondary, height: 1.4))),
          ],
        ),
      ),
    );
  }
}
