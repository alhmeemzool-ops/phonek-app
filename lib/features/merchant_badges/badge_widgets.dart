import 'package:flutter/material.dart';
import 'badge_model.dart';

class MerchantBadgeChip extends StatelessWidget {
  const MerchantBadgeChip({super.key, required this.level, this.compact = false});
  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = badgeForLevel(level);
    return Semantics(
      label: 'شارة المستوى ${badge.level}: ${badge.nameAr}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipOval(
            child: Image.asset(
              badge.assetPath,
              width: compact ? 22 : 28,
              height: compact ? 22 : 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium, color: Color(0xFFF59E0B), size: 24),
            ),
          ),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .9),
      itemBuilder: (_, index) {
        final badge = merchantBadges[index];
        final unlocked = badge.level <= currentLevel;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Expanded(child: Opacity(opacity: unlocked ? 1 : .38, child: Image.asset(badge.assetPath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium, size: 64, color: Color(0xFFF59E0B))))),
              Text('المستوى ${badge.level}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(badge.nameAr, textAlign: TextAlign.center),
              const SizedBox(height: 3),
              Text('${badge.requiredSales} مبيعات', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ]),
          ),
        );
      },
    );
  }
}
