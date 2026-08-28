import 'package:flutter/material.dart';
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

  String? _brand;
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

  final _storageOptions = ['32GB', '64GB', '128GB', '256GB', '512GB'];
  final _ramOptions = ['3GB', '4GB', '6GB', '8GB', '12GB'];

  bool get _isIphone => (_brand ?? '').toLowerCase().contains('iphone');

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
            const SizedBox(height: 16),
            _label('اسم الهاتف'),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'مثال: Samsung Galaxy A73 5G'),
              validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            _label('الماركة'),
            DropdownButtonFormField<String>(
              initialValue: _brand,
              items: MockData.brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _brand = v),
              decoration: const InputDecoration(hintText: 'اختر الماركة'),
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
                if (n < 10000) return 'الحد الأدنى للسعر 10,000 ج.س، أو فعّل "اتصل للسعر"';
                return null;
              },
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _priceNegotiable,
                    onChanged: (v) => setState(() => _priceNegotiable = v ?? true),
                    title: const Text('قابل للتفاوض', style: TextStyle(fontSize: 13)),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _priceOnCall,
                    onChanged: (v) => setState(() => _priceOnCall = v ?? false),
                    title: const Text('اتصل للسعر', style: TextStyle(fontSize: 13)),
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
            if (_isIphone) ...[
              const SizedBox(height: 16),
              _label('صحة البطارية: $_batteryHealth%'),
              Slider(
                value: _batteryHealth.toDouble(),
                min: 50,
                max: 100,
                divisions: 50,
                activeColor: AppColors.gold,
                label: '$_batteryHealth%',
                onChanged: (v) => setState(() => _batteryHealth = v.round()),
              ),
            ],
            const SizedBox(height: 16),
            _label('حالة الجهاز'),
            RadioGroup<DeviceCondition>(
              groupValue: _condition,
              onChanged: (value) {
                if (value != null) setState(() => _condition = value);
              },
              child: Column(
                children: DeviceCondition.values.map((c) {
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
              title: const Text('يوجد عيوب أو أعطال أذكرها', style: TextStyle(fontSize: 13)),
            ),
            if (_hasDamage)
              TextFormField(
                controller: _damageController,
                decoration: const InputDecoration(hintText: 'مثال: بصمة لا تعمل، خدش بالزاوية'),
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
                FilterChip(
                  label: const Text('السماعة'),
                  selected: _hasEarphones,
                  onSelected: (v) => setState(() => _hasEarphones = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label('المدينة'),
            DropdownButtonFormField<String>(
              initialValue: _city,
              items: MockData.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _city = v),
              decoration: const InputDecoration(hintText: 'اختر المدينة'),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            _label('الوصف'),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'اكتب تفاصيل إضافية عن الهاتف...'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('نشر الإعلان'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _saveDraft,
              child: const Text('حفظ كمسودة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );

  Widget _imagePickerRow() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _addImageBox(),
          const SizedBox(width: 8),
          // ملاحظة: بعد ربط image_picker + Firebase Storage تُعرض الصور المختارة هنا فعلياً
        ],
      ),
    );
  }

  Widget _addImageBox() {
    return InkWell(
      onTap: () {
        // TODO: عند ربط image_picker، افتح خيار (الكاميرا / المعرض) هنا
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يتطلب ربط image_picker + Firebase Storage لرفع الصور فعلياً')),
        );
      },
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: const Icon(Icons.add_a_photo, color: AppColors.gold),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // TODO: عند ربط Firestore، احفظ PhoneListing جديد هنا بدل SnackBar
    // ملاحظة: هذه الشاشة تعمل كتبويب ضمن التنقل السفلي وليست شاشة مستقلة،
    // لذلك لا نستخدم Navigator.pop هنا؛ نكتفي بمسح النموذج وتنبيه المستخدم.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال الإعلان للمراجعة قبل النشر')),
    );
    _resetForm();
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
      _hasEarphones = false;
      _hasDamage = false;
      _batteryHealth = 100;
    });
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الإعلان كمسودة (لمدة 24 ساعة)')),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _damageController.dispose();
    super.dispose();
  }
}
