import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/catalog_data.dart';
import '../theme/app_theme.dart';

class AccessoriesScreen extends StatefulWidget {
  const AccessoriesScreen({super.key});
  @override State<AccessoriesScreen> createState() => _AccessoriesScreenState();
}

class _AccessoriesScreenState extends State<AccessoriesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _query = '';
  String _city = 'الكل';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client.from('accessories')
          .select('*').eq('status', 'active').order('created_at', ascending: false);
      if (mounted) setState(() => _items = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل سوق الإكسسوارات')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولاً')));
      return;
    }

    final details = TextEditingController();
    String city = CatalogData.cities.first;
    String deliveryScope = 'all_states';
    String deliveryPayer = 'free';
    final images = <XFile>[];
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (saving) return;
            if (details.text.trim().isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('يرجى كتابة تفاصيل الإكسسوار')));
              return;
            }
            setDialogState(() => saving = true);
            try {
              final urls = <String>[];
              for (var i = 0; i < images.length; i++) {
                final path = '$uid/accessory_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                await Supabase.instance.client.storage.from('listing-images').uploadBinary(
                  path, await images[i].readAsBytes(),
                  fileOptions: const FileOptions(contentType: 'image/jpeg'));
                urls.add(Supabase.instance.client.storage.from('listing-images').getPublicUrl(path));
              }
              final text = details.text.trim();
              await Supabase.instance.client.from('accessories').insert({
                'seller_id': uid, 'title': text, 'category': '', 'price': null,
                'city': city, 'description': text, 'image_urls': urls,
                'delivery_scope': deliveryScope,
                'delivery_fee_payer': deliveryPayer,
                'status': 'pending_review',
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال الإكسسوار للمراجعة')));
                await _load();
              }
            } catch (e) {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('تعذر نشر الإكسسوار: $e')));
              }
            }
          }

          return AlertDialog(
            title: const Text('نشر إكسسوار'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: details, minLines: 6, maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'اكتب ما تريد عرضه',
                    hintText: 'اكتب تفاصيل الإكسسوار بحرية...',
                    alignLabelWithHint: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: city,
                  decoration: const InputDecoration(labelText: 'المدينة', border: OutlineInputBorder()),
                  items: CatalogData.cities.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                  onChanged: saving ? null : (v) { if (v != null) setDialogState(() => city = v); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: deliveryScope,
                  decoration: const InputDecoration(labelText: 'التوصيل', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'all_states', child: Text('توصيل لكل الولايات')),
                    DropdownMenuItem(value: 'within_state', child: Text('توصيل داخل الولاية فقط')),
                  ],
                  onChanged: saving ? null : (v) { if (v != null) setDialogState(() => deliveryScope = v); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: deliveryPayer,
                  decoration: const InputDecoration(labelText: 'تكلفة التوصيل', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'free', child: Text('التوصيل مجاناً')),
                    DropdownMenuItem(value: 'buyer', child: Text('التوصيل على حساب المشتري')),
                  ],
                  onChanged: saving ? null : (v) { if (v != null) setDialogState(() => deliveryPayer = v); },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: saving ? null : () async {
                    final picked = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
                    if (picked.isNotEmpty) setDialogState(() => images..clear()..addAll(picked));
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(images.isEmpty ? 'إضافة صور' : 'الصور المضافة: ${images.length}'),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton.icon(
                onPressed: saving ? null : submit,
                icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.publish),
                label: Text(saving ? 'جارٍ النشر...' : 'نشر'),
              ),
            ],
          );
        },
      ),
    );
    details.dispose();
  }

  String _deliveryLabel(Map<String, dynamic> item) {
    final scope = item['delivery_scope']?.toString();
    final payer = item['delivery_fee_payer']?.toString();
    return '${scope == 'within_state' ? 'داخل الولاية' : 'كل الولايات'} • ${payer == 'buyer' ? 'على حساب المشتري' : 'مجاناً'}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((item) {
      final text = '${item['title'] ?? ''} ${item['description'] ?? ''}'.toLowerCase();
      return text.contains(_query) && (_city == 'الكل' || item['city']?.toString() == _city);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('سوق الإكسسوارات'), actions: [
        IconButton(tooltip: 'نشر إكسسوار', onPressed: _add, icon: const Icon(Icons.add_circle_outline)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add, icon: const Icon(Icons.add), label: const Text('نشر إكسسوار')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: TextField(
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث في الإكسسوارات', border: OutlineInputBorder()),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: DropdownButtonFormField<String>(
          value: _city,
          decoration: const InputDecoration(labelText: 'المدينة', border: OutlineInputBorder()),
          items: ['الكل', ...CatalogData.cities].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (v) { if (v != null) setState(() => _city = v); },
        )),
        const SizedBox(height: 6),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : filtered.isEmpty ? const Center(child: Text('لا توجد إكسسوارات'))
          : ListView.builder(
            padding: const EdgeInsets.only(bottom: 90), itemCount: filtered.length,
            itemBuilder: (_, index) {
              final item = filtered[index];
              final rawImages = item['image_urls'];
              final images = rawImages is List ? rawImages : <dynamic>[];
              return Card(child: ListTile(
                leading: images.isNotEmpty ? Image.network(images.first.toString(), width: 60, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                  : const Icon(Icons.inventory_2_outlined, color: AppColors.gold),
                title: Text(item['title']?.toString().trim() ?? ''),
                subtitle: Text('${item['city'] ?? ''}\n${_deliveryLabel(item)}'),
                isThreeLine: true,
              ));
            },
          )),
      ]),
    );
  }
}
