import 'package:flutter/foundation.dart';

@immutable
class MerchantBadge {
  final int level;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final int requiredSales;
  final int requiredDays;
  final double? minRating;
  final bool requiresIdentity;
  final bool requiresLicense;
  final String assetPath;

  const MerchantBadge({required this.level, required this.nameAr, required this.nameEn, required this.descriptionAr, required this.requiredSales, required this.requiredDays, this.minRating, this.requiresIdentity = true, this.requiresLicense = false, required this.assetPath});
}

const merchantBadges = <MerchantBadge>[
  MerchantBadge(level: 1, nameAr: 'بائع مبتدئ', nameEn: 'Novice', descriptionAr: 'تفعيل المتجر والتحقق من الهوية.', requiredSales: 0, requiredDays: 0, assetPath: 'assets/badges/badge_level_01.png'),
  MerchantBadge(level: 2, nameAr: 'بائع ناشئ', nameEn: 'Emerging', descriptionAr: '15 عملية بيع ناجحة + 7 أيام نشاط.', requiredSales: 15, requiredDays: 7, assetPath: 'assets/badges/badge_level_02.png'),
  MerchantBadge(level: 3, nameAr: 'بائع صاعد', nameEn: 'Rising', descriptionAr: '40 عملية بيع ناجحة + 30 يوماً.', requiredSales: 40, requiredDays: 30, assetPath: 'assets/badges/badge_level_03.png'),
  MerchantBadge(level: 4, nameAr: 'بائع موثوق', nameEn: 'Verified', descriptionAr: '80 عملية بيع ناجحة + 60 يوماً + توثيق المتجر.', requiredSales: 80, requiredDays: 60, requiresLicense: true, assetPath: 'assets/badges/badge_level_04.png'),
  MerchantBadge(level: 5, nameAr: 'بائع متميز', nameEn: 'Star', descriptionAr: '150 عملية بيع + 120 يوماً + تقييم أعلى من 4.2.', requiredSales: 150, requiredDays: 120, minRating: 4.2, assetPath: 'assets/badges/badge_level_05.png'),
  MerchantBadge(level: 6, nameAr: 'بائع محترف', nameEn: 'Pro', descriptionAr: '300 عملية بيع ناجحة + 180 يوماً.', requiredSales: 300, requiredDays: 180, assetPath: 'assets/badges/badge_level_06.png'),
  MerchantBadge(level: 7, nameAr: 'بائع خبير', nameEn: 'Expert', descriptionAr: '600 عملية بيع ناجحة + 270 يوماً.', requiredSales: 600, requiredDays: 270, assetPath: 'assets/badges/badge_level_07.png'),
  MerchantBadge(level: 8, nameAr: 'بائع نخبة', nameEn: 'Elite', descriptionAr: '1,200 عملية بيع ناجحة + سنة كاملة.', requiredSales: 1200, requiredDays: 365, assetPath: 'assets/badges/badge_level_08.png'),
  MerchantBadge(level: 9, nameAr: 'بائع معتمد', nameEn: 'Master', descriptionAr: '2,500 عملية بيع ناجحة + 18 شهراً.', requiredSales: 2500, requiredDays: 540, assetPath: 'assets/badges/badge_level_09.png'),
  MerchantBadge(level: 10, nameAr: 'تاجر أسطوري', nameEn: 'Legendary', descriptionAr: '5,000 عملية بيع ناجحة + سنتان.', requiredSales: 5000, requiredDays: 730, assetPath: 'assets/badges/badge_level_10.png'),
];

MerchantBadge badgeForLevel(int level) => merchantBadges[(level.clamp(1, merchantBadges.length)) - 1];

int levelForStatus({required int sales, required int activeDays, required bool identityVerified, required bool licenseVerified, required double rating}) {
  if (!identityVerified) return 0;
  var level = 1;
  for (final badge in merchantBadges.skip(1)) {
    if (sales >= badge.requiredSales && activeDays >= badge.requiredDays && (!badge.requiresLicense || licenseVerified) && (badge.minRating == null || rating > badge.minRating!)) level = badge.level;
  }
  return level;
}

int levelForSales(int sales) => levelForStatus(sales: sales, activeDays: 730, identityVerified: true, licenseVerified: true, rating: 5);
