import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_card.dart';
import 'phone_details_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final userId = state.currentUser?.id;
    final listings = userId == null ? const <PhoneListing>[] : state.listings.where((listing) => listing.seller.id == userId).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي')),
      body: RefreshIndicator(
        onRefresh: state.loadListings,
        child: state.isLoadingListings && state.listings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.listingsError != null && state.listings.isEmpty
                ? _error(context, state)
                : listings.isEmpty
                    ? _empty()
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.62),
                        itemCount: listings.length,
                        itemBuilder: (context, index) {
                          final listing = listings[index];
                          return Column(children: [
                            Expanded(child: PhoneCard(listing: listing, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: listing))))),
                            Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _edit(context, listing), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('تعديل', style: TextStyle(fontSize: 11)))), const SizedBox(width: 4), Expanded(child: OutlinedButton.icon(onPressed: () => _delete(context, listing), icon: const Icon(Icons.delete_outline, size: 16), label: const Text('حذف', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)))]),
                          ]);
                        },
                      ),
      ),
    );
  }

  Widget _error(BuildContext context, AppState state) => ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 140), const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary), const SizedBox(height: 12), const Center(child: Text('تعذر تحميل إعلاناتك')), TextButton.icon(onPressed: state.loadListings, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))]);

  Widget _empty() => ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 160), Icon(Icons.inventory_2_outlined, size: 52, color: AppColors.textSecondary), SizedBox(height: 12), Center(child: Text('لا توجد لديك إعلانات نشطة حالياً')), SizedBox(height: 6), Center(child: Text('يمكنك نشر إعلان جديد من زر إضافة إعلان.', style: TextStyle(color: AppColors.textSecondary)))]);

  Future<void> _edit(BuildContext context, PhoneListing listing) async {
    final title = TextEditingController(text: listing.title);
    final price = TextEditingController(text: listing.price.toString());
    final city = TextEditingController(text: listing.city);
    final description = TextEditingController(text: listing.description);
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('تعديل الإعلان'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')), TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')), TextField(controller: city, decoration: const InputDecoration(labelText: 'الولاية / المدينة')), TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'الوصف'))])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ'))]));
    if (saved != true || !context.mounted) return;
    try {
      await context.read<AppState>().updateListing(id: listing.id, title: title.text, price: int.tryParse(price.text.replaceAll(',', '')) ?? listing.price, city: city.text, description: description.text);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الإعلان.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تعديل الإعلان: $error')));
    }
  }

  Future<void> _delete(BuildContext context, PhoneListing listing) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('حذف الإعلان؟'), content: const Text('سيختفي الإعلان من السوق، ويمكن للإدارة الاحتفاظ بسجله للمراجعة.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف'))]));
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<AppState>().deleteListing(listing.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الإعلان من السوق.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف الإعلان: $error')));
    }
  }
}
