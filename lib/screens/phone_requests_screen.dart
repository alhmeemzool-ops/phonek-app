import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class PhoneRequestsScreen extends StatefulWidget {
  const PhoneRequestsScreen({super.key});

  @override
  State<PhoneRequestsScreen> createState() => _PhoneRequestsScreenState();
}

class _PhoneRequestsScreenState extends State<PhoneRequestsScreen> {
  static const _customModelOption = 'موديل آخر / أضف موديل';
  String? _brand;
  String? _model;
  bool _addingCustomModel = false;
  String? _storage = '';
  String? _ram = '';
  String? _condition = '';
  String? _city;
  final _customCityController = TextEditingController();
  final _customModelController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final requests = appState.phoneRequests;
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الهواتف')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _introCard(),
          const SizedBox(height: 16),
          _requestForm(appState),
          const SizedBox(height: 24),
          const Text('طلبات الشراء الحالية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (requests.isEmpty)
            const _EmptyRequests()
          else
            ...requests.map(_requestCard),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3A2B0B), Color(0xFF211B10)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.campaign_outlined, color: AppColors.gold, size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اكتب الهاتف الذي تبحث عنه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('انشر طلبك مجاناً ليشاهده البائعون والمحلات ويتواصلوا معك عند توفر الجهاز.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestForm(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('طلب جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _brand,
              items: MockData.brands.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
              onChanged: (value) => setState(() {
                _brand = value;
                _model = null;
                _addingCustomModel = false;
                _customModelController.clear();
              }),
              decoration: const InputDecoration(labelText: 'الماركة (اختياري)', prefixIcon: Icon(Icons.branding_watermark_outlined)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _model,
              items: [
                ...appState.phoneModelsForBrand(_brand),
                _customModelOption,
              ]
                  .map((model) => DropdownMenuItem(value: model, child: Text(model)))
                  .toList(),
              onChanged: _brand == null
                  ? null
                  : (value) => setState(() {
                        _addingCustomModel = value == _customModelOption;
                        _model = _addingCustomModel ? null : value;
                        if (!_addingCustomModel) _customModelController.clear();
                      }),
              decoration: InputDecoration(
                labelText: 'الموديل (اختياري)',
                hintText: _brand == null ? 'اختر الماركة أولاً' : 'اختر الموديل',
                prefixIcon: const Icon(Icons.phone_android_outlined),
              ),
            ),
            if (_addingCustomModel) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customModelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'اكتب اسم الموديل',
                  hintText: 'مثال: Galaxy A99 Ultra',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('سيتم حفظ الموديل وإتاحته لجميع المستخدمين بعد نشر الطلب.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _storage,
                    items: const ['', '64GB', '128GB', '256GB', '512GB', '1TB']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value.isEmpty ? 'لا شيء' : value)))
                        .toList(),
                    onChanged: (value) => setState(() => _storage = value),
                    decoration: const InputDecoration(labelText: 'التخزين', prefixIcon: Icon(Icons.sd_storage_outlined)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _ram,
                    items: const ['', '4GB', '6GB', '8GB', '12GB', '16GB']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value.isEmpty ? 'لا شيء' : value)))
                        .toList(),
                    onChanged: (value) => setState(() => _ram = value),
                    decoration: const InputDecoration(labelText: 'الرام', prefixIcon: Icon(Icons.memory_outlined)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              items: const ['', 'جديد', 'مستعمل بحالة ممتازة', 'خدوش بسيطة']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value.isEmpty ? 'لا شيء' : value)))
                  .toList(),
              onChanged: (value) => setState(() => _condition = value),
              decoration: const InputDecoration(labelText: 'الحالة المطلوبة', prefixIcon: Icon(Icons.verified_outlined)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _city,
              items: MockData.cities.map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
              onChanged: (value) => setState(() => _city = value),
              decoration: const InputDecoration(labelText: 'الولاية أو المدينة', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            if (_city == 'مدينة أخرى') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCityController,
                decoration: const InputDecoration(labelText: 'اكتب المدينة أو المنطقة'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _maxPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الحد الأعلى للسعر (اختياري)',
                suffixText: 'ج.س',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات إضافية (اختياري)',
                hintText: 'مثال: أريد الجهاز مع الكرتونة وبحالة ممتازة',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitRequest,
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('نشر طلب الهاتف'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(PhoneRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceLight,
          child: Icon(Icons.search, color: AppColors.gold),
        ),
        title: Text(request.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            [
              request.city,
              if (request.details.isNotEmpty) request.details,
              if (request.maxPrice != null) 'حتى ${AppFormatters.priceSDG(request.maxPrice!)}',
              if (request.notes.isNotEmpty) request.notes,
            ].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
      ),
    );
  }

  Future<void> _submitRequest() async {
    final appState = context.read<AppState>();
    if (!appState.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولاً حتى يتمكن البائعون من التواصل معك')),
      );
      return;
    }
    final city = _city == 'مدينة أخرى' ? _customCityController.text.trim() : _city;
    final customModel = _customModelController.text.trim();
    if (city == null || city.isEmpty || _brand == null || (!_addingCustomModel && _model == null) || (_addingCustomModel && customModel.length < 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الماركة أو الموديل وحدد المدينة أولاً')),
      );
      return;
    }

    final selectedModel = _addingCustomModel ? customModel : _model;
    if (_addingCustomModel) {
      try {
        await appState.addCustomPhoneModel(brand: _brand!, model: customModel);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الموديل: $error')));
        }
        return;
      }
    }
    final maxPriceText = _maxPriceController.text.replaceAll(',', '').trim();
    final request = PhoneRequest(
      id: 'request-${DateTime.now().microsecondsSinceEpoch}',
      brand: _brand,
      model: selectedModel,
      storage: _storage,
      ram: _ram,
      condition: _condition,
      city: city,
      maxPrice: maxPriceText.isEmpty ? null : int.tryParse(maxPriceText),
      notes: _notesController.text.trim(),
      createdAt: DateTime.now(),
    );
    appState.addPhoneRequest(request);
    _customCityController.clear();
    _maxPriceController.clear();
    _notesController.clear();
    _customModelController.clear();
    setState(() {
      _brand = null;
      _model = null;
      _addingCustomModel = false;
      _storage = '';
      _ram = '';
      _condition = '';
      _city = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر طلب الهاتف بنجاح')));
  }

  @override
  void dispose() {
    _customCityController.dispose();
    _customModelController.dispose();
    _maxPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: Text('لا توجد طلبات منشورة حالياً', style: TextStyle(color: AppColors.textSecondary))),
    );
  }
}
