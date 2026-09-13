import 'package:flutter/material.dart';
import 'badge_model.dart';

/// Uses the supplied PhoneK badge PNG as the source of truth.
/// A tiny fallback keeps older builds functional if an asset is missing.
class MerchantBadgeArt extends StatelessWidget {
  const MerchantBadgeArt({super.key, required this.level, this.size = 96, this.locked = false});
  final int level;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final badge = badgeForLevel(level);
    return RepaintBoundary(
      child: Semantics(
        label: 'شارة ${badge.nameAr}، المستوى ${badge.level}',
        image: true,
        child: Opacity(
          opacity: locked ? .28 : 1,
          child: Image.asset(
            badge.assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => _FallbackBadge(level: badge.level, size: size),
          ),
        ),
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({required this.level, required this.size});
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD76A), Color(0xFF6B3F0E)]),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 5))],
          border: Border.all(color: const Color(0xFFFFE8A3), width: 2),
        ),
        alignment: Alignment.center,
        child: Text('$level', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
      );
}
