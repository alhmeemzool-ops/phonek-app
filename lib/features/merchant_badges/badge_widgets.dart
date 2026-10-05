import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _BadgeCelebrationDialog(badge: badge, current: current, unlocked: unlocked),
  );
}

class _BadgeCelebrationDialog extends StatefulWidget {
  const _BadgeCelebrationDialog({required this.badge, required this.current, required this.unlocked});
  final MerchantBadge badge;
  final bool current;
  final bool unlocked;

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
    if (widget.unlocked) {
      unawaited(BadgeSoundService.playForLevel(widget.badge.level).catchError((error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Badge detail MP3 playback failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.unlocked ? const Color(0xFFFFD700) : const Color(0xFF64748B);
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
                  Icon(widget.unlocked ? Icons.auto_awesome : Icons.lock_outline, color: accent, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.current ? '✨ شارتك المملوكة' : widget.unlocked ? '✨ شارة مملوكة' : 'شارة قادمة',
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
              MerchantBadge3DViewer(level: widget.badge.level, size: 180),
              const SizedBox(height: 8),
              Text(
                widget.badge.nameAr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                'المستوى ${widget.badge.level}',
                style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                widget.current
                    ? 'احتفظت بهذه الشارة بجدارة 🎉'
                    : widget.unlocked
                        ? 'هذه الشارة مفتوحة في متجرك 🎉'
                        : 'واصل التقدم لفتحها',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ممتاز'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
