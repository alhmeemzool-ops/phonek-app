import 'package:supabase_flutter/supabase_flutter.dart';

/// Provisions the configured PhoneK admin as a real store after authentication.
/// It is idempotent: existing listings are preserved and only enough demo
/// catalog entries are added to reach six when the store is empty/short.
class AdminStoreProvisioner {
  static const adminEmail = 'alhmeemzool@gmail.com';

  static Future<void> ensure() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.email?.toLowerCase() != adminEmail) return;

    await client.from('profiles').update({
      'is_shop': true,
      'is_verified_store': true,
      'name': 'متجر PhoneK الرسمي',
      'city': 'الخرطوم',
      'shop_address': 'الخرطوم — متجر PhoneK الرسمي',
      'shop_location_url': 'https://maps.google.com/?q=Khartoum,Sudan',
      'shop_hours': {
        'السبت': '09:00 - 21:00', 'الأحد': '09:00 - 21:00', 'الاثنين': '09:00 - 21:00',
        'الثلاثاء': '09:00 - 21:00', 'الأربعاء': '09:00 - 21:00', 'الخميس': '09:00 - 21:00', 'الجمعة': '16:00 - 21:00',
      },
      'payment_methods': ['نقداً', 'تحويل بنكي', 'دفع عند الاستلام'],
    }).eq('id', user.id);

    final rows = await client.from('listings').select('id').eq('seller_id', user.id);
    final count = (rows as List).length;
    if (count >= 6) return;

    final catalog = <Map<String, dynamic>>[
      {'title':'iPhone 15 Pro Max — 256GB','brand':'iPhone','price':620000,'storage':'256GB','ram':'8GB','condition':'excellent','warranty':'store_warranty','description':'جهاز نظيف مع كرتونة وفاتورة وضمان متجر PhoneK.','featured':true},
      {'title':'Samsung Galaxy S24 Ultra','brand':'Samsung','price':540000,'storage':'256GB','ram':'12GB','condition':'excellent','warranty':'store_warranty','description':'نسخة أصلية، حالة ممتازة، متوفرة مع كامل الملحقات.','featured':true},
      {'title':'Google Pixel 8 Pro','brand':'Google','price':390000,'storage':'128GB','ram':'12GB','condition':'excellent','warranty':'none','description':'هاتف رائد بكاميرا ممتازة وحالة نظيفة.','featured':false},
      {'title':'Xiaomi 14','brand':'Xiaomi','price':315000,'storage':'512GB','ram':'12GB','condition':'new','warranty':'agent_warranty','description':'جديد بالكرتونة وضمان وكيل رسمي.','featured':false},
      {'title':'Tecno Camon 30 Pro','brand':'Tecno','price':180000,'storage':'512GB','ram':'12GB','condition':'new','warranty':'agent_warranty','description':'جهاز جديد مع الضمان والملحقات.','featured':false},
      {'title':'Infinix Note 40 Pro','brand':'Infinix','price':155000,'storage':'256GB','ram':'8GB','condition':'excellent','warranty':'store_warranty','description':'حالة ممتازة وسعر قابل للتفاوض.','featured':false},
    ];
    for (var i = count; i < catalog.length; i++) {
      final item = catalog[i];
      await client.from('listings').insert({
        'seller_id': user.id,
        'title': item['title'], 'brand': item['brand'], 'price': item['price'],
        'price_is_negotiable': true, 'price_on_call': false,
        'storage': item['storage'], 'ram': item['ram'], 'condition': item['condition'],
        'has_box': true, 'has_charger': true, 'has_invoice': true, 'has_earphones': false,
        'warranty': item['warranty'], 'city': 'الخرطوم', 'image_urls': <String>[],
        'status': 'active', 'view_count': 10 + i * 7, 'is_featured': item['featured'],
        'description': item['description'],
      });
    }
  }
}
