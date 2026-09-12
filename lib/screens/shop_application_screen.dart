import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_state.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'location_picker_screen.dart';

class ShopApplicationScreen extends StatefulWidget {
  const ShopApplicationScreen({super.key});

  @override
  State<ShopApplicationScreen> createState() => _ShopApplicationScreenState();
}

class _ShopApplicationScreenState extends State<ShopApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _picker = ImagePicker();
  int _step = 0;
  bool _saving = false;
  bool _locationBusy = false;
  XFile? _facePhoto;
  XFile? _faceVideo;
  XFile? _identityPhoto;
  double? _latitude;
  double? _longitude;
  double? _locationAccuracy;
  String? _address;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _shopName.text = state.shopName ?? '';
    _phone.text = Supabase.instance.client.auth.currentUser?.phone ?? '';
  }

  Future<void> _pickLocation() async {
    setState(() => _locationBusy = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      _locationAccuracy = position.accuracy;
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialLatitude: position.latitude,
            initialLongitude: position.longitude,
          ),
        ),
      );
      if (result != null) {
        setState(() {
          _latitude = (result['latitude'] as num?)?.toDouble();
          _longitude = (result['longitude'] as num?)?.toDouble();
          _address = result['address'] as String?;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديد موقع المحل: $error')));
      }
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _captureFace() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo != null && mounted) setState(() => _facePhoto = photo);
  }

  Future<void> _captureLivenessVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 8));
    if (video != null && mounted) setState(() => _faceVideo = video);
  }

  Future<void> _captureIdentity() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (image != null && mounted) setState(() => _identityPhoto = image);
  }

  bool _next() {
    if (_step == 0 && !(_formKey.currentState?.validate() ?? false)) return false;
    if (_step == 1 && (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدد موقع المحل على الخريطة أولاً')));
      return false;
    }
    if (_step == 2 && (_facePhoto == null || _faceVideo == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل التقاط الوجه وفيديو الحيوية أولاً')));
      return false;
    }
    if (_step == 3 && _identityPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التقط صورة واضحة لوثيقة الهوية أولاً')));
      return false;
    }
    setState(() => _step++);
    return true;
  }

  Future<void> _submit() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتهت جلسة الدخول. سجل الدخول مرة أخرى ثم أرسل الطلب.')));
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Captured media remains local until a trusted eKYC provider is integrated.
      // Never store raw faceprints or biometric templates in PhoneK.
      await client.from('shop_applications').insert({
        'user_id': user.id,
        'shop_name': _shopName.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'address': _address,
        'location_accuracy_m': _locationAccuracy,
        'verification_status': 'pending',
        'liveness_status': 'pending_provider',
        'identity_match_status': 'pending_provider',
        'kyc_result': 'pending',
        'consented_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Do not upsert profiles here. Profile RLS/schema rules must not turn a
      // successfully inserted shop application into a false submission error.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب المحل بنجاح. سيظهر للإدارة للمراجعة.')));
      Navigator.pop(context);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب إلى قاعدة البيانات: ${error.message}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقديم لفتح محل')),
      body: Stepper(
        currentStep: _step,
        controlsBuilder: (context, details) => Row(
          children: [
            ElevatedButton(onPressed: _saving ? null : (_step == 4 ? _submit : _next), child: Text(_step == 4 ? 'إرسال الطلب' : 'التالي')),
            if (_step > 0) ...[
              const SizedBox(width: 10),
              TextButton(onPressed: _saving ? null : () => setState(() => _step--), child: const Text('السابق')),
            ],
          ],
        ),
        steps: [
          Step(isActive: _step >= 0, title: const Text('بيانات المحل'), content: _details()),
          Step(isActive: _step >= 1, title: const Text('موقع المحل'), content: _location()),
          Step(isActive: _step >= 2, title: const Text('التقاط الوجه والحيوية'), content: _faceVerification()),
          Step(isActive: _step >= 3, title: const Text('وثيقة الهوية'), content: _identity()),
          Step(isActive: _step >= 4, title: const Text('المراجعة والإرسال'), content: _review()),
        ],
      ),
    );
  }

  Widget _details() => Form(
        key: _formKey,
        child: Column(children: [
          TextFormField(controller: _shopName, decoration: const InputDecoration(labelText: 'اسم المحل', prefixIcon: Icon(Icons.store)), validator: (v) => v == null || v.trim().length < 2 ? 'أدخل اسم المحل' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم التواصل', prefixIcon: Icon(Icons.phone)), validator: (v) => v == null || v.trim().length < 7 ? 'أدخل رقمًا صحيحًا' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'المدينة', prefixIcon: Icon(Icons.location_city)), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل المدينة' : null),
        ]),
      );

  Widget _location() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('شارك موقع المحل بسرعة من الخريطة، ثم ثبّت العلامة على المدخل أو الفرع الصحيح.'),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _locationBusy ? null : _pickLocation, icon: _locationBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.map), label: const Text('اختيار الموقع عبر Google Maps'))),
        if (_latitude != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text('تم تحديد الموقع: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}\n${_address ?? ''}')),
      ]);

  Widget _faceVerification() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('التقط صورة للوجه داخل الإطار، ثم فيديو قصير لتنفيذ حركة حيوية. هذه الخطوة لا تعني نجاح التحقق؛ النجاح يصدر فقط من مزود eKYC الموثوق.'),
        const SizedBox(height: 12),
        _captureTile(Icons.face, 'التقاط الوجه', _facePhoto != null, _captureFace),
        _captureTile(Icons.videocam, 'اختبار الحيوية — ابتسم أو أدر رأسك ببطء', _faceVideo != null, _captureLivenessVideo),
        const SizedBox(height: 8),
        const Text('المطابقة، كشف الصورة/الفيديو/القناع والتزييف العميق وإنشاء Faceprint لا تتم داخل Flutter ولا تُحفظ كبيانات خام في PhoneK.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]);

  Widget _identity() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('التقط وثيقة الهوية الرسمية بوضوح. ستُستخدم للمطابقة بواسطة مزود eKYC المعتمد.'),
        const SizedBox(height: 12),
        _captureTile(Icons.badge_outlined, 'تصوير وثيقة الهوية', _identityPhoto != null, _captureIdentity),
      ]);

  Widget _review() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _summary('المحل', _shopName.text),
        _summary('الهاتف', _phone.text),
        _summary('المدينة', _city.text),
        _summary('الموقع', _latitude == null ? 'غير محدد' : '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'),
        _summary('الوجه والحيوية', 'جاهز لبدء تحقق eKYC'),
        _summary('الهوية', 'جاهزة للمطابقة'),
        const SizedBox(height: 8),
        const Text('بعد الإرسال يبقى الطلب قيد التحقق. لا تُمنح شارة التوثيق ولا صلاحيات المحل قبل وصول نتيجة eKYC الموثقة والمراجعة.', style: TextStyle(color: AppColors.textSecondary)),
      ]);

  Widget _summary(String label, String value) => ListTile(contentPadding: EdgeInsets.zero, title: Text(label), subtitle: Text(value));

  Widget _captureTile(IconData icon, String title, bool done, VoidCallback onTap) => Card(
        child: ListTile(leading: Icon(icon, color: AppColors.gold), title: Text(title), trailing: Icon(done ? Icons.check_circle : Icons.camera_alt, color: done ? AppColors.gold : null), onTap: onTap),
      );

  @override
  void dispose() {
    _shopName.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }
}
