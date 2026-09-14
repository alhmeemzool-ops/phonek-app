import 'package:flutter/material.dart';
import 'badge_3d_viewer.dart';
import 'badge_model.dart';
import 'merchant_badge_art.dart';

class MerchantBadgeChip extends StatelessWidget {
  const MerchantBadgeChip({super.key, required this.level, this.compact = false});
  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = badgeForLevel(level);
    final artSize = compact ? 27.0 : 38.0;
    return Semantics(
      label: 'شارة المستوى ${badge.level}: ${badge.nameAr}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 9, vertical: compact ? 3 : 5),
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(compact ? 8 : 9999), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .55)), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [MerchantBadgeArt(level: badge.level, size: artSize), if (!compact) ...[const SizedBox(width: 6), Text(badge.nameAr, style: const TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w700, fontSize: 12))]],
        ),
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
        final current = badge.level == currentLevel;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showMerchantBadgeDetails(context, badge, current: current, unlocked: unlocked),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: current ? const Color(0xFFFFD700) : Colors.transparent, width: current ? 2 : 0)),
            child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [Expanded(child: Center(child: MerchantBadgeArt(level: badge.level, size: 104, locked: !unlocked))), Text('المستوى ${badge.level}', style: TextStyle(fontWeight: FontWeight.w800, color: current ? const Color(0xFFFFD700) : null)), const SizedBox(height: 3), Text(badge.nameAr, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(badge.descriptionAr, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11))])),
          ),
        );
      },
    );
  }
}

void showMerchantBadgeDetails(BuildContext context, MerchantBadge badge, {required bool current, bool unlocked = true}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(badge.nameAr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close, color: Colors.white))]),
      Text('المستوى ${badge.level}', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Center(child: MerchantBadgeArt(level: badge.level, size: 100, locked: !unlocked)),
      const SizedBox(height: 12),
      Text(badge.descriptionAr, style: const TextStyle(color: Colors.white70, height: 1.5)),
      const SizedBox(height: 14),
      Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12), border: Border.all(color: current ? const Color(0xFFFFD700) : Colors.white12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(current ? 'المستوى الحالي' : 'شروط الحصول على الشارة', style: const TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(height: 6), Text(badge.requiredSales == 0 ? 'تفعيل المتجر والتحقق من الهوية' : '${badge.requiredSales} عملية بيع ناجحة${badge.requiresLicense ? ' + توثيق رخصة المتجر' : ''}${badge.minRating != null ? ' + تقييم أعلى من ${badge.minRating!.toStringAsFixed(1)}' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(sheetContext); Navigator.of(context).push(MaterialPageRoute(builder: (_) => MerchantBadge3DViewer(badge: badge, unlocked: unlocked))); }, icon: const Icon(Icons.threed_rotation_rounded), label: const Text('عرض الشارة 360°'))),
    ]))),
  );
}
