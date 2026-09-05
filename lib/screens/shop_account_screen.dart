import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import 'guided_identity_camera_screen.dart';

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
  double? _latitude;
  double? _longitude;
  bool _saving = false;
  bool _loading = true;
  String _status = 'none';
  double? _locationAccuracy;
  DateTime? _locationCapturedAt;
  bool _capturingLocation = false;

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
          .select('shop_city, shop_address, shop_latitude, shop_longitude, shop_location_accuracy_m, shop_location_captured_at, shop_verification_status, phone, name')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) {
        _shopNameController.text = row['name'] as String? ?? '';
        _phoneController.text = row['phone'] as String? ?? '';
        _cityController.text = row['shop_city'] as String? ?? '';
        _addressController.text = row['shop_address'] as String? ?? '';
        _latitude = (row['shop_latitude'] as num?)?.toDouble();
        _longitude = (row['shop_longitude'] as num?)?.toDouble();
        _locationAccuracy = (row['shop_location_accuracy_m'] as num?)?.toDouble();
        _locationCapturedAt = DateTime.tryParse(row['shop_location_captured_at'] as String? ?? '');
        _status = row['shop_verification_status'] as String? ?? 'none';
      }
    } catch (_) {
      // The form remains usable while the optional verification migration is pending.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<ImageSource?> _chooseSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من معرض الهاتف'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('استخدام الكاميرا'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIdentityImage() async {
    final source = await _chooseSource();
    if (source == null) return;
    final file = await _imagePicker.pickImage(source: source, imageQuality: 82, maxWidth: 1600, maxHeight: 1600);
    if (file != null && mounted) setState(() => _identityImage = file);
  }

  Future<void> _pickIdentityVideo() async {
    final file = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(builder: (_) => const GuidedIdentityCameraScreen()),
    );
    if (file != null && mounted) setState(() => _identityVideo = file);
  }

  Future<void> _captureShopLocation() async {
    if (_capturingLocation) return;
    setState(() => _capturingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('فعّل خدمة الموقع GPS من إعدادات الهاتف ثم حاول مرة أخرى.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw StateError('يجب السماح لـ PhoneK باستخدام الموقع حتى يتم تثبيت موقع المحل.');
      }
      final accuracyStatus = await Geolocator.getLocationAccuracy();
      if (accuracyStatus == LocationAccuracyStatus.reduced) {
        throw StateError('فعّل الموقع الدقيق Precise Location، فالموقع التقريبي غير مقبول.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 25)),
      );
      final inSudan = position.latitude >= 8.5 && position.latitude <= 22.2 && position.longitude >= 21.8 && position.longitude <= 38.6;
      if (!inSudan) throw StateError('يجب تثبيت موقع المحل من داخل السودان.');
      if (position.accuracy <= 0 || position.accuracy > 50) throw StateError('دقة GPS الحالية ${position.accuracy.toStringAsFixed(0)}م غير كافية. تحرك إلى مكان مفتوح وحاول مرة أخرى.');
      if (Platform.isAndroid && position.isMocked) throw StateError('تم اكتشاف موقع محاكى أو وهمي. عطّل Mock Location وحاول مرة أخرى.');
      final capturedAt = DateTime.now().toUtc();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationAccuracy = position.accuracy;
        _locationCapturedAt = capturedAt;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تثبيت موقع المحل من GPS الحقيقي بنجاح.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  String _extensionFor(String name, {required String fallback}) {
    final value = name.toLowerCase().split('.').last;
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'bmp', 'tif', 'tiff', 'avif', 'mp4', 'mov', 'm4v', 'webm', '3gp'};
    return allowed.contains(value) ? value : fallback;
  }

  String _contentTypeFor(String name, {required bool video}) {
    final extension = _extensionFor(name, fallback: video ? 'mp4' : 'jpg');
    if (video) {
      return switch (extension) {
        'mov' => 'video/quicktime',
        'webm' => 'video/webm',
        '3gp' => 'video/3gpp',
        _ => 'video/mp4',
      };
    }
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      'tif' || 'tiff' => 'image/tiff',
      'avif' => 'image/avif',
      _ => 'image/jpeg',
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null || _locationAccuracy == null || _locationCapturedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ثبّت موقع المحل من GPS داخل التطبيق قبل الإرسال')),
      );
      return;
    }
    if (_locationAccuracy! > 50 || DateTime.now().toUtc().difference(_locationCapturedAt!).inMinutes > 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قراءة الموقع قديمة أو دقتها غير كافية. ثبّت الموقع مرة أخرى.')));
      return;
    }
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
      final imageExtension = _extensionFor(_identityImage!.name, fallback: 'jpg');
      final videoExtension = _extensionFor(_identityVideo!.name, fallback: 'mp4');
      final imagePath = '${user.id}/identity_$stamp.$imageExtension';
      final videoPath = '${user.id}/identity_$stamp.$videoExtension';
      await client.storage.from('verification-documents').uploadBinary(
            imagePath,
            await _identityImage!.readAsBytes(),
            fileOptions: FileOptions(contentType: _contentTypeFor(_identityImage!.name, video: false)),
          );
      uploadedPaths.add(imagePath);
      await client.storage.from('verification-documents').uploadBinary(
            videoPath,
            await _identityVideo!.readAsBytes(),
            fileOptions: FileOptions(contentType: _contentTypeFor(_identityVideo!.name, video: true)),
          );
      uploadedPaths.add(videoPath);
      await client.from('shop_verification_requests').insert({
        'user_id': user.id,
        'shop_name': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'location_accuracy_m': _locationAccuracy,
        'location_captured_at': _locationCapturedAt!.toIso8601String(),
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
        'shop_latitude': _latitude,
        'shop_longitude': _longitude,
        'shop_location_accuracy_m': _locationAccuracy,
        'shop_location_captured_at': _locationCapturedAt!.toIso8601String(),
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isPending || isApproved || _capturingLocation ? null : _captureShopLocation,
              icon: _capturingLocation ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
              label: Text(_capturingLocation ? 'جاري التحقق من GPS...' : _locationCapturedAt == null ? 'تثبيت موقع المحل من GPS' : 'تم تثبيت موقع المحل من GPS'),
            ),
            if (_locationAccuracy != null && _locationCapturedAt != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('دقة الموقع: ${_locationAccuracy!.toStringAsFixed(0)}م — ${_locationCapturedAt!.toLocal()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
            if (_latitude == null && !isPending && !isApproved)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('يجب أن يكون التاجر داخل المحل ويفعّل GPS بدقة قبل إرسال الطلب.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
            const SizedBox(height: 18),
            const Text('إثبات الهوية إلزامي', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('صوّر مستند الهوية من المعرض أو الكاميرا، أما فيديو الوجه فيُسجّل داخل التطبيق فقط مع تعليمات وضع الوجه وتحريكه. يُحفظ الإثبات في مساحة خاصة ولا يراه إلا الأدمن المصرّح له بالمراجعة.', style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: isPending || isApproved ? null : _pickIdentityImage, icon: const Icon(Icons.badge_outlined), label: Text(_identityImage == null ? 'اختيار صورة إثبات الهوية' : 'تم اختيار صورة الإثبات')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: isPending || isApproved ? null : _pickIdentityVideo, icon: const Icon(Icons.videocam_outlined), label: Text(_identityVideo == null ? 'تصوير فيديو إثبات الوجه بالكاميرا' : 'تم تصوير فيديو الإثبات')),
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
      child: Padding(
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
