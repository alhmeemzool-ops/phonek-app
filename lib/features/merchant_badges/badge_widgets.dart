import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'badge_model.dart';
import 'merchant_badge_art.dart';
import 'badge_sound_service.dart';

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
          onTap: unlocked ? () => showMerchantBadgeDetails(context, badge, current: current) : null,
          child: Card(
            color: unlocked ? null : const Color(0xFF111827),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: current ? const Color(0xFFFFD700) : Colors.transparent, width: current ? 2 : 0)),
            child: Semantics(
              button: unlocked,
              enabled: unlocked,
              label: unlocked ? 'شارة ${badge.nameAr}، المستوى ${badge.level}' : 'شارة مقفلة، المستوى ${badge.level}',
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(child: MerchantBadgeArt(level: badge.level, size: 104, locked: !unlocked)),
                          if (!unlocked)
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(color: const Color(0xCC020617), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF475569))),
                              child: const Icon(Icons.lock_outline, color: Color(0xFFCBD5E1), size: 25),
                            ),
                        ],
                      ),
                    ),
                    Text('المستوى ${badge.level}', style: TextStyle(fontWeight: FontWeight.w800, color: unlocked ? (current ? const Color(0xFFFFD700) : null) : const Color(0xFF64748B))),
                    const SizedBox(height: 3),
                    Text(badge.nameAr, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: unlocked ? null : const Color(0xFF64748B))),
                    const SizedBox(height: 3),
                    Text(unlocked ? badge.descriptionAr : 'مقفلة — واصل التقدم لفتحها', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

void showMerchantBadgeDetails(BuildContext context, MerchantBadge badge, {required bool current}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _BadgeCelebrationDialog(badge: badge, current: current),
  );
}

class _BadgeCelebrationDialog extends StatefulWidget {
  const _BadgeCelebrationDialog({required this.badge, required this.current});
  final MerchantBadge badge;
  final bool current;

  @override
  State<_BadgeCelebrationDialog> createState() => _BadgeCelebrationDialogState();
}

class _BadgeCelebrationDialogState extends State<_BadgeCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    unawaited(_playBadgeSound());
  }

  Future<void> _playBadgeSound() async {
    try {
      await BadgeSoundService.instance.playForLevel(widget.badge.level);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Badge detail MP3 playback failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFD700);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: accent.withValues(alpha: .55), width: 1.5),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: .24), blurRadius: 32, spreadRadius: 3),
              const BoxShadow(color: Color(0x66000000), blurRadius: 22),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: accent, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.current ? '✨ شارتك المملوكة' : '✨ شارة مملوكة',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MerchantBadgeArt(level: widget.badge.level, size: 180),
              const SizedBox(height: 8),
              Text(widget.badge.nameAr, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('المستوى ${widget.badge.level}', style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                widget.current ? 'احتفظت بهذه الشارة بجدارة 🎉' : 'هذه الشارة مفتوحة في متجرك 🎉',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('ممتاز'))),
            ],
          ),
        ),
      ),
    );
  }
}
