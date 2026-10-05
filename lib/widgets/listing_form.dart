import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/catalog_data.dart' as catalog;
import '../models/phone_model.dart';
import '../theme/app_theme.dart';

class ListingFormData {
  final String title;
  final String brand;
  final int price;
  final bool priceNegotiable;
  final bool priceOnCall;
  final String storage;
  final String ram;
  final int? batteryHealth;
  final DeviceCondition condition;
  final bool hasDamage;
  final String? damageNotes;
  final bool hasBox;
  final bool hasCharger;
  final bool hasInvoice;
  final bool hasEarphones;
  final String city;
  final String description;
  final List<String> existingImageUrls;
  final List<XFile> newImages;

  const ListingFormData({
    required this.title, required this.brand, required this.price,
    required this.priceNegotiable, required this.priceOnCall,
    required this.storage, required this.ram, required this.batteryHealth,
    required this.condition, required this.hasDamage, required this.damageNotes,
    required this.hasBox, required this.hasCharger, required this.hasInvoice,
    required this.hasEarphones, required this.city, required this.description,
    required this.existingImageUrls, required this.newImages,
  });
}

class ListingForm extends StatefulWidget {
  const ListingForm({
    super.key,
    this.initialListing,
    required this.submitLabel,
    required this.onSubmit,
    this.onSaveDraft,
  });

  final PhoneListing? initialListing;
  final String submitLabel;
  final Future<void> Function(ListingFormData data) onSubmit;
  final VoidCallback? onSaveDraft;

  @override
  State<ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<ListingForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _damageController = TextEditingController();
  final _imagePicker = ImagePicker();

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
  bool _hasEarphones = false;
  bool _hasDamage = false;
  int _batteryHealth = 100;
  bool _saving = false;
  final List<String> _existingImages = [];
  final List<XFile> _newImages = [];

  static const _storageOptions = ['32GB', '64GB', '128GB', '256GB', '512GB'];
  static const _ramOptions = ['3GB', '4GB', '6GB', '8GB', '12GB'];

  bool get _isIphone => _brand == 'Apple';

