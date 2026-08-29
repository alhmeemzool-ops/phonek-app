import '../models/phone_model.dart';
import '../models/chat_model.dart';

/// بيانات تجريبية محلية للمعاينة فقط.
/// ستُستبدل تدريجيًا بقراءة حقيقية من Supabase عند اكتمال طبقة البيانات.
class MockData {
  static const seller1 = SellerInfo(
    id: 's1',
    name: 'محل النور للهواتف',
    phone: '+249900000001',
    whatsapp: '+249900000001',
    bio: 'معرض هواتف موثوق - الخرطوم السوق العربي',
    isVerifiedStore: true,
    isShop: true,
    rating: 4.7,
    completedSales: 132,
    city: 'الخرطوم',
    replySpeedLabel: 'يرد عادة خلال دقائق',
  );

  static const seller2 = SellerInfo(
    id: 's2',
    name: 'أحمد محمد',
    phone: '+249900000002',
    whatsapp: '+249900000002',
    isVerifiedStore: false,
    isShop: false,
    rating: 0,
    completedSales: 3,
    city: 'شندي',
    replySpeedLabel: 'يرد خلال ساعات',
  );

  static final List<PhoneListing> listings = [
    PhoneListing(
      id: 'p1',
      title: 'Samsung Galaxy A73 5G',
      brand: 'Samsung',
      price: 280000,
      oldPrice: 310000,
      storage: '256GB',
      ram: '8GB',
      condition: DeviceCondition.excellent,
      hasBox: true,
      hasCharger: true,
      warranty: WarrantyType.storeWarranty,
      city: 'الخرطوم',
      imageUrls: const [],
      seller: seller1,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      viewCount: 214,
      isFeatured: true,
      description: 'هاتف بحالة ممتازة، استخدام شخصي نظيف، مع كامل الملحقات.',
    ),
    PhoneListing(
      id: 'p2',
      title: 'iPhone 13 Pro',
      brand: 'iPhone',
      price: 450000,
      storage: '128GB',
      ram: '6GB',
      batteryHealthPercent: 89,
      condition: DeviceCondition.minorScratches,
      hasBox: false,
      hasCharger: true,
      warranty: WarrantyType.none,
      city: 'بحري',
      imageUrls: const [],
      seller: seller2,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      viewCount: 98,
      description: 'آيفون 13 برو نظيف جداً، بطارية 89%، بدون كرتونة.',
    ),
    PhoneListing(
      id: 'p3',
      title: 'Tecno Camon 20',
      brand: 'Tecno',
      price: 95000,
      priceOnCall: true,
      storage: '128GB',
      ram: '8GB',
      condition: DeviceCondition.newDevice,
      hasBox: true,
      hasCharger: true,
      hasInvoice: true,
      warranty: WarrantyType.agentWarranty,
      city: 'مدني',
      imageUrls: const [],
      seller: seller1,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      viewCount: 40,
      description: 'جهاز جديد بالكرتون، ضمان وكيل رسمي.',
    ),
  ];

  static final List<ChatThread> chatThreads = [
    ChatThread(
      id: 'c1',
      phoneListingId: 'p1',
      phoneTitle: 'Samsung Galaxy A73 5G',
      otherUserName: 'محل النور للهواتف',
      otherUserOnline: true,
      messages: [
        ChatMessage(
          id: 'm1',
          senderId: 's1',
          text: 'مرحباً، أنا مهتم بهاتف Samsung A73 المعروض في تطبيق فونك',
          timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
          status: MessageStatus.read,
        ),
        ChatMessage(
          id: 'm2',
          senderId: 'me',
          text: 'أهلاً بيك، الهاتف متوفر والسعر قابل للتفاوض بسيط',
          timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
          status: MessageStatus.read,
        ),
      ],
    ),
  ];

  static const List<String> cities = [
    'الخرطوم', 'أم درمان', 'بحري', 'شندي', 'عطبرة', 'بورتسودان', 'مدني', 'كسلا', 'الأبيض', 'نيالا',
  ];

  static const List<String> brands = [
    'iPhone', 'Samsung', 'Tecno', 'Infinix', 'Xiaomi', 'Realme', 'Honor', 'Oppo',
  ];
}
