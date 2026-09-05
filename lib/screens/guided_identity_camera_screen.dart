import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Captures an identity video in-app with explicit face-position guidance.
class GuidedIdentityCameraScreen extends StatefulWidget {
  const GuidedIdentityCameraScreen({super.key});

  @override
  State<GuidedIdentityCameraScreen> createState() => _GuidedIdentityCameraScreenState();
}

enum _CapturePhase { center, right, left, complete }

class _GuidedIdentityCameraScreenState extends State<GuidedIdentityCameraScreen> {
  CameraController? _controller;
  Timer? _timer;
  _CapturePhase _phase = _CapturePhase.center;
  double _progress = 0;
  bool _starting = true;
  bool _recording = false;
  String? _error;

  String get _instruction => switch (_phase) {
        _CapturePhase.center => 'ضع وجهك داخل الإطار البيضاوي',
        _CapturePhase.right => 'اتجه بوجهك إلى اليمين',
        _CapturePhase.left => 'اتجه بوجهك إلى اليسار',
        _CapturePhase.complete => 'اكتمل فيديو إثبات الوجه',
      };

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.where((camera) => camera.lensDirection == CameraLensDirection.front).toList();
      if (front.isEmpty) throw CameraException('no_front_camera', 'لا توجد كاميرا أمامية على هذا الجهاز');
      final controller = CameraController(front.first, ResolutionPreset.medium, enableAudio: true);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _starting = false;
      });
    } on CameraException catch (error) {
      if (mounted) setState(() { _starting = false; _error = error.description ?? 'تعذر تشغيل الكاميرا'; });
    } catch (_) {
      if (mounted) setState(() { _starting = false; _error = 'تعذر تشغيل الكاميرا'; });
    }
  }

  Future<void> _startCapture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _recording) return;
    try {
      await controller.startVideoRecording();
      setState(() { _recording = true; _phase = _CapturePhase.center; _progress = 0; });
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        if (!mounted) return;
        setState(() => _progress = (_progress + 0.01).clamp(0, 1));
        if (_progress >= 1) await _advancePhase();
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر بدء تسجيل الفيديو');
    }
  }

  Future<void> _advancePhase() async {
    _timer?.cancel();
    if (_phase == _CapturePhase.center) {
      setState(() { _phase = _CapturePhase.right; _progress = 0; });
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    } else if (_phase == _CapturePhase.right) {
      setState(() { _phase = _CapturePhase.left; _progress = 0; });
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    } else if (_phase == _CapturePhase.left) {
      final controller = _controller;
      final file = controller == null ? null : await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() { _recording = false; _phase = _CapturePhase.complete; _progress = 1; });
      if (file != null) Navigator.pop(context, file);
    }
  }

  Future<void> _tick() async {
    if (!mounted) return;
    setState(() => _progress = (_progress + 0.01).clamp(0, 1));
    if (_progress >= 1) await _advancePhase();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('فيديو إثبات الشخصية'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? _ErrorBody(message: _error!)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (controller != null && controller.value.isInitialized) CameraPreview(controller),
                    Center(child: _FaceGuide(active: _recording)),
                    SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .62), borderRadius: BorderRadius.circular(14)),
                            child: Column(
                              children: [
                                Text(_instruction, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(value: _recording ? _progress : 0, minHeight: 7, backgroundColor: Colors.white24, color: Colors.greenAccent),
                                const SizedBox(height: 6),
                                Text(_recording ? 'جودة الصورة: ${((_progress * 100).round()).clamp(0, 100)}%' : 'سيتم التسجيل تلقائيًا عبر المراحل الثلاث', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (!_recording && _phase != _CapturePhase.complete)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 28),
                              child: FilledButton.icon(
                                onPressed: _startCapture,
                                icon: const Icon(Icons.videocam),
                                label: const Text('ابدأ التحقق بالكاميرا'),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _FaceGuide extends StatelessWidget {
  const _FaceGuide({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 315,
      decoration: BoxDecoration(
        border: Border.all(color: active ? Colors.greenAccent : Colors.white70, width: 4),
        borderRadius: BorderRadius.circular(120),
        color: Colors.transparent,
        boxShadow: [BoxShadow(color: (active ? Colors.greenAccent : Colors.white).withValues(alpha: .22), blurRadius: 18, spreadRadius: 4)],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16))));
}
