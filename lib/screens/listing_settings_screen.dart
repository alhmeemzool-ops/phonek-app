import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';

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
  late List<String> _images;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.listing.title);
    _price = TextEditingController(text: widget.listing.price.toString());
    _city = TextEditingController(text: widget.listing.city);
    _description = TextEditingController(text: widget.listing.description);
    _images = [...widget.listing.imageUrls];
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
        imageUrls: _images,
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

  Future<void> _addImages() async {
    final user = context.read<AppState>().currentUser;
    if (user == null || _images.length >= 6) return;
    final selected = await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
    if (!mounted || selected.isEmpty) return;
    try {
      for (final image in selected.take(6 - _images.length)) {
        final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}_${image.name}';
        await Supabase.instance.client.storage.from('listing-images').uploadBinary(path, await image.readAsBytes(), fileOptions: const FileOptions(upsert: false));
        _images.add(Supabase.instance.client.storage.from('listing-images').getPublicUrl(path));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة الصور: $e')));
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
            Row(
              children: [
                const Expanded(
                  child: Text('صور الإعلان', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: _addImages,
                  icon: const Icon(Icons.add_photo_alternate, color: AppColors.gold),
                  tooltip: 'إضافة صور',
                ),
              ],
            ),
            if (_images.isEmpty)
              const Text('لا توجد صور', style: TextStyle(color: AppColors.textSecondary))
            else
              SizedBox(
                height: 92,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final image = _images.removeAt(oldIndex);
                      _images.insert(newIndex, image);
                    });
                  },
                  itemBuilder: (_, index) {
                    return Padding(
                      key: ValueKey('${_images[index]}-$index'),
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _images[index],
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
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
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 6),
            const Text('اسحب الصور لترتيبها، واضغط × لحذف صورة.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.visibility_off_outlined), label: const Text('إخفاء الإعلان'))),
          ]))),
        ],
      ),
    );
  }
}
