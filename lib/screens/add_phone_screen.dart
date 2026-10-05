import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../widgets/listing_form.dart';

class AddPhoneScreen extends StatelessWidget {
  const AddPhoneScreen({super.key});

  Future<void> _submit(BuildContext context, ListingFormData data) async {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) throw const AuthException('سجّل الدخول أولاً حتى تتمكن من نشر إعلان');

    final client = Supabase.instance.client;
    final uploadedPaths = <String>[];
    final imageUrls = <String>[];
    try {
      for (var index = 0; index < data.newImages.length; index++) {
        final image = data.newImages[index];
        final path = user.id + '/' + DateTime.now().microsecondsSinceEpoch.toString() + '_' + index.toString() + '.' + _extensionFor(image.name);
        await client.storage.from('listing-images').uploadBinary(
          path,
          await image.readAsBytes(),
          fileOptions: FileOptions(contentType: _contentTypeFor(image.name), upsert: false),
        );
        uploadedPaths.add(path);
        imageUrls.add(client.storage.from('listing-images').getPublicUrl(path));
      }
      imageUrls.insertAll(0, data.existingImageUrls);
      await client.from('listings').insert({
        'seller_id': user.id,
        'title': data.title,
        'brand': data.brand,
        'price': data.price,
        'price_is_negotiable': data.priceNegotiable,
        'price_on_call': data.priceOnCall,
        'storage': data.storage,
        'ram': data.ram,
        'battery_health_percent': data.batteryHealth,
        'condition': data.condition.value,
        'damage_notes': data.hasDamage ? data.damageNotes : null,
        'has_box': data.hasBox,
        'has_charger': data.hasCharger,
        'has_invoice': data.hasInvoice,
        'has_earphones': data.hasEarphones,
        'warranty': WarrantyType.none.value,
        'city': data.city,
        'image_urls': imageUrls,
        'status': ListingStatus.pendingReview.value,
        'description': data.description,
      });
      await appState.loadListings();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الإعلان للمراجعة قبل النشر')));
      Navigator.of(context).pop();
    } catch (_) {
      if (uploadedPaths.isNotEmpty) await client.storage.from('listing-images').remove(uploadedPaths);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة هاتف')),
      body: ListingForm(
        submitLabel: 'نشر الإعلان',
        onSubmit: (data) => _submit(context, data),
        onSaveDraft: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حفظ المسودة سيُفعّل مع نظام الإعلانات القادم')),
        ),
      ),
    );
  }

  static String _extensionFor(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? 'jpg' : name.substring(dot + 1).toLowerCase();
  }

  static String _contentTypeFor(String name) {
    switch (_extensionFor(name)) {
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      default: return 'image/jpeg';
    }
  }
}
