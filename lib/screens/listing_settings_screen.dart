import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import 'my_listings_screen.dart';

class ListingSettingsScreen extends StatefulWidget {
  const ListingSettingsScreen({super.key, required this.listing});
  final PhoneListing listing;

  @override
  State<ListingSettingsScreen> createState() => _ListingSettingsScreenState();
}

class _ListingSettingsScreenState extends State<ListingSettingsScreen> {
  late final TextEditingController _title;
  late final TextEditingController _price;
  late final TextEditingController _city;
  late final TextEditingController _description;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.listing.title);
    _price = TextEditingController(text: widget.listing.price.toString());
    _city = TextEditingController(text: widget.listing.city);
    _description = TextEditingController(text: widget.listing.description);
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _city.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.replaceAll(',', '').trim());
    if (_title.text.trim().isEmpty || price == null || price < 0 || _city.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل العنوان والسعر والمدينة بشكل صحيح')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().updateListing(
        id: widget.listing.id,
        title: _title.text,
        price: price,
        city: _city.text,
        description: _description.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ تعديلات الإعلان')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إخفاء الإعلان؟'),
        content: const Text('سيتم إخراج الإعلان من الإعلانات النشطة ولن يظهر للزوار.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إخفاء الإعلان')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<AppState>().deleteListing(widget.listing.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إخفاء الإعلان: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<AppState>().currentUser?.id == widget.listing.seller.id;
    if (!owner) {
      return const Scaffold(body: Center(child: Text('هذه الصفحة متاحة لصاحب الإعلان فقط')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الإعلان')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.listing.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('تعديل بيانات الإعلان الظاهرة للزوار', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان الإعلان')),
            const SizedBox(height: 12),
            TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر (ج.س)')),
            const SizedBox(height: 12),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'المدينة')),
            const SizedBox(height: 12),
            TextField(controller: _description, maxLines: 5, decoration: const InputDecoration(labelText: 'الوصف')),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.visibility_off_outlined), label: const Text('إخفاء الإعلان'))),
          ]))),
          const SizedBox(height: 16),
          Card(child: ListTile(
            leading: const Icon(Icons.list_alt, color: AppColors.gold),
            title: const Text('إعلاناتي', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('فتح صفحة إعلاناتي من القائمة الرئيسية لإدارة كل إعلاناتك'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
          )),
          const SizedBox(height: 10),
          Card(color: AppColors.surfaceLight, child: const Padding(padding: EdgeInsets.all(14), child: Row(children: [Icon(Icons.lock_outline, size: 18, color: AppColors.gold), SizedBox(width: 8), Expanded(child: Text('زر الإعدادات لا يظهر إلا لصاحب الإعلان نفسه.'))]))),
        ],
      ),
    );
  }
}
