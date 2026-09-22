import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'badge_model.dart';
import 'badge_widgets.dart';
import 'merchant_badge_art.dart';

class MerchantLevelUpGate extends StatefulWidget {
  const MerchantLevelUpGate({super.key, required this.child});
  final Widget child;
  @override State<MerchantLevelUpGate> createState() => _MerchantLevelUpGateState();
}

class _MerchantLevelUpGateState extends State<MerchantLevelUpGate> with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<AuthState>? _auth;
  bool _checking = false, _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) => unawaited(_checkLevel(initial: true)));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_checkLevel(initial: true)));
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => unawaited(_checkLevel()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkLevel());
  }

  Future<void> _checkLevel({bool initial = false}) async {
    if (_checking || _showing || !mounted) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _checking = true;
    try {
      final row = await Supabase.instance.client
          .from('merchant_badge_state')
          .select('current_level')
          .eq('profile_id', userId)
          .maybeSingle();
      final current = (row?['current_level'] as num?)?.toInt() ?? 0;
      if (current <= 0) return;

      final prefs = await SharedPreferences.getInstance();
      final key = 'phonek_level_up_seen_$userId';
      final seen = prefs.getInt(key);

      // First installation: remember the current level without replaying old achievements.
      if (seen == null) {
        await prefs.setInt(key, current);
        return;
      }
      if (current < seen) {
        await prefs.setInt(key, current);
        return;
      }
      if (current > seen) {
        await prefs.setInt(key, current);
        if (!mounted) return;
        _showing = true;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => LevelUpCelebration(level: current, previousLevel: seen),
        );
        _showing = false;
      }
    } catch (_) {
      // Celebration is non-critical and must never block the app.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class LevelUpCelebration extends StatefulWidget {
  const LevelUpCelebration({super.key, required this.level, required this.previousLevel});
  final int level, previousLevel;
  @override State<LevelUpCelebration> createState() => _LevelUpCelebrationState();
}

class _LevelUpCelebrationState extends State<LevelUpCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final math.Random _random;
  late final List<_ConfettiParticle> _particles;
  late final List<_Firework> _fireworks;

  int get _tier => widget.level >= 10 ? 4 : widget.level >= 7 ? 3 : widget.level >= 4 ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _random = math.Random(widget.level * 7919);
    final count = [0, 45, 75, 105, 145][_tier];
    _particles = List.generate(count, (_) => _ConfettiParticle(_random));
    final fireworks = [0, 0, 3, 5, 8][_tier];
    _fireworks = List.generate(fireworks, (_) => _Firework(_random));
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _tier == 1 ? 3000 : 4200),
    )..forward();
    SystemSound.play(SystemSoundType.alert);
    unawaited(_playNativeSfx());
  }

  Future<void> _playNativeSfx() async {
    try {
      await const MethodChannel('phonek/level_up').invokeMethod<void>(
        'playLevelUpSound',
        {'level': widget.level},
      );
    } catch (_) {}
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final badge = badgeForLevel(widget.level);
    final width = MediaQuery.sizeOf(context).width;
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF070B16),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => CustomPaint(
                  painter: _CelebrationPainter(progress: _controller.value, particles: _particles, fireworks: _fireworks, tier: _tier),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 48, color: Color(0xFFFFD54F)),
                    const SizedBox(height: 10),
                    const Text('🎉 مبروك! لقد ارتقيت', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    Text('المستوى ${widget.previousLevel}  ←  ${widget.level}', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 22),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) => Transform.scale(scale: .78 + (_controller.value.clamp(0.0, 1.0) * .22), child: child),
                      child: MerchantBadgeArt(level: widget.level, size: width * .52),
                    ),
                    const SizedBox(height: 18),
                    Text(badge.nameAr, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    Text('المستوى ${widget.level}', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(badge.descriptionAr, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .12))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.workspace_premium, color: Color(0xFFFFD54F)),
                        SizedBox(width: 8),
                        Flexible(child: Text('إنجاز جديد تمت إضافته إلى سجل متجرك', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                      ]),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('متابعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle(math.Random r)
      : x = r.nextDouble(), y = -r.nextDouble() * .45, speed = .28 + r.nextDouble() * .62,
        size = 4 + r.nextDouble() * 7, rotation = r.nextDouble() * math.pi,
        rotationSpeed = -3 + r.nextDouble() * 6, shape = r.nextInt(3), phase = r.nextDouble();
  final double x, y, speed, size, rotation, rotationSpeed, phase;
  final int shape;
}

class _Firework {
  _Firework(math.Random r) : x = .15 + r.nextDouble() * .7, y = .12 + r.nextDouble() * .38, radius = 70 + r.nextDouble() * 100, phase = r.nextDouble();
  final double x, y, radius, phase;
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({required this.progress, required this.particles, required this.fireworks, required this.tier});
  final double progress;
  final List<_ConfettiParticle> particles;
  final List<_Firework> fireworks;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = <Color>[const Color(0xFFFFD54F), const Color(0xFF60A5FA), const Color(0xFFF472B6), const Color(0xFF34D399), const Color(0xFFA78BFA)];
    for (final p in particles) {
      final y = (p.y + progress * (1.25 + p.speed)) * size.height;
      if (y < -20 || y > size.height + 20) continue;
      final x = (p.x + math.sin(progress * 5 + p.phase) * .035) * size.width;
      final paint = Paint()..color = colors[(p.shape + (p.phase * 10).floor()) % colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * p.rotationSpeed);
      final rect = Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size);
      if (p.shape == 0) canvas.drawRect(rect, paint);
      else if (p.shape == 1) canvas.drawCircle(Offset.zero, p.size * .55, paint);
      else {
        final path = Path()..moveTo(0, -p.size)..lineTo(p.size, p.size)..lineTo(-p.size, p.size)..close();
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }

    if (tier >= 2) {
      for (final f in fireworks) {
        final local = ((progress + f.phase) % 1.0);
        final alpha = (1.0 - local).clamp(0.0, 1.0);
        final radius = f.radius * local;
        final paint = Paint()
          ..color = colors[(f.phase * colors.length).floor() % colors.length].withValues(alpha: alpha * .75)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        final center = Offset(f.x * size.width, f.y * size.height);
        canvas.drawCircle(center, radius, paint);
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi * 2 / 12;
          canvas.drawLine(
            Offset(center.dx + math.cos(a) * radius * .35, center.dy + math.sin(a) * radius * .35),
            Offset(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) => oldDelegate.progress != progress;
}
