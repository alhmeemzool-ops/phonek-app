import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';

class AddPhoneScreen extends StatefulWidget {
  const AddPhoneScreen({super.key});

  @override
  State<AddPhoneScreen> createState() => _AddPhoneScreenState();
}

class _AddPhoneScreenState extends State<AddPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _damageController = TextEditingController();
  final _customCityController = TextEditingController();

  String? _brand;
  String? _phoneModel;
  String? _city;
  String _storage = '128GB';
  String _ram = '6GB';
  DeviceCondition _condition = DeviceCondition.excellent;
  bool _priceNegotiable = true;
  bool _priceOnCall = false;
  bool _hasBox = true;
  bool _hasCharger = true;
  bool _hasInvoice = false;
  bool _hasDamage = false;
  bool _saving = false;
  String? _imagesError;
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _images = [];

  final _storageOptions = ['32GB', '64GB', '128GB', '256GB', '512GB', '1TB'];
  final _ramOptions = ['3GB', '4GB', '6GB', '8GB', '12GB', '16GB'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة هاتف')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label('صور الهاتف'),
            _imagePickerRow(),
            if (_imagesError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _imagesError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _label('الماركة'),
            DropdownButtonFormField<String>(
              initialValue: _brand,
              items: MockData.brands
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _brand = value;
                  _phoneModel = null;
                  _titleController.clear();
                });
              },
              decoration: const InputDecoration(hintText: 'اختر الماركة أولاً'),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            _label('اسم الهاتف'),
            DropdownButtonFormField<String>(
              initialValue: _phoneModel,
              items: (MockData.phoneModelsByBrand[_brand] ?? const <String>[])
                  .map((model) =>
                      DropdownMenuItem(value: model, child: Text(model)))
                  .toList(),
              onChanged: _brand == null
                  ? null
                  : (value) => setState(() {
                        _phoneModel = value;
                        _titleController.text = value ?? '';
                      }),
              decoration: InputDecoration(
                hintText:
                    _brand == null ? 'اختر الماركة أولاً' : 'اختر اسم الهاتف',
              ),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            _label('السعر (ج.س)'),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              enabled: !_priceOnCall,
              decoration: const InputDecoration(hintText: 'مثال: 250000'),
              validator: (v) {
                if (_priceOnCall) return null;
                if (v == null || v.isEmpty) return 'مطلوب';
                final n = int.tryParse(v);
                if (n == null) return 'رقم غير صحيح';
                if (n < 10000) {
                  return 'الحد الأدنى للسعر 10,000 ج.س، أو فعّل "اتصل للسعر"';
                }
                return null;
              },
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _priceNegotiable,
                    onChanged: (v) =>
                        setState(() => _priceNegotiable = v ?? true),
                    title: const Text('قابل للتفاوض',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _priceOnCall,
                    onChanged: (v) => setState(() => _priceOnCall = v ?? false),
                    title: const Text('اتصل للسعر',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _label('التخزين'),
            Wrap(
              spacing: 8,
              children: _storageOptions
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _storage == s,
                        onSelected: (_) => setState(() => _storage = s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _label('الرام'),
            Wrap(
              spacing: 8,
              children: _ramOptions
                  .map((r) => ChoiceChip(
                        label: Text(r),
                        selected: _ram == r,
                        onSelected: (_) => setState(() => _ram = r),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            _label('حالة الجهاز'),
            RadioGroup<DeviceCondition>(
              groupValue: _condition,
              onChanged: (value) {
                if (value != null) setState(() => _condition = value);
              },
              child: Column(
                children: DeviceCondition.values.map<Widget>((c) {
                  return RadioListTile<DeviceCondition>(
                    contentPadding: EdgeInsets.zero,
                    value: c,
                    title: Text(c.labelAr, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasDamage,
              onChanged: (v) => setState(() => _hasDamage = v ?? false),
              title: const Text('يوجد عيوب أو أعطال أذكرها',
                  style: TextStyle(fontSize: 13)),
            ),
            if (_hasDamage)
              TextFormField(
                controller: _damageController,
                decoration: const InputDecoration(
                    hintText: 'مثال: بصمة لا تعمل، خدش بالزاوية'),
                maxLines: 2,
              ),
            const SizedBox(height: 16),
            _label('الملحقات المرفقة'),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('الكرتونة'),
                  selected: _hasBox,
                  onSelected: (v) => setState(() => _hasBox = v),
                ),
                FilterChip(
                  label: const Text('الشاحن الأصلي'),
                  selected: _hasCharger,
                  onSelected: (v) => setState(() => _hasCharger = v),
                ),
                FilterChip(
                  label: const Text('الفاتورة'),
                  selected: _hasInvoice,
                  onSelected: (v) => setState(() => _hasInvoice = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label('المدينة'),
            DropdownButtonFormField<String>(
              initialValue: _city,
              items: MockData.cities
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _city = v),
              decoration:
                  const InputDecoration(hintText: 'اختر الولاية أو المدينة'),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
            if (_city == 'مدينة أخرى') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _customCityController,
                decoration: const InputDecoration(
                    hintText: 'اكتب اسم المدينة أو المنطقة'),
                validator: (value) => _city == 'مدينة أخرى' &&
                        (value == null || value.trim().isEmpty)
                    ? 'اكتب اسم المدينة'
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            _label('الوصف'),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'اكتب تفاصيل إضافية عن الهاتف... ولأجهزة الآيفون اذكر صحة البطارية هنا.',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('نشر الإعلان'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _saving ? null : _saveDraft,
              child: const Text('حفظ كمسودة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );

  Widget _imagePickerRow() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) =>
            index == 0 ? _addImageBox() : _imagePreview(index - 1),
      ),
    );
  }

  Widget _addImageBox() {
    return InkWell(
      onTap: _pickImages,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(Icons.add_a_photo, color: AppColors.gold),
      ),
    );
  }

  Widget _imagePreview(int index) {
    final image = _images[index];
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        return Stack(
          children: [
            Container(
              width: 90,
              height: 90,
              clipBehavior: Clip.antiAlias,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(10)),
              child: snapshot.hasData
                  ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                  : const ColoredBox(
                      color: AppColors.surfaceLight,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
            ),
            Positioned(
              top: 3,
              right: 3,
              child: GestureDetector(
                onTap: () => setState(() => _images.removeAt(index)),
                child: const CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.black87,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImages() async {
    final remaining = 5 - _images.length;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يمكنك إضافة 5 صور كحد أقصى')));
      return;
    }
    final selected =
        await _imagePicker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (!mounted || selected.isEmpty) return;
    setState(() {
      _images.addAll(selected.take(remaining));
      if (_images.isNotEmpty) _imagesError = null;
    });
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    setState(() {
      _imagesError = _images.isEmpty ? 'أضف صورة واحدة على الأقل' : null;
    });
    if (!formValid || _images.isEmpty) return;
    final user = context.read<AppState>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('سجّل الدخول أولاً حتى تتمكن من نشر إعلان')),
      );
      return;
    }

    final appState = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final price = _priceOnCall ? 0 : int.parse(_priceController.text.trim());
      final uploadedPaths = <String>[];
      final imageUrls = <String>[];
      for (var index = 0; index < _images.length; index++) {
        final image = _images[index];
        final path =
            '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$index.${_extensionFor(image.name)}';
        final bytes = await image.readAsBytes();
        await Supabase.instance.client.storage
            .from('listing-images')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                  contentType: _contentTypeFor(image.name), upsert: false),
            );
        uploadedPaths.add(path);
        imageUrls.add(Supabase.instance.client.storage
            .from('listing-images')
            .getPublicUrl(path));
      }
      try {
        await Supabase.instance.client.from('listings').insert({
          'seller_id': user.id,
          'title': _titleController.text.trim(),
          'brand': _brand,
          'price': price,
          'price_is_negotiable': _priceNegotiable,
          'price_on_call': _priceOnCall,
          'storage': _storage,
          'ram': _ram,
          'condition': _condition.name,
          'damage_notes': _hasDamage ? _damageController.text.trim() : null,
          'has_box': _hasBox,
          'has_charger': _hasCharger,
          'has_invoice': _hasInvoice,
          'warranty': WarrantyType.none.name,
          'city':
              _city == 'مدينة أخرى' ? _customCityController.text.trim() : _city,
          'image_urls': imageUrls,
          'status': ListingStatus.active.name,
          'description': _descController.text.trim(),
          'expires_at':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        });
      } catch (_) {
        if (uploadedPaths.isNotEmpty) {
          await Supabase.instance.client.storage
              .from('listing-images')
              .remove(uploadedPaths);
        }
        rethrow;
      }
      await appState.loadListings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر الإعلان بنجاح وهو ظاهر الآن للجميع')),
      );
      _resetForm();
    } on StorageException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذر رفع الصور: ${_storageErrorMessage(error)}')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الإعلان: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر نشر الإعلان: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _storageErrorMessage(StorageException error) {
    final message = error.message.trim();
    if (message.toLowerCase().contains('row-level security') ||
        message.toLowerCase().contains('not authorized') ||
        message.toLowerCase().contains('unauthorized')) {
      return 'تأكد من تسجيل الدخول وصلاحيات مجلد الصور';
    }
    return message.isEmpty ? 'تحقق من الاتصال وحاول مرة أخرى' : message;
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _priceController.clear();
    _descController.clear();
    _damageController.clear();
    setState(() {
      _brand = null;
      _city = null;
      _storage = '128GB';
      _ram = '6GB';
      _condition = DeviceCondition.excellent;
      _priceNegotiable = true;
      _priceOnCall = false;
      _hasBox = true;
      _hasCharger = true;
      _hasInvoice = false;
      _hasDamage = false;
      _phoneModel = null;
      _images.clear();
    });
  }

  String _contentTypeFor(String name) {
    switch (_extensionFor(name)) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _extensionFor(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? 'jpg' : name.substring(dot + 1).toLowerCase();
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('حفظ المسودة سيُفعّل مع نظام الإعلانات القادم')),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _damageController.dispose();
    _customCityController.dispose();
    super.dispose();
  }
}
