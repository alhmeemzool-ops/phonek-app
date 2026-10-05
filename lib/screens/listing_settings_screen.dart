import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../utils/friendly_error.dart';
import '../widgets/listing_form.dart';

class ListingSettingsScreen extends StatelessWidget {
  const ListingSettingsScreen({super.key, required this.listing});
  final PhoneListing listing;

  Future<void> _save(BuildContext context, ListingFormData data) async {
    try {
      await context.read<AppState>().updateListing(
        id: listing.id,
        title: data.title,
        brand: data.brand,
        price: data.price,
        priceIsNegotiable: data.priceNegotiable,
        priceOnCall: data.priceOnCall,
        storage: data.storage,
        ram: data.ram,
        batteryHealthPercent: data.batteryHealth,
        condition: data.condition,
        damageNotes: data.hasDamage ? data.damageNotes : null,
        hasBox: data.hasBox,
        hasCharger: data.hasCharger,
        hasInvoice: data.hasInvoice,
        hasEarphones: data.hasEarphones,
        city: data.city,
        description: data.description,
        imageUrls: data.existingImageUrls,
        newImages: data.newImages,
        originalImageUrls: listing.imageUrls,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ تعديلات الإعلان')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      final message = friendlyError(error, fallback: 'تعذر حفظ تعديلات الإعلان. حاول مرة أخرى.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<AppState>().currentUser?.id == listing.seller.id;
    if (!owner) {
      return const Scaffold(body: Center(child: Text('هذه الصفحة متاحة لصاحب الإعلان فقط')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الإعلان')),
      body: ListingForm(
        initialListing: listing,
        submitLabel: 'حفظ التعديلات',
        onSubmit: (data) => _save(context, data),
      ),
    );
  }
}
