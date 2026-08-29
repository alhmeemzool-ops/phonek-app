import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'phone_details_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUserId = appState.currentUser?.id;
    final listings = currentUserId == null
        ? appState.listings
        : appState.listings.where((listing) => listing.seller.id == currentUserId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي')),
      body: listings.isEmpty
          ? const _EmptyListings()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: listings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _listingTile(context, listings[index]),
            ),
    );
  }

  Widget _listingTile(BuildContext context, PhoneListing listing) {
    final statusLabel = switch (listing.status) {
      ListingStatus.active => 'نشط',
      ListingStatus.pendingReview => 'قيد المراجعة',
      ListingStatus.sold => 'تم البيع',
      ListingStatus.frozen => 'مجمّد',
      ListingStatus.expired => 'منتهي',
    };
    final statusColor = listing.status == ListingStatus.active ? AppColors.success : AppColors.textSecondary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 76,
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.phone_android_rounded, color: AppColors.gold, size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(listing.priceOnCall ? 'اتصل للسعر' : AppFormatters.priceSDG(listing.price),
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12)),
                ],
              ),
            ),
            PopupMenuButton<_ListingAction>(
              onSelected: (action) => _handleAction(context, listing, action),
              itemBuilder: (_) => [
                const PopupMenuItem(value: _ListingAction.editPrice, child: Text('تحديث السعر')),
                const PopupMenuItem(value: _ListingAction.markSold, child: Text('حذف بعد البيع')),
                const PopupMenuItem(value: _ListingAction.open, child: Text('عرض الإعلان')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, PhoneListing listing, _ListingAction action) async {
    switch (action) {
      case _ListingAction.open:
        Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: listing)));
        return;
      case _ListingAction.editPrice:
        await _showEditPriceDialog(context, listing);
        return;
      case _ListingAction.markSold:
        await _confirmDelete(context, listing);
        return;
    }
  }

  Future<void> _showEditPriceDialog(BuildContext context, PhoneListing listing) async {
    final controller = TextEditingController(text: listing.price.toString());
    final newPrice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تحديث السعر'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر الجديد (ج.س)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final price = int.tryParse(controller.text.replaceAll(',', '').trim());
              if (price == null || price < 10000) return;
              Navigator.pop(ctx, price);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || newPrice == null) return;
    try {
      await context.read<AppState>().updateListingPrice(listing.id, newPrice);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث السعر بنجاح')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديث السعر حالياً')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, PhoneListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف الإعلان'),
        content: Text('سيتم حذف إعلان «${listing.title}» نهائياً بعد تأكيد البيع. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    try {
      await context.read<AppState>().deleteListing(listing.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الإعلان نهائياً')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حذف الإعلان حالياً')));
      }
    }
  }
}

enum _ListingAction { editPrice, markSold, open }

class _EmptyListings extends StatelessWidget {
  const _EmptyListings();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('لا توجد إعلانات في حسابك حالياً', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
