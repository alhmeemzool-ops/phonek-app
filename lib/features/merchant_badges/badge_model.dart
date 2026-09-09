import 'package:flutter/foundation.dart';

@immutable
class MerchantBadge {
  final int level;
  final String nameAr;
  final String descriptionAr;
  final String assetPath;
  final int requiredSales;

  const MerchantBadge({required this.level, required this.nameAr, required this.descriptionAr, required this.assetPath, required this.requiredSales});
}

const merchantBadges = <MerchantBadge>[
  MerchantBadge(level: 1, nameAr: 'البداية الموثوقة', descriptionAr: 'أكمل أولى معاملاتك بنجاح.', assetPath: 'assets/badges/badge_level1.jpg', requiredSales: 1),
  MerchantBadge(level: 2, nameAr: 'البائع النشط', descriptionAr: 'حافظ على نشاط ثابت ومعاملات ناجحة.', assetPath: 'assets/badges/badge_level2.jpg', requiredSales: 10),
  MerchantBadge(level: 3, nameAr: 'الذهب', descriptionAr: 'سجل أداءً موثوقًا في البيع.', assetPath: 'assets/badges/badge_level3.jpg', requiredSales: 25),
  MerchantBadge(level: 4, nameAr: 'البلاتيني', descriptionAr: 'تقدم قوي في المبيعات وجودة الخدمة.', assetPath: 'assets/badges/badge_level4.jpg', requiredSales: 50),
  MerchantBadge(level: 5, nameAr: 'الزمرد', descriptionAr: 'استمرارية عالية وثقة متنامية.', assetPath: 'assets/badges/badge_level5.jpg', requiredSales: 100),
  MerchantBadge(level: 6, nameAr: 'الياقوت', descriptionAr: 'مستوى متقدم من الأداء التجاري.', assetPath: 'assets/badges/badge_level6.jpg', requiredSales: 200),
  MerchantBadge(level: 7, nameAr: 'الياقوت الأزرق', descriptionAr: 'أداء متميز ومستقر.', assetPath: 'assets/badges/badge_level7.jpg', requiredSales: 350),
  MerchantBadge(level: 8, nameAr: 'التاج', descriptionAr: 'مكانة بارزة بين المتاجر.', assetPath: 'assets/badges/badge_level8.jpg', requiredSales: 500),
  MerchantBadge(level: 9, nameAr: 'المجرة', descriptionAr: 'إنجاز استثنائي طويل المدى.', assetPath: 'assets/badges/badge_level9.jpg', requiredSales: 750),
  MerchantBadge(level: 10, nameAr: 'الإلهي', descriptionAr: 'أعلى مستوى إنجاز في النظام.', assetPath: 'assets/badges/badge_level10.jpg', requiredSales: 1000),
];

MerchantBadge badgeForLevel(int level) => merchantBadges[(level.clamp(1, 10)) - 1];

int levelForSales(int sales) {
  var level = 0;
  for (final badge in merchantBadges) {
    if (sales >= badge.requiredSales) level = badge.level;
  }
  return level;
}
