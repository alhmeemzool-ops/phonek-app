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

  static final List<PhoneRequest> phoneRequests = [
    PhoneRequest(
      id: 'r1',
      brand: 'iPhone',
      model: 'iPhone 13 Pro',
      city: 'الخرطوم',
      maxPrice: 430000,
      notes: 'يفضل مع بطارية جيدة وكرتونة إن أمكن.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
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
    'الخرطوم', 'الجزيرة', 'البحر الأحمر', 'كسلا', 'القضارف', 'سنار', 'النيل الأبيض', 'النيل الأزرق',
    'الشمالية', 'نهر النيل', 'شندي', 'عطبرة', 'شمال كردفان', 'جنوب كردفان', 'غرب كردفان',
    'شمال دارفور', 'جنوب دارفور', 'غرب دارفور', 'وسط دارفور', 'شرق دارفور',
    'أم درمان', 'بحري', 'بورتسودان', 'مدني', 'الأبيض', 'نيالا', 'مدينة أخرى',
  ];

  static const List<String> brands = [
    'iPhone', 'Samsung', 'Tecno', 'Infinix', 'Xiaomi', 'Realme', 'Honor', 'Oppo',
  ];

  static const Map<String, List<String>> phoneModelsByBrand = {
    'iPhone': ['iPhone 11', 'iPhone 11 Pro', 'iPhone 11 Pro Max', 'iPhone 12', 'iPhone 12 mini', 'iPhone 12 Pro', 'iPhone 12 Pro Max', 'iPhone 13', 'iPhone 13 mini', 'iPhone 13 Pro', 'iPhone 13 Pro Max', 'iPhone 14', 'iPhone 14 Plus', 'iPhone 14 Pro', 'iPhone 14 Pro Max', 'iPhone 15', 'iPhone 15 Plus', 'iPhone 15 Pro', 'iPhone 15 Pro Max', 'iPhone 16', 'iPhone 16 Plus', 'iPhone 16 Pro', 'iPhone 16 Pro Max', 'iPhone 17', 'iPhone 17e', 'iPhone Air', 'iPhone 17 Pro', 'iPhone 17 Pro Max'],
    'Samsung': ['Galaxy A05', 'Galaxy A05s', 'Galaxy A15', 'Galaxy A16 5G', 'Galaxy A17 5G', 'Galaxy A24', 'Galaxy A25', 'Galaxy A26', 'Galaxy A27 5G', 'Galaxy A34', 'Galaxy A35', 'Galaxy A36 5G', 'Galaxy A37 5G', 'Galaxy A54', 'Galaxy A55', 'Galaxy A56', 'Galaxy A57 5G', 'Galaxy A73 5G', 'Galaxy S21', 'Galaxy S21 FE', 'Galaxy S22', 'Galaxy S22+', 'Galaxy S22 Ultra', 'Galaxy S23', 'Galaxy S23+', 'Galaxy S23 Ultra', 'Galaxy S24', 'Galaxy S24+', 'Galaxy S24 Ultra', 'Galaxy S25', 'Galaxy S25+', 'Galaxy S25 Ultra', 'Galaxy S25 Edge', 'Galaxy S25 FE', 'Galaxy S26', 'Galaxy S26+', 'Galaxy S26 Ultra', 'Galaxy Note 20', 'Galaxy Note 20 Ultra', 'Galaxy Z Flip4', 'Galaxy Z Flip5', 'Galaxy Z Flip6', 'Galaxy Z Flip7', 'Galaxy Z Flip8', 'Galaxy Z Fold4', 'Galaxy Z Fold5', 'Galaxy Z Fold6', 'Galaxy Z Fold7', 'Galaxy Z Fold8', 'Galaxy Z Fold8 Ultra'],
    'Tecno': ['Pop 5', 'Pop 6', 'Pop 7', 'Pop 8', 'Pop 9', 'Spark 8', 'Spark 9', 'Spark 10', 'Spark 20', 'Spark 20 Pro', 'Spark 30', 'Spark 40', 'Camon 18', 'Camon 19', 'Camon 20', 'Camon 20 Pro', 'Camon 30', 'Camon 30 Pro', 'Camon 40', 'Phantom X', 'Phantom X2', 'Phantom V Fold', 'Phantom V Flip'],
    'Infinix': ['Smart 6', 'Smart 7', 'Smart 8', 'Smart 9', 'Hot 10', 'Hot 11', 'Hot 12', 'Hot 20', 'Hot 30', 'Hot 40', 'Hot 50', 'Hot 60', 'Note 10', 'Note 11', 'Note 12', 'Note 30', 'Note 40', 'Note 50', 'Zero 20', 'Zero 30', 'Zero 40', 'GT 10 Pro', 'GT 20 Pro', 'GT 30 Pro'],
    'Xiaomi': ['Xiaomi 12', 'Xiaomi 12 Pro', 'Xiaomi 13', 'Xiaomi 13 Pro', 'Xiaomi 13T', 'Xiaomi 13T Pro', 'Xiaomi 14', 'Xiaomi 14 Pro', 'Xiaomi 14T', 'Xiaomi 14T Pro', 'Xiaomi 15', 'Xiaomi 15 Ultra', 'Redmi 10', 'Redmi 12', 'Redmi 13C', 'Redmi 14C', 'Redmi Note 10', 'Redmi Note 11', 'Redmi Note 12', 'Redmi Note 13', 'Redmi Note 14', 'Redmi Note 15', 'Redmi Note 13 Pro', 'Redmi Note 14 Pro', 'POCO C65', 'POCO C71', 'POCO C85', 'POCO M5', 'POCO M6', 'POCO M7', 'POCO M8 5G', 'POCO X5', 'POCO X6', 'POCO X7', 'POCO X8 Pro', 'POCO F5', 'POCO F6', 'POCO F7', 'POCO F8 Pro', 'POCO F8 Ultra'],
    'Realme': ['C21', 'C25', 'C30', 'C31', 'C33', 'C35', 'C51', 'C53', 'C55', 'C61', 'C63', 'C65', 'C67', 'C71', 'Narzo 50', 'Narzo 60', 'Narzo 70', '9 Pro', '10 Pro', '11 Pro', '12 Pro', '13 Pro', 'GT Neo 3', 'GT Neo 5', 'GT 5 Pro'],
    'Honor': ['HONOR 50', 'HONOR 50 Lite', 'HONOR 70', 'HONOR 70 Pro', 'HONOR 90', 'HONOR 90 Lite', 'HONOR 200', 'HONOR 200 Pro', 'HONOR 400', 'HONOR 400 Pro', 'HONOR 600', 'HONOR 600 Pro', 'HONOR Magic3', 'HONOR Magic5 Pro', 'HONOR Magic6 Pro', 'HONOR Magic7', 'HONOR Magic7 Pro', 'HONOR Magic8 Pro', 'HONOR Magic V2', 'HONOR Magic V3', 'HONOR Magic V5', 'HONOR Magic V6', 'HONOR X5b', 'HONOR X6b', 'HONOR X7b', 'HONOR X7c', 'HONOR X8b', 'HONOR X8c', 'HONOR X9b', 'HONOR X9c', 'HONOR X9d'],
    'Oppo': ['A16', 'A17', 'A18', 'A38', 'A58', 'A3 Pro', 'A78', 'A79', 'A98', 'F19', 'F21 Pro', 'F23', 'Reno 6', 'Reno 7', 'Reno 8', 'Reno 10', 'Reno 11', 'Reno 12', 'Reno 13', 'Reno 14', 'Find X3 Pro', 'Find X5 Pro', 'Find X6 Pro', 'Find X7 Ultra', 'Find N3', 'Find N5'],
  };
}
