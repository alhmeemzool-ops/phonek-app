import 'package:flutter/material.dart';
import 'badge_model.dart';
import 'merchant_badge_art.dart';

class MerchantBadgeChip extends StatelessWidget {
  const MerchantBadgeChip({super.key, required this.level, this.compact = false});
  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = badgeForLevel(level);
    final artSize = compact ? 30.0 : 38.0;
    return Semantics(
      label: 'شارة المستوى ${badge.level}: ${badge.nameAr}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 4 : 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .55)),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          MerchantBadgeArt(level: badge.level, size: artSize),
          const SizedBox(width: 6),
          Text(badge.nameAr, style: const TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
    );
  }
}

class MerchantBadgeGallery extends StatelessWidget {
  const MerchantBadgeGallery({super.key, required this.currentLevel});
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: merchantBadges.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .86),
      itemBuilder: (_, index) {
        final badge = merchantBadges[index];
        final unlocked = badge.level <= currentLevel;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Expanded(child: Center(child: MerchantBadgeArt(level: badge.level, size: 104, locked: !unlocked))),
              Text('المستوى ${badge.level}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(badge.nameAr, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(badge.descriptionAr, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ]),
          ),
        );
      },
    );
  }
}
