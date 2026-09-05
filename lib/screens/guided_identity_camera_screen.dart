import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../theme/app_theme.dart';

/// Records identity video only after ML Kit detects the required face poses.
class GuidedIdentityCameraScreen extends StatefulWidget {
  const GuidedIdentityCameraScreen({super.key});

  @override
  State<GuidedIdentityCameraScreen> createState() => _GuidedIdentityCameraScreenState();
}

enum _CapturePhase { center, right, left, complete }

class _GuidedIdentityCameraScreenState extends State<GuidedIdentityCameraScreen> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  _CapturePhase _phase = _CapturePhase.center;
  double _progress = 0;
  bool _starting = true;
  bool _recording = false;
  bool _processingFrame = false;
  bool _validPose = false;
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
    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() {
        _starting = false;
        _error = 'كشف الوجه الحقيقي متاح على Android وiOS فقط.';
      });
      return;
    }
    try {
      final cameras = await availableCameras();
      final front = cameras.where((camera) => camera.lensDirection == CameraLensDirection.front).toList();
      if (front.isEmpty) throw CameraException('no_front_camera', 'لا توجد كاميرا أمامية على هذا الجهاز');
      final selected = front.first;
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: true,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableTracking: true,
          enableClassification: true,
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.15,
        ),
      );
      if (!mounted) {
        await controller.dispose();
        detector.close();
        return;
      }
      setState(() {
        _controller = controller;
        _faceDetector = detector;
        _starting = false;
      });
    } on CameraException catch (error) {
      if (mounted) setState(() { _starting = false; _error = error.description ?? 'تعذر تشغيل الكاميرا'; });
    } catch (error) {
      if (mounted) setState(() { _starting = false; _error = 'تعذر تهيئة كشف الوجه: $error'; });
    }
  }

  Future<void> _startCapture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _recording) return;
    try {
      await controller.startVideoRecording();
      setState(() {
        _recording = true;
        _phase = _CapturePhase.center;
        _progress = 0;
        _validPose = false;
      });
      await controller.startImageStream(_processCameraImage);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر بدء تسجيل فيديو إثبات الوجه');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processingFrame || !_recording || _faceDetector == null || _controller == null) return;
    _processingFrame = true;
    try {
      final input = _toInputImage(image, _controller!.description);
      if (input == null) return;
      final faces = await _faceDetector!.processImage(input);
      final face = faces.length == 1 ? faces.first : null;
      final valid = face != null && _isValidPose(face);
      if (!mounted) return;
      setState(() {
        _validPose = valid;
        if (valid) {
          _progress = (_progress + 0.045).clamp(0, 1);
        } else {
          _progress = (_progress - 0.01).clamp(0, 1);
        }
      });
      if (_progress >= 1) await _advancePhase();
    } catch (_) {
      // A dropped frame must not advance the verification step.
    } finally {
      _processingFrame = false;
    }
  }

  bool _isValidPose(Face face) {
    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    if (pitch.abs() > 25 || roll.abs() > 25) return false;
    return switch (_phase) {
      _CapturePhase.center => yaw.abs() <= 10,
      _CapturePhase.right => yaw >= 18,
      _CapturePhase.left => yaw <= -18,
      _CapturePhase.complete => false,
    };
  }

  Future<void> _advancePhase() async {
    if (_phase == _CapturePhase.center) {
      setState(() { _phase = _CapturePhase.right; _progress = 0; _validPose = false; });
    } else if (_phase == _CapturePhase.right) {
      setState(() { _phase = _CapturePhase.left; _progress = 0; _validPose = false; });
    } else if (_phase == _CapturePhase.left) {
      final controller = _controller;
      if (controller == null) return;
      await controller.stopImageStream();
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() { _recording = false; _phase = _CapturePhase.complete; _progress = 1; _validPose = true; });
      Navigator.pop(context, file);
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
    final rotation = InputImageRotationValue.fromRawValue(description.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.isEmpty) return null;
    final bytes = BytesBuilder();
    for (final plane in image.planes) {
      bytes.add(plane.bytes);
    }
    return InputImage.fromBytes(
      bytes: bytes.takeBytes(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('فيديو إثبات الشخصية'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: _starting
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? _ErrorBody(message: _error!)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (controller != null && controller.value.isInitialized) CameraPreview(controller),
                    Center(child: _FaceGuide(active: _validPose)),
                    SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .68), borderRadius: BorderRadius.circular(14)),
                            child: Column(
                              children: [
                                Text(_instruction, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(value: _recording ? _progress : 0, minHeight: 7, backgroundColor: Colors.white24, color: _validPose ? Colors.greenAccent : Colors.orangeAccent),
                                const SizedBox(height: 6),
                                Text(_recording ? (_validPose ? 'تم التعرف على الوضع الصحيح' : 'يجب إبقاء الوجه في الوضع المطلوب') : 'لن يتقدم الشريط إلا بعد التعرف على الوجه والوضع الصحيح', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (!_recording && _phase != _CapturePhase.complete)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 28),
                              child: FilledButton.icon(onPressed: _startCapture, icon: const Icon(Icons.videocam), label: const Text('ابدأ التحقق بالكاميرا'), style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14))),
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
  Widget build(BuildContext context) => Container(width: 230, height: 315, decoration: BoxDecoration(border: Border.all(color: active ? Colors.greenAccent : Colors.white70, width: 4), borderRadius: BorderRadius.circular(120), boxShadow: [BoxShadow(color: (active ? Colors.greenAccent : Colors.white).withValues(alpha: .22), blurRadius: 18, spreadRadius: 4)]));
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16))));
}
