import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  double? _latitude;
  double? _longitude;
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
          .select('shop_city, shop_address, shop_latitude, shop_longitude, shop_verification_status, phone, name')
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
    final source = await _chooseSource();
    if (source == null) return;
    final file = await _imagePicker.pickVideo(source: source, maxDuration: const Duration(seconds: 15));
    if (file != null && mounted) setState(() => _identityVideo = file);
  }

  Future<void> _pickShopLocation() async {
    final selected = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LocationPicker(initial: _latitude == null || _longitude == null ? const LatLng(15.5007, 32.5599) : LatLng(_latitude!, _longitude!)),
    );
    if (selected != null && mounted) {
      setState(() {
        _latitude = selected.latitude;
        _longitude = selected.longitude;
      });
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
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد موقع المحل من الخريطة قبل الإرسال')),
      );
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
              onPressed: isPending || isApproved ? null : _pickShopLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(_latitude == null ? 'مشاركة موقع المحل من الخريطة' : 'تم تحديد موقع المحل من الخريطة'),
            ),
            if (_latitude == null && !isPending && !isApproved)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('حدد نقطة المحل على الخريطة قبل إرسال الطلب', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
            const SizedBox(height: 18),
            const Text('إثبات الهوية إلزامي', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('يمكن اختيار إثبات الهوية وفيديو الوجه من معرض الهاتف أو الكاميرا. يُحفظ الإثبات في مساحة خاصة ولا يراه إلا الأدمن المصرّح له بالمراجعة.', style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: isPending || isApproved ? null : _pickIdentityImage, icon: const Icon(Icons.badge_outlined), label: Text(_identityImage == null ? 'اختيار صورة إثبات الهوية' : 'تم اختيار صورة الإثبات')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: isPending || isApproved ? null : _pickIdentityVideo, icon: const Icon(Icons.videocam_outlined), label: Text(_identityVideo == null ? 'اختيار فيديو إثبات الوجه' : 'تم اختيار فيديو الإثبات')),
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


class _LocationPicker extends StatefulWidget {
  const _LocationPicker({required this.initial});

  final LatLng initial;

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  late LatLng _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(child: Text('حدد موقع المحل من الخريطة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('اضغط على موقع المحل، ثم اضغط حفظ الموقع.', style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selected,
                initialZoom: 13,
                onTap: (_, point) => setState(() => _selected = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.phonek.phonek_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 46),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.check),
                label: const Text('حفظ موقع المحل'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
