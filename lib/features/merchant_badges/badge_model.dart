import 'package:flutter/foundation.dart';

@immutable
class MerchantBadge {
  final int level;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final int requiredSales;
  final double? minRating;
  final bool requiresIdentity;
  final bool requiresLicense;

  const MerchantBadge({
    required this.level,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.requiredSales,
    this.minRating,
    this.requiresIdentity = true,
    this.requiresLicense = false,
  });
}

const merchantBadges = <MerchantBadge>[
  MerchantBadge(
    level: 1,
    nameAr: 'بائع مبتدئ',
    nameEn: 'Novice',
    descriptionAr: 'بمجرد تفعيل الحساب بالهوية الشخصية، حتى مع 0 طلب.',
    requiredSales: 0,
  ),
  MerchantBadge(
    level: 2,
    nameAr: 'بائع ناشئ',
    nameEn: 'Emerging',
    descriptionAr: 'إكمال 15 طلباً ناجحاً.',
    requiredSales: 15,
  ),
  MerchantBadge(
    level: 3,
    nameAr: 'بائع صاعد',
    nameEn: 'Rising',
    descriptionAr: 'إكمال 40 طلباً ناجحاً.',
    requiredSales: 40,
  ),
  MerchantBadge(
    level: 4,
    nameAr: 'بائع موثوق',
    nameEn: 'Verified',
    descriptionAr: 'إكمال 80 طلباً ناجحاً + توثيق رخصة المحل الرسمية.',
    requiredSales: 80,
    requiresLicense: true,
  ),
  MerchantBadge(
    level: 5,
    nameAr: 'بائع متميز',
    nameEn: 'Star',
    descriptionAr: 'إكمال 150 طلباً ناجحاً + تقييم عام أعلى من 4.2 نجمة.',
    requiredSales: 150,
    minRating: 4.2,
  ),
  MerchantBadge(
    level: 6,
    nameAr: 'بائع محترف',
    nameEn: 'Pro',
    descriptionAr: 'إكمال 300 طلب ناجح.',
    requiredSales: 300,
  ),
  MerchantBadge(
    level: 7,
    nameAr: 'بائع خبير',
    nameEn: 'Expert',
    descriptionAr: 'إكمال 600 طلب ناجح.',
    requiredSales: 600,
  ),
  MerchantBadge(
    level: 8,
    nameAr: 'بائع نخبة',
    nameEn: 'Elite',
    descriptionAr: 'إكمال 1,200 طلب ناجح.',
    requiredSales: 1200,
  ),
  MerchantBadge(
    level: 9,
    nameAr: 'بائع معتمد',
    nameEn: 'Master',
    descriptionAr: 'إكمال 2,500 طلب ناجح.',
    requiredSales: 2500,
  ),
  MerchantBadge(
    level: 10,
    nameAr: 'تاجر أسطوري',
    nameEn: 'Legendary',
    descriptionAr: 'إكمال 5,000 طلب ناجح أو أكثر.',
    requiredSales: 5000,
  ),
];

MerchantBadge badgeForLevel(int level) => merchantBadges[(level.clamp(1, merchantBadges.length)) - 1];

/// Calculates the live eligible level. The database keeps the earned level
/// monotonic, so this function is only for local display/progress logic.
int levelForStatus({
  required int sales,
  required bool identityVerified,
  required bool licenseVerified,
  required double rating,
}) {
  if (!identityVerified) return 0;
  var level = 1;
  if (sales >= 15) level = 2;
  if (sales >= 40) level = 3;
  if (sales >= 80 && licenseVerified) level = 4;
  if (sales >= 150 && rating > 4.2) level = 5;
  if (sales >= 300) level = 6;
  if (sales >= 600) level = 7;
  if (sales >= 1200) level = 8;
  if (sales >= 2500) level = 9;
  if (sales >= 5000) level = 10;
  return level;
}

int levelForSales(int sales) => levelForStatus(
      sales: sales,
      identityVerified: true,
      licenseVerified: true,
      rating: 5,
    );
