enum DeviceCondition { newDevice, excellent, minorScratches, cracked }

extension DeviceConditionLabel on DeviceCondition {
  String get labelAr {
    switch (this) {
      case DeviceCondition.newDevice:
        return 'جديد';
      case DeviceCondition.excellent:
        return 'مستعمل بحالة ممتازة';
      case DeviceCondition.minorScratches:
        return 'خدوش بسيطة';
      case DeviceCondition.cracked:
        return 'كسور بالظهر أو الشاشة';
    }
  }
}

/// نوع الضمان
enum WarrantyType { none, storeWarranty, agentWarranty }

/// حالة الإعلان
enum ListingStatus { active, sold, frozen, expired, pendingReview }

class SellerInfo {
  final String id;
  final String name;
  final String phone;
  final String? whatsapp;
  final String? bio;
  final String? avatarUrl;
  final bool isVerifiedStore;
  final bool isShop; // تاجر/معرض
  final double rating; // 0-5
  final int completedSales;
  final String city;
  final String replySpeedLabel; // "يرد عادة خلال دقائق"

  const SellerInfo({
    required this.id,
    required this.name,
    required this.phone,
    this.whatsapp,
    this.bio,
    this.avatarUrl,
    this.isVerifiedStore = false,
    this.isShop = false,
    this.rating = 0,
    this.completedSales = 0,
    required this.city,
    this.replySpeedLabel = 'يرد عادة خلال ساعات',
  });
}

class PhoneListing {
  final String id;
  final String title; // مثال: Samsung A73 5G
  final String brand;
  final int price; // بالجنيه السوداني
  final bool priceIsNegotiable;
  final bool priceOnCall; // "على السوم / اتصل للسعر"
  final int? oldPrice; // لإظهار الخصم
  final String storage;
  final String ram;
  final int? batteryHealthPercent; // خاص بالآيفون فقط حسب طلب المستخدم
  final DeviceCondition condition;
  final String? damageNotes; // ملاحظات الأعطال (تظهر بالأحمر)
  final bool hasBox;
  final bool hasCharger;
  final bool hasInvoice;
  final bool hasEarphones;
  final WarrantyType warranty;
  final String city;
  final List<String> imageUrls;
  final SellerInfo seller;
  final ListingStatus status;
  final DateTime createdAt;
  final int viewCount;
  final bool isFeatured;
  final String description;

  const PhoneListing({
    required this.id,
    required this.title,
    required this.brand,
    required this.price,
    this.priceIsNegotiable = true,
    this.priceOnCall = false,
    this.oldPrice,
    required this.storage,
    required this.ram,
    this.batteryHealthPercent,
    this.condition = DeviceCondition.excellent,
    this.damageNotes,
    this.hasBox = true,
    this.hasCharger = true,
    this.hasInvoice = false,
    this.hasEarphones = false,
    this.warranty = WarrantyType.none,
    required this.city,
    required this.imageUrls,
    required this.seller,
    this.status = ListingStatus.active,
    required this.createdAt,
    this.viewCount = 0,
    this.isFeatured = false,
    this.description = '',
  });

  bool get isIphone => brand.toLowerCase().contains('iphone') || brand.toLowerCase().contains('apple');

  PhoneListing copyWith({
    int? price,
    int? oldPrice,
    bool? priceIsNegotiable,
    bool? priceOnCall,
    ListingStatus? status,
  }) {
    return PhoneListing(
      id: id,
      title: title,
      brand: brand,
      price: price ?? this.price,
      priceIsNegotiable: priceIsNegotiable ?? this.priceIsNegotiable,
      priceOnCall: priceOnCall ?? this.priceOnCall,
      oldPrice: oldPrice ?? this.oldPrice,
      storage: storage,
      ram: ram,
      batteryHealthPercent: batteryHealthPercent,
      condition: condition,
      damageNotes: damageNotes,
      hasBox: hasBox,
      hasCharger: hasCharger,
      hasInvoice: hasInvoice,
      hasEarphones: hasEarphones,
      warranty: warranty,
      city: city,
      imageUrls: imageUrls,
      seller: seller,
      status: status ?? this.status,
      createdAt: createdAt,
      viewCount: viewCount,
      isFeatured: isFeatured,
      description: description,
    );
  }
}

/// طلب شراء ينشره المشتري عندما لا يجد الهاتف المطلوب.
class PhoneRequest {
  final String id;
  final String? brand;
  final String? model;
  final String city;
  final int? maxPrice;
  final String notes;
  final DateTime createdAt;

  const PhoneRequest({
    required this.id,
    this.brand,
    this.model,
    required this.city,
    this.maxPrice,
    this.notes = '',
    required this.createdAt,
  });

  String get title {
    final parts = [brand, model].whereType<String>().where((item) => item.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'هاتف غير محدد' : parts.join(' ');
  }
}