  @override
  void initState() {
    super.initState();
    final listing = widget.initialListing;
    if (listing == null) return;
    _brand = listing.brand;
    _phoneModel = listing.title;
    _titleController.text = listing.title;
    _priceController.text = listing.price.toString();
    _descController.text = listing.description;
    _city = listing.city;
    _storage = listing.storage;
    _ram = listing.ram;
    _condition = listing.condition;
    _priceNegotiable = listing.priceIsNegotiable;
    _priceOnCall = listing.priceOnCall;
    _hasBox = listing.hasBox;
    _hasCharger = listing.hasCharger;
    _hasInvoice = listing.hasInvoice;
    _hasEarphones = listing.hasEarphones;
    _hasDamage = listing.damageNotes?.trim().isNotEmpty == true;
    _damageController.text = listing.damageNotes ?? '';
    _batteryHealth = listing.batteryHealthPercent ?? 100;
    _existingImages.addAll(listing.imageUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _damageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('صور الهاتف'),
          _imagePickerRow(),
          const SizedBox(height: 16),
          _label('الماركة'),
          DropdownButtonFormField<String>(
            value: _brand,
            items: catalog.CatalogData.brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: _saving ? null : (value) => setState(() {
              _brand = value;
              _phoneModel = null;
              _titleController.clear();
            }),
            decoration: const InputDecoration(hintText: 'اختر الماركة أولاً'),
            validator: (v) => v == null ? 'مطلوب' : null,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _saveCatalogSuggestion(brand: null, model: null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('ماركة غير موجودة؟ أضف ماركة جديدة'),
            ),
          ),
          const SizedBox(height: 16),
          _label('اسم الهاتف'),
          _modelPicker(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _brand == null || _saving ? null : () => _saveCatalogSuggestion(brand: _brand, model: ''),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('موبايل غير موجود؟ أضف موبايل جديد'),
            ),
          ),
          const SizedBox(height: 16),
          _label('السعر (ج.س)'),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            enabled: !_priceOnCall && !_saving,
            decoration: const InputDecoration(hintText: 'مثال: 250000'),
            validator: (v) {
              if (_priceOnCall) return null;
              if (v == null || v.trim().isEmpty) return 'مطلوب';
              final n = int.tryParse(v.trim());
              if (n == null) return 'رقم غير صحيح';
              if (n < 10000) return 'الحد الأدنى للسعر 10,000 ج.س، أو فعّل "اتصل للسعر"';
              return null;
            },
          ),
          Row(
            children: [
              Expanded(child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _priceNegotiable,
                onChanged: _saving ? null : (v) => setState(() => _priceNegotiable = v ?? true),
                title: const Text('قابل للتفاوض', style: TextStyle(fontSize: 13)),
              )),
              Expanded(child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _priceOnCall,
                onChanged: _saving ? null : (v) => setState(() => _priceOnCall = v ?? false),
                title: const Text('اتصل للسعر', style: TextStyle(fontSize: 13)),
              )),
            ],
          ),
          const SizedBox(height: 8),
          _label('التخزين'),
          Wrap(
            spacing: 8,
            children: _storageOptions.map((s) => ChoiceChip(
              label: Text(s), selected: _storage == s,
              onSelected: _saving ? null : (_) => setState(() => _storage = s),
            )).toList(),
          ),
          const SizedBox(height: 12),
          _label('الرام'),
          Wrap(
            spacing: 8,
            children: _ramOptions.map((r) => ChoiceChip(
              label: Text(r), selected: _ram == r,
              onSelected: _saving ? null : (_) => setState(() => _ram = r),
            )).toList(),
          ),
          if (_isIphone) ...[
            const SizedBox(height: 16),
            _label('صحة البطارية: $_batteryHealth%'),
            Slider(
              value: _batteryHealth.toDouble(), min: 50, max: 100, divisions: 50,
              activeColor: AppColors.gold, label: '$_batteryHealth%',
              onChanged: _saving ? null : (v) => setState(() => _batteryHealth = v.round()),
            ),
          ],
          const SizedBox(height: 16),
          _label('حالة الجهاز'),
          Column(children: DeviceCondition.values.map((c) => RadioListTile<DeviceCondition>(
            contentPadding: EdgeInsets.zero, value: c, groupValue: _condition,
            onChanged: _saving ? null : (value) { if (value != null) setState(() => _condition = value); },
            title: Text(c.labelAr, style: const TextStyle(fontSize: 13)),
          )).toList()),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero, value: _hasDamage,
            onChanged: _saving ? null : (v) => setState(() => _hasDamage = v ?? false),
            title: const Text('يوجد عيوب أو أعطال أذكرها', style: TextStyle(fontSize: 13)),
          ),
          if (_hasDamage) TextFormField(
            controller: _damageController, enabled: !_saving, maxLines: 2,
            decoration: const InputDecoration(hintText: 'مثال: بصمة لا تعمل، خدش بالزاوية'),
          ),
          const SizedBox(height: 16),
          _label('الملحقات المرفقة'),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: const Text('الكرتونة'), selected: _hasBox, onSelected: _saving ? null : (v) => setState(() => _hasBox = v)),
              FilterChip(label: const Text('الشاحن الأصلي'), selected: _hasCharger, onSelected: _saving ? null : (v) => setState(() => _hasCharger = v)),
              FilterChip(label: const Text('الفاتورة'), selected: _hasInvoice, onSelected: _saving ? null : (v) => setState(() => _hasInvoice = v)),
              FilterChip(label: const Text('السماعة'), selected: _hasEarphones, onSelected: _saving ? null : (v) => setState(() => _hasEarphones = v)),
            ],
          ),
          const SizedBox(height: 16),
          _label('المدينة'),
          _cityPicker(),
          const SizedBox(height: 16),
          _label('الوصف'),
          TextFormField(
            controller: _descController, enabled: !_saving, maxLines: 4,
            decoration: const InputDecoration(hintText: 'اكتب تفاصيل إضافية عن الهاتف...'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.submitLabel),
          ),
          if (widget.onSaveDraft != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _saving ? null : widget.onSaveDraft, child: const Text('حفظ كمسودة')),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  );

  Widget _modelPicker() {
    final models = [...(catalog.CatalogData.phoneModelsByBrand[_brand] ?? const <String>[])];
    if (_phoneModel != null && !models.any((m) => m.toLowerCase() == _phoneModel!.toLowerCase())) models.insert(0, _phoneModel!);
    return FormField<String>(
      initialValue: _phoneModel,
      validator: (_) => _phoneModel == null || _phoneModel!.trim().isEmpty ? 'مطلوب' : null,
      builder: (field) => InkWell(
        onTap: _brand == null || _saving ? null : () async {
          final picked = await showSearchablePicker(context, title: 'اختر الهاتف', groups: {'$_brand': models}, selectedValue: _phoneModel);
          if (picked == null || !mounted) return;
          setState(() { _phoneModel = picked; _titleController.text = picked; });
          field.didChange(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            hintText: _brand == null ? 'اختر الماركة أولاً' : 'ابحث واختر اسم الهاتف',
            errorText: field.errorText, suffixIcon: const Icon(Icons.search),
          ),
          child: Text(_phoneModel ?? 'اختر اسم الهاتف', style: TextStyle(color: _phoneModel == null ? AppColors.textSecondary : null)),
        ),
      ),
    );
  }

  Widget _cityPicker() {
    return FormField<String>(
      initialValue: _city,
      validator: (_) => _city == null || _city!.trim().isEmpty ? 'مطلوب' : null,
      builder: (field) => InkWell(
        onTap: _saving ? null : () async {
          final picked = await showCityPicker(context, selectedCity: _city);
          if (picked == null || !mounted) return;
          setState(() => _city = picked);
          field.didChange(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(hintText: 'اختر المدينة', errorText: field.errorText, suffixIcon: const Icon(Icons.search)),
          child: Text(_city ?? 'اختر المدينة'),
        ),
      ),
    );
  }

  Widget _imagePickerRow() {
    final total = _existingImages.length + _newImages.length;
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: total + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          if (index == 0) return _addImageBox();
          final imageIndex = index - 1;
          if (imageIndex < _existingImages.length) return _networkImagePreview(_existingImages[imageIndex], imageIndex);
          return _newImagePreview(imageIndex - _existingImages.length);
        },
      ),
    );
  }

  Widget _addImageBox() => InkWell(
    onTap: _pickImages,
    child: Container(
      width: 90, height: 90,
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
      child: const Icon(Icons.add_a_photo, color: AppColors.gold),
    ),
  );

  Widget _networkImagePreview(String url, int index) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(url, width: 90, height: 90, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surfaceLight, child: SizedBox(width: 90, height: 90, child: Icon(Icons.broken_image))),
        ),
      ),
      _removeButton(() => setState(() => _existingImages.removeAt(index))),
    ],
  );

  Widget _newImagePreview(int index) {
    final image = _newImages[index];
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (_, snapshot) => Stack(
        children: [
          Container(
            width: 90, height: 90, clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: snapshot.hasData ? Image.memory(snapshot.data!, fit: BoxFit.cover) : const ColoredBox(color: AppColors.surfaceLight, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          _removeButton(() => setState(() => _newImages.removeAt(index))),
        ],
      ),
    );
  }

  Widget _removeButton(VoidCallback onTap) => Positioned(
    top: 3, right: 3,
    child: GestureDetector(
      onTap: onTap,
      child: const CircleAvatar(radius: 11, backgroundColor: Colors.black87, child: Icon(Icons.close, size: 14, color: Colors.white)),
    ),
  );

  Future<void> _pickImages() async {
    final remaining = 6 - _existingImages.length - _newImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يمكنك إضافة 6 صور كحد أقصى')));
      return;
    }
    final selected = await _imagePicker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (!mounted || selected.isEmpty) return;
    setState(() => _newImages.addAll(selected.take(remaining)));
  }

  Future<void> _saveCatalogSuggestion({required String? brand, required String? model}) async {
    final brandController = TextEditingController(text: brand ?? '');
    final modelController = TextEditingController(text: model ?? '');
    final isBrandSuggestion = model == null;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isBrandSuggestion ? 'إضافة ماركة جديدة' : 'إضافة موبايل جديد'),
        content: TextField(
          controller: isBrandSuggestion ? brandController : modelController,
          autofocus: true, textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: isBrandSuggestion ? 'اسم الماركة' : 'اسم الموبايل'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
        ],
      ),
    );
    final value = (isBrandSuggestion ? brandController.text : modelController.text).trim();
    brandController.dispose(); modelController.dispose();
    if (result != true || value.isEmpty || !mounted) return;
    try {
      await Supabase.instance.client.from('phone_catalog_suggestions').insert({
        'brand': isBrandSuggestion ? value : _brand,
        'model': isBrandSuggestion ? null : value,
        'suggested_by': Supabase.instance.client.auth.currentUser?.id,
        'status': 'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الاقتراح وسيتم مراجعته قبل إضافته للقائمة')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الاقتراح حالياً')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_phoneModel == null || _city == null || _brand == null) return;
    final price = _priceOnCall ? 0 : int.parse(_priceController.text.trim());
    setState(() => _saving = true);
    try {
      await widget.onSubmit(ListingFormData(
        title: _phoneModel!.trim(), brand: _brand!, price: price,
        priceNegotiable: _priceNegotiable, priceOnCall: _priceOnCall,
        storage: _storage, ram: _ram, batteryHealth: _isIphone ? _batteryHealth : null,
        condition: _condition, hasDamage: _hasDamage,
        damageNotes: _hasDamage ? _damageController.text.trim() : null,
        hasBox: _hasBox, hasCharger: _hasCharger, hasInvoice: _hasInvoice,
        hasEarphones: _hasEarphones, city: _city!, description: _descController.text.trim(),
        existingImageUrls: List.unmodifiable(_existingImages),
        newImages: List.unmodifiable(_newImages),
      ));
    } catch (_) {
      // The parent screen is responsible for the user-facing Arabic error.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Future<String?> showSearchablePicker(BuildContext context, {
  required String title, required Map<String, List<String>> groups, String? selectedValue,
}) {
  return showModalBottomSheet<String>(
    context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetContext) {
      String query = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final filteredGroups = <String, List<String>>{};
          for (final entry in groups.entries) {
            final values = query.trim().isEmpty ? entry.value : entry.value.where((v) => v.toLowerCase().contains(query.trim().toLowerCase())).toList();
            if (values.isNotEmpty) filteredGroups[entry.key] = values;
          }
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .82,
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      onChanged: (value) => setState(() => query = value),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'اكتب للبحث...'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: filteredGroups.entries.expand((entry) sync* {
                        yield Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Text(entry.key, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)));
                        for (final value in entry.value) {
                          yield ListTile(
                            title: Text(value),
                            trailing: value == selectedValue ? const Icon(Icons.check, color: AppColors.gold) : null,
                            onTap: () => Navigator.pop(sheetContext, value),
                          );
                        }
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showCityPicker(BuildContext context, {String? selectedCity, bool includeAll = false}) async {
  final groups = <String, List<String>>{
    for (final entry in catalog.CatalogData.citiesByState.entries) entry.key: List.unmodifiable(entry.value),
  };
  if (includeAll) groups['الكل'] = ['الكل'];
  final result = await showSearchablePicker(context, title: 'اختر المدينة', groups: groups, selectedValue: includeAll && selectedCity == null ? 'الكل' : selectedCity);
  if (includeAll && result == 'الكل') return null;
  return result;
}
