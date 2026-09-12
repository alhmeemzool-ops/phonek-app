import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Native Flutter badge artwork so PhoneK does not depend on missing raster
/// assets. The painter creates a consistent 3D medal/shield language across
/// all ten levels while varying material and ornamentation by rank.
class MerchantBadgeArt extends StatelessWidget {
  const MerchantBadgeArt({super.key, required this.level, this.size = 96, this.locked = false});

  final int level;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final safeLevel = level.clamp(1, 10);
    return RepaintBoundary(
      child: Opacity(
        opacity: locked ? .34 : 1,
        child: CustomPaint(
          size: Size.square(size),
          painter: _MerchantBadgePainter(safeLevel),
        ),
      ),
    );
  }
}

class _MerchantBadgePainter extends CustomPainter {
  _MerchantBadgePainter(this.level);
  final int level;

  Color get base {
    const colors = [
      Color(0xFFB97843),
      Color(0xFFC8D0D8),
      Color(0xFFE3B341),
      Color(0xFF4EA6E8),
      Color(0xFF9A65E8),
      Color(0xFFE24E5B),
      Color(0xFF26B5A3),
      Color(0xFF4B86F0),
      Color(0xFF2E3440),
      Color(0xFFE8F1FF),
    ];
    return colors[level - 1];
  }

  Color get accent {
    const colors = [
      Color(0xFFF2B26A),
      Color(0xFFFFFFFF),
      Color(0xFFFFF0A1),
      Color(0xFFBDE5FF),
      Color(0xFFE0C7FF),
      Color(0xFFFFB0B7),
      Color(0xFF9EF4E8),
      Color(0xFFD8E5FF),
      Color(0xFFFFD76A),
      Color(0xFFFFFFFF),
    ];
    return colors[level - 1];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * .39;

    // Soft cast shadow creates the floating 3D presentation.
    canvas.drawCircle(
      c.translate(0, r * .16),
      r * 1.02,
      Paint()
        ..color = Colors.black.withValues(alpha: .30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Outer premium ring.
    final outer = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, base, Colors.black.withValues(alpha: .45)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * 1.02, outer);

    final inner = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.45),
        radius: 1,
        colors: [accent.withValues(alpha: .95), base, Color.lerp(base, Colors.black, .55)!],
        stops: const [.02, .55, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * .86, inner);

    // Bevel edge.
    canvas.drawCircle(
      c.translate(-r * .015, -r * .02),
      r * .75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .055
        ..color = Colors.white.withValues(alpha: .22),
    );

    // Laurel / star ornamentation increases subtly with rank.
    final ornaments = level <= 3 ? 4 : level <= 6 ? 6 : 8;
    for (var i = 0; i < ornaments; i++) {
      final a = -math.pi * .85 + i * (math.pi * 1.7 / math.max(1, ornaments - 1));
      final p = Offset(c.dx + math.cos(a) * r * .66, c.dy + math.sin(a) * r * .66);
      _drawDiamond(canvas, p, r * (level >= 8 ? .07 : .055), accent);
    }

    // Central shield with a metallic gradient.
    final shield = Path()
      ..moveTo(c.dx, c.dy - r * .49)
      ..lineTo(c.dx + r * .38, c.dy - r * .29)
      ..lineTo(c.dx + r * .30, c.dy + r * .18)
      ..quadraticBezierTo(c.dx, c.dy + r * .53, c.dx - r * .30, c.dy + r * .18)
      ..lineTo(c.dx - r * .38, c.dy - r * .29)
      ..close();
    canvas.drawPath(
      shield.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: .32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: .70), base, Colors.black.withValues(alpha: .55)],
        ).createShader(Rect.fromLTWH(c.dx - r, c.dy - r, 2 * r, 2 * r)),
    );

    // PhoneK P mark.
    final tp = TextPainter(
      text: TextSpan(
        text: 'P',
        style: TextStyle(
          color: Colors.white,
          fontSize: r * .63,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 2))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2 - r * .015));

    // Level 10 gets a faceted crown; levels 7-9 get a small premium crown.
    if (level >= 7) {
      final crown = Path()
        ..moveTo(c.dx - r * .22, c.dy - r * .60)
        ..lineTo(c.dx - r * .10, c.dy - r * .74)
        ..lineTo(c.dx, c.dy - r * .60)
        ..lineTo(c.dx + r * .10, c.dy - r * .74)
        ..lineTo(c.dx + r * .22, c.dy - r * .60)
        ..lineTo(c.dx + r * .16, c.dy - r * .49)
        ..lineTo(c.dx - r * .16, c.dy - r * .49)
        ..close();
      canvas.drawPath(crown, Paint()..shader = LinearGradient(colors: [accent, base, Colors.white]).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    // Specular highlight.
    canvas.drawArc(
      Rect.fromCircle(center: c.translate(-r * .06, -r * .08), radius: r * .73),
      math.pi * 1.08,
      math.pi * .72,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * .035
        ..color = Colors.white.withValues(alpha: level == 10 ? .82 : .42),
    );
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .8));
  }

  @override
  bool shouldRepaint(covariant _MerchantBadgePainter oldDelegate) => oldDelegate.level != level;
}
