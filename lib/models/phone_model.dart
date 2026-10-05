/// حالة الجهاز الخارجية
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

extension ListingStatusValue on ListingStatus {
  /// نص مطابق لاسم القيمة، بدون الاعتماد على getter المدمج name
  /// (بعض بيئات التشغيل تفشل عند استدعائه على هذا التعداد تحديدًا).
  String get value {
    switch (this) {
      case ListingStatus.active:
        return 'active';
      case ListingStatus.sold:
        return 'sold';
      case ListingStatus.frozen:
        return 'frozen';
      case ListingStatus.expired:
        return 'expired';
      case ListingStatus.pendingReview:
        return 'pendingReview';
    }
  }
}

extension WarrantyTypeValue on WarrantyType {
  String get value {
    switch (this) {
      case WarrantyType.none:
        return 'none';
      case WarrantyType.storeWarranty:
        return 'storeWarranty';
      case WarrantyType.agentWarranty:
        return 'agentWarranty';
    }
  }
}

extension DeviceConditionValue on DeviceCondition {
  String get value {
    switch (this) {
      case DeviceCondition.newDevice:
        return 'newDevice';
      case DeviceCondition.excellent:
        return 'excellent';
      case DeviceCondition.minorScratches:
        return 'minorScratches';
      case DeviceCondition.cracked:
        return 'cracked';
    }
  }
}


class SellerInfo {
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'phone':'','whatsapp':whatsapp,'bio':bio,'avatar_url':avatarUrl,'is_verified_store':isVerifiedStore,'is_shop':isShop,'rating':rating,'completed_sales':completedSales,'city':city,'reply_speed_label':replySpeedLabel};
  factory SellerInfo.fromJson(Map<String,dynamic> j)=>SellerInfo(id:j['id']?.toString()??'',name:j['name']?.toString()??'',phone:'',whatsapp:j['whatsapp']?.toString(),bio:j['bio']?.toString(),avatarUrl:j['avatar_url']?.toString(),isVerifiedStore:j['is_verified_store']==true,isShop:j['is_shop']==true,rating:(j['rating'] as num?)?.toDouble()??0,completedSales:(j['completed_sales'] as num?)?.toInt()??0,city:j['city']?.toString()??'',replySpeedLabel:j['reply_speed_label']?.toString()??'يرد عادة خلال ساعات');
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
  final bool acceptsSwap;
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
    this.acceptsSwap = false,
    this.description = '',
  });

  Map<String,dynamic> toJson()=>{'id':id,'title':title,'brand':brand,'price':price,'price_is_negotiable':priceIsNegotiable,'price_on_call':priceOnCall,'old_price':oldPrice,'storage':storage,'ram':ram,'battery_health_percent':batteryHealthPercent,'condition':condition.value,'damage_notes':damageNotes,'has_box':hasBox,'has_charger':hasCharger,'has_invoice':hasInvoice,'has_earphones':hasEarphones,'warranty':warranty.value,'city':city,'image_urls':imageUrls,'seller':seller.toJson(),'status':status.value,'created_at':createdAt.toIso8601String(),'view_count':viewCount,'is_featured':isFeatured,'accepts_swap':acceptsSwap,'description':description};
  factory PhoneListing.fromJson(Map<String,dynamic> j)=>PhoneListing(id:j['id']?.toString()??'',title:j['title']?.toString()??'',brand:j['brand']?.toString()??'',price:(j['price'] as num?)?.toInt()??0,priceIsNegotiable:j['price_is_negotiable']!=false,priceOnCall:j['price_on_call']==true,oldPrice:(j['old_price'] as num?)?.toInt(),storage:j['storage']?.toString()??'',ram:j['ram']?.toString()??'',batteryHealthPercent:(j['battery_health_percent'] as num?)?.toInt(),condition:DeviceCondition.values.firstWhere((v)=>v.value==j['condition'],orElse:()=>DeviceCondition.excellent),damageNotes:j['damage_notes']?.toString(),hasBox:j['has_box']!=false,hasCharger:j['has_charger']!=false,hasInvoice:j['has_invoice']==true,hasEarphones:j['has_earphones']==true,warranty:WarrantyType.values.firstWhere((v)=>v.value==j['warranty'],orElse:()=>WarrantyType.none),city:j['city']?.toString()??'',imageUrls:(j['image_urls'] as List?)?.map((e)=>e.toString()).toList()??const [],seller:SellerInfo.fromJson(Map<String,dynamic>.from(j['seller'] as Map)),status:ListingStatus.values.firstWhere((v)=>v.value==j['status'],orElse:()=>ListingStatus.active),createdAt:DateTime.tryParse(j['created_at']?.toString()??'')??DateTime.now(),viewCount:(j['view_count'] as num?)?.toInt()??0,isFeatured:j['is_featured']==true,acceptsSwap:j['accepts_swap']==true,description:j['description']?.toString()??'');
  bool get isIphone => brand.toLowerCase().contains('iphone') || brand.toLowerCase().contains('apple');
}
