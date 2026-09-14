import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'badge_model.dart';
import 'merchant_badge_art.dart';

class MerchantBadge3DViewer extends StatefulWidget {
  const MerchantBadge3DViewer({super.key, required this.badge, this.unlocked = true});
  final MerchantBadge badge;
  final bool unlocked;

  @override
  State<MerchantBadge3DViewer> createState() => _MerchantBadge3DViewerState();
}

class _MerchantBadge3DViewerState extends State<MerchantBadge3DViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _rotationY = 0;
  double _rotationX = 0;
  double _dragStartY = 0;
  double _dragStartX = 0;

  Color get _accent {
    const accents = <Color>[
      Color(0xFF94A3B8),
      Color(0xFF60A5FA),
      Color(0xFF22D3EE),
      Color(0xFF34D399),
      Color(0xFFA3E635),
      Color(0xFFFACC15),
      Color(0xFFF59E0B),
      Color(0xFFFB7185),
      Color(0xFFC084FC),
      Color(0xFFF472B6),
    ];
    return accents[(widget.badge.level - 1).clamp(0, accents.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 3600 - widget.badge.level * 180))
      ..addListener(() {
        if (!mounted) return;
        setState(() => _rotationY = _controller.value * math.pi * 2);
      })
      ..repeat();
    SystemSound.play(SystemSoundType.click);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startDrag(DragStartDetails details) {
    _controller.stop();
    _dragStartY = _rotationY;
    _dragStartX = _rotationX;
  }

  void _drag(DragUpdateDetails details) {
    setState(() {
      _rotationY = _dragStartY + details.localPosition.dx * 0.012;
      _rotationX = (_dragStartX - details.localPosition.dy * 0.008).clamp(-0.55, 0.55);
    });
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    _accent.withValues(alpha: .20),
                    const Color(0xFF080B19),
                    const Color(0xFF02030A),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BadgeParticlesPainter(accent: _accent, level: badge.level)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  ),
                ),
                const Spacer(),
                Text('المستوى ${badge.level}', style: TextStyle(color: _accent, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(badge.nameAr, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 28),
                GestureDetector(
                  onHorizontalDragStart: _startDrag,
                  onVerticalDragStart: _startDrag,
                  onHorizontalDragUpdate: _drag,
                  onVerticalDragUpdate: _drag,
                  child: SizedBox(
                    width: 310,
                    height: 310,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: _accent.withValues(alpha: .30), blurRadius: 70, spreadRadius: 18),
                              BoxShadow(color: _accent.withValues(alpha: .16), blurRadius: 120, spreadRadius: 30),
                            ],
                          ),
                        ),
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateX(_rotationX)
                            ..rotateY(_rotationY),
                          child: MerchantBadgeArt(level: badge.level, size: 245, locked: !widget.unlocked),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(widget.unlocked ? 'اسحب الشارة لتدويرها 360°' : 'هذه الشارة ستفتح مع التقدم', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _accent.withValues(alpha: .28)),
                  ),
                  child: Text(badge.descriptionAr, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.5)),
                ),
                const Spacer(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeParticlesPainter extends CustomPainter {
  const _BadgeParticlesPainter({required this.accent, required this.level});
  final Color accent;
  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .32;
    final paint = Paint()..color = accent.withValues(alpha: .24);
    for (var i = 0; i < level + 6; i++) {
      final angle = i * math.pi * 2 / (level + 6);
      final r = radius + (i.isEven ? 25 : -8);
      final p = Offset(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);
      canvas.drawCircle(p, i.isEven ? 2.4 : 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeParticlesPainter oldDelegate) => oldDelegate.accent != accent || oldDelegate.level != level;
}
