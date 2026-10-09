import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';

/// شاشة الترحيب (Splash) الخاصة بتطبيق فونك.
///
/// تبدأ بنفس شكل شاشة الأندرويد الأصلية (خلفية داكنة + شنطة فونك في المنتصف)
/// فلا يشعر المستخدم بأي قفزة، ثم:
///   1. تظهر هالة ذهبية وحلقات نبض خفيفة حول الشعار
///   2. يرتفع الشعار قليلًا ويمرّ عليه لمعان
///   3. يظهر اسم PHONEK وخط ذهبي صغير تحت الشعار
///   4. يتلاشى كل شيء بنعومة إلى الصفحة الرئيسية
///
/// الصفحة الرئيسية تُبنى تحت الشاشة من البداية، فتكون القوائم جاهزة
/// تقريبًا لحظة الاختفاء.
class PhoneKSplashGate extends StatefulWidget {
  final Widget child;

  const PhoneKSplashGate({super.key, required this.child});

  /// تظهر مرة واحدة فقط في كل تشغيل للتطبيق.
  static bool _shownThisLaunch = false;

  @override
  State<PhoneKSplashGate> createState() => _PhoneKSplashGateState();
}

class _PhoneKSplashGateState extends State<PhoneKSplashGate>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF121212);
  static const _minDuration = Duration(milliseconds: 2600);
  static const _maxDataWait = Duration(seconds: 3);
  static const _fadeOut = Duration(milliseconds: 550);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );

  bool _leaving = false;
  bool _gone = PhoneKSplashGate._shownThisLaunch;
  AudioPlayer? _welcomePlayer;
  StreamSubscription<void>? _welcomeCompleteSubscription;

  @override
  void initState() {
    super.initState();
    if (_gone) return;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: _bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    final player = _welcomePlayer;
    if (player != null) {
      unawaited(_releaseWelcomePlayer(player));
    }
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (!mounted) return;
    PhoneKSplashGate._shownThisLaunch = true;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _intro.value = 1;
    } else {
      unawaited(_playWelcomeSound());
      _ambient.repeat();
      unawaited(_intro.forward());
      // نبضة خفيفة لحظة استقرار الشعار.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 650), () {
        HapticFeedback.lightImpact();
      }));
    }

    await Future<void>.delayed(
      reduceMotion ? const Duration(milliseconds: 700) : _minDuration,
    );
    if (!mounted) return;

    // انتظر تحميل الإعلانات (بحد أقصى ثواني) حتى لا تظهر الرئيسية فارغة.
    try {
      final app = context.read<AppState>();
      final deadline = DateTime.now().add(_maxDataWait);
      while (mounted &&
          app.isLoadingListings &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } catch (_) {
      // لا مشكلة: نكمل بدون انتظار.
    }
    if (!mounted) return;
    setState(() => _leaving = true);
  }

  Future<void> _playWelcomeSound() async {
    final player = AudioPlayer();
    _welcomePlayer = player;
    _welcomeCompleteSubscription = player.onPlayerComplete.listen((_) {
      unawaited(_releaseWelcomePlayer(player));
    });
    try {
      await player.play(AssetSource('audio/phonek_welcome.mp3'));
    } catch (error) {
      debugPrint('PhoneK welcome sound error: $error');
      await _releaseWelcomePlayer(player);
    }
  }

  Future<void> _releaseWelcomePlayer(AudioPlayer player) async {
    if (!identical(_welcomePlayer, player)) return;
    _welcomePlayer = null;
    final subscription = _welcomeCompleteSubscription;
    _welcomeCompleteSubscription = null;
    try {
      await subscription?.cancel();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  double _seg(double begin, double end, Curve curve) {
    final t = ((_intro.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: AbsorbPointer(
            child: AnimatedOpacity(
              opacity: _leaving ? 0 : 1,
              duration: _fadeOut,
              curve: Curves.easeInOut,
              onEnd: () {
                if (_leaving && mounted) {
                  _ambient.stop();
                  setState(() => _gone = true);
                }
              },
              child: AnimatedScale(
                scale: _leaving ? 1.05 : 1,
                duration: _fadeOut,
                curve: Curves.easeInCubic,
                child: _buildSplash(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplash(BuildContext context) {
    return Material(
      color: _bg,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _ambient]),
        builder: (context, _) {
          final glow = _seg(0.0, 0.6, Curves.easeOut);
          final lift = _seg(0.20, 0.62, Curves.easeInOutCubic);
          final shine = _seg(0.50, 0.85, Curves.easeInOut);
          final sub = _seg(0.50, 0.85, Curves.easeOutCubic);
          final line = _seg(0.60, 0.90, Curves.easeInOut);
          final ring1 = _seg(0.15, 0.75, Curves.easeOut);
          final ring2 = _seg(0.30, 0.90, Curves.easeOut);
          final breath = 0.5 + 0.5 * math.sin(_ambient.value * 2 * math.pi);

          final logoLift = -34.0 * lift;
          final logoScale = 1.0 - 0.10 * lift;
          final glowAlpha = 0.22 * glow * (0.85 + 0.15 * breath);

          return Stack(
            fit: StackFit.expand,
            children: [
              // هالة ذهبية ناعمة خلف الشعار
              Center(
                child: Transform.translate(
                  offset: Offset(0, logoLift),
                  child: Container(
                    width: 560,
                    height: 560,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: glowAlpha),
                          AppColors.gold.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // غبار ذهبي خفيف يطفو للأعلى
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DustPainter(t: _ambient.value, fade: glow),
                  ),
                ),
              ),

              // حلقتان تنبضان من الشعار
              Center(
                child: Transform.translate(
                  offset: Offset(0, logoLift),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _ring(ring1),
                      _ring(ring2),
                    ],
                  ),
                ),
              ),

              // الشعار
              Center(
                child: Transform.translate(
                  offset: Offset(0, logoLift),
                  child: Transform.scale(
                    scale: logoScale,
                    child: _logo(shine),
                  ),
                ),
              ),

              // اسم PHONEK + خط ذهبي صغير
              Center(
                child: Transform.translate(
                  offset: const Offset(0, 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: sub,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - sub)),
                          child: Padding(
                            // نعوّض مسافة الحروف الأخيرة ليبقى النص في المنتصف تمامًا
                            padding: EdgeInsets.only(left: 12 - 5 * sub),
                            child: Text(
                              'PHONEK',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 12 - 5 * sub,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: 44 * line,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            ],
          );
        },
      ),
    );
  }

  Widget _ring(double t) {
    final size = 130 + 280 * t;
    return Opacity(
      opacity: ((1 - t) * 0.45).clamp(0.0, 1.0),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 1.2),
        ),
      ),
    );
  }

  /// حجم الشعار عند البداية = نفس حجمه في شاشة أندرويد الأصلية (153dp ارتفاع)
  /// حتى يكون الانتقال بينهما غير ملحوظ.
  Widget _logo(double shine) {
    return SizedBox(
      height: 153,
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final p = -0.3 + 1.6 * shine;
          double s(double v) => v.clamp(0.0, 1.0);
          return LinearGradient(
            begin: const Alignment(-1, -0.7),
            end: const Alignment(1, 0.7),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.75),
              Colors.white.withValues(alpha: 0),
            ],
            stops: [s(p - 0.16), s(p), s(p + 0.16)],
          ).createShader(rect);
        },
        child: Image.asset(
          'assets/icon/phonek_logo_mark.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

}

class _Dust {
  final double x;
  final double phase;
  final double radius;
  const _Dust(this.x, this.phase, this.radius);
}

/// جزيئات ذهبية صغيرة تطفو ببطء. السرعة ثابتة (دورة كاملة لكل لفة) فلا تظهر قفزة.
class _DustPainter extends CustomPainter {
  final double t;
  final double fade;

  _DustPainter({required this.t, required this.fade});

  static final List<_Dust> _dust = List.generate(16, (i) {
    final r = math.Random(i * 7919 + 13);
    return _Dust(r.nextDouble(), r.nextDouble(), 1.2 + r.nextDouble() * 2.0);
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final d in _dust) {
      final p = (d.phase + t) % 1.0;
      final y = size.height * (1.05 - p * 1.1);
      final x = size.width * d.x + math.sin(p * 2 * math.pi + d.phase * 6) * 10;
      final alpha = math.sin(p * math.pi) * 0.38 * fade;
      paint.color = AppColors.gold.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), d.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) =>
      old.t != t || old.fade != fade;
}
