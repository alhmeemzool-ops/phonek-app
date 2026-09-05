import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../theme/app_theme.dart';

/// In-app active liveness capture using the front camera and ML Kit.
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
  String _status = 'ضع وجهك داخل الإطار البيضاوي';
  String? _error;

  String get _instruction => switch (_phase) {
        _CapturePhase.center => 'انظر للأمام',
        _CapturePhase.right => 'ممتاز، اتجه بوجهك إلى اليمين',
        _CapturePhase.left => 'ممتاز، اتجه بوجهك إلى اليسار',
        _CapturePhase.complete => 'اكتمل التحقق',
      };

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      setState(() {
        _starting = false;
        _error = kIsWeb
            ? 'التحقق الحي متاح داخل تطبيق الهاتف فقط.'
            : 'كشف الوجه الحقيقي متاح على Android وiOS فقط.';
      });
      return;
    }
    try {
      final cameras = await availableCameras();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      if (front.isEmpty) throw CameraException('no_front_camera', 'لا توجد كاميرا أمامية على هذا الجهاز');

      final controller = CameraController(
        front.first,
        ResolutionPreset.medium,
        enableAudio: true,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
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
    } on CameraException catch (e) {
      if (mounted) setState(() { _starting = false; _error = e.description ?? 'تعذر تشغيل الكاميرا'; });
    } catch (e) {
      if (mounted) setState(() { _starting = false; _error = 'تعذر تهيئة كشف الوجه: $e'; });
    }
  }

  Future<void> _pickVideoFromBrowser() async {
    try {
      final file = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 20));
      if (file != null && mounted) Navigator.pop(context, file);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر فتح كاميرا المتصفح: $e');
    }
  }

  Future<void> _startCapture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _recording) return;
    try {
      setState(() {
        _recording = true;
        _phase = _CapturePhase.center;
        _progress = 0;
        _validPose = false;
        _status = 'ضع وجهك داخل الإطار البيضاوي';
      });
      await controller.startVideoRecording(onAvailable: _processCameraImage);
    } catch (_) {
      if (mounted) {
        setState(() {
          _recording = false;
          _error = 'تعذر بدء تسجيل فيديو إثبات الوجه';
        });
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processingFrame || !_recording || _faceDetector == null || _controller == null) return;
    _processingFrame = true;
    try {
      final quality = _checkImageQuality(image);
      final input = _toInputImage(image, _controller!.description);
      if (input == null) return;

      final faces = await _faceDetector!.processImage(input);
      String status;
      Face? face;
      if (quality != null) {
        face = faces.length == 1 ? faces.first : null;
        status = quality;
      } else if (faces.isEmpty) {
        status = 'لم يتم العثور على وجه';
      } else if (faces.length > 1) {
        status = 'يجب أن يكون هناك وجه واحد فقط';
      } else if (!_faceFitsGuide(faces.first, image.width, image.height)) {
        status = 'ضع وجهك داخل الإطار وبالحجم المناسب';
      } else if (!_isValidPose(faces.first)) {
        status = _phase == _CapturePhase.center
            ? 'انظر للأمام بثبات'
            : _phase == _CapturePhase.right
                ? 'اتجه بوجهك إلى اليمين'
                : 'اتجه بوجهك إلى اليسار';
      } else {
        face = faces.first;
        status = 'ممتاز، ثبّت وجهك';
      }

      final valid = face != null && _faceFitsGuide(face, image.width, image.height) && _isValidPose(face);
      if (!mounted) return;
      setState(() {
        _validPose = valid;
        _status = status;
        if (valid) {
          _progress = (_progress + 0.055).clamp(0.0, 1.0);
        } else {
          _progress = (_progress - 0.02).clamp(0.0, 1.0);
        }
      });
      if (_progress >= 1) await _advancePhase();
    } catch (_) {
      // A bad/dropped frame never advances the verification.
    } finally {
      _processingFrame = false;
    }
  }

  String? _checkImageQuality(CameraImage image) {
    if (image.planes.isEmpty) return 'تعذر قراءة جودة الصورة';
    final plane = image.planes.first;
    final bytes = plane.bytes;
    if (bytes.isEmpty) return 'تعذر قراءة جودة الصورة';

    // Android NV21: plane 0 is luminance. iOS BGRA: sample B,G,R bytes.
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    const samples = 420;
    final step = bytes.length ~/ samples < 1 ? 1 : bytes.length ~/ samples;
    double sum = 0;
    double sumSq = 0;
    double edge = 0;
    int count = 0;
    int previous = -1;

    for (int i = 0; i < bytes.length && count < samples; i += step) {
      final luminance = isBgra
          ? (0.114 * bytes[i] +
                  0.587 * bytes[(i + 1).clamp(0, bytes.length - 1)] +
                  0.299 * bytes[(i + 2).clamp(0, bytes.length - 1)])
              .round()
          : bytes[i];
      sum += luminance;
      sumSq += luminance * luminance;
      if (previous >= 0) edge += (luminance - previous).abs();
      previous = luminance;
      count++;
    }

    if (count == 0) return 'تعذر قراءة جودة الصورة';
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    final contrast = variance < 0 ? 0 : variance;
    final edgeAverage = edge / count;

    if (mean < 42) return 'الإضاءة ضعيفة';
    if (mean > 245) return 'الإضاءة قوية جداً';
    if (contrast < 90 || edgeAverage < 3.0) return 'الصورة غير واضحة، ثبّت الهاتف';
    return null;
  }

  bool _faceFitsGuide(Face face, int imageWidth, int imageHeight) {
    final box = face.boundingBox;
    final cx = (box.left + box.width / 2) / imageWidth;
    final cy = (box.top + box.height / 2) / imageHeight;
    final w = box.width / imageWidth;
    final h = box.height / imageHeight;

    // Ellipse approximating the on-screen face guide.
    final dx = (cx - 0.5) / 0.33;
    final dy = (cy - 0.5) / 0.45;
    final insideEllipse = dx * dx + dy * dy <= 1.0;
    final correctSize = w >= 0.22 && w <= 0.72 && h >= 0.25 && h <= 0.86;
    return insideEllipse && correctSize;
  }

  bool _isValidPose(Face face) {
    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    if (pitch.abs() > 22 || roll.abs() > 22) return false;
    return switch (_phase) {
      _CapturePhase.center => yaw.abs() <= 10,
      _CapturePhase.right => yaw >= 18,
      _CapturePhase.left => yaw <= -18,
      _CapturePhase.complete => false,
    };
  }

  Future<void> _advancePhase() async {
    if (_phase == _CapturePhase.center) {
      setState(() {
        _phase = _CapturePhase.right;
        _progress = 0;
        _validPose = false;
        _status = 'ممتاز، اتجه بوجهك إلى اليمين';
      });
    } else if (_phase == _CapturePhase.right) {
      setState(() {
        _phase = _CapturePhase.left;
        _progress = 0;
        _validPose = false;
        _status = 'ممتاز، اتجه بوجهك إلى اليسار';
      });
    } else if (_phase == _CapturePhase.left) {
      final controller = _controller;
      if (controller == null) return;
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _phase = _CapturePhase.complete;
        _progress = 1;
        _validPose = true;
        _status = 'اكتمل التحقق بنجاح';
      });
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
      appBar: AppBar(title: const Text('إثبات الشخصية'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: _starting
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? _ErrorBody(message: _error!, onAction: kIsWeb ? _pickVideoFromBrowser : null, actionLabel: kIsWeb ? 'تسجيل فيديو من الجهاز' : null)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (controller != null && controller.value.isInitialized) CameraPreview(controller),
                    Center(child: _FaceGuide(active: _validPose)),
                    SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 18),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 18),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .72), borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                Text(_instruction, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Text(_status, textAlign: TextAlign.center, style: TextStyle(color: _validPose ? Colors.greenAccent : Colors.white70, fontSize: 14)),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(value: _recording ? _progress : 0, minHeight: 8, backgroundColor: Colors.white24, color: _validPose ? Colors.greenAccent : Colors.white38),
                                const SizedBox(height: 7),
                                Text(_recording ? 'لن يتحرك الخط إلا عند تحقق الوجه + الإطار + الإضاءة + الوضوح + الحركة المطلوبة' : 'تحقق حي بالكاميرا الأمامية داخل التطبيق', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (!_recording && _phase != _CapturePhase.complete)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 28),
                              child: FilledButton.icon(
                                onPressed: _startCapture,
                                icon: const Icon(Icons.face_retouching_natural),
                                label: const Text('ابدأ التحقق'),
                                style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15)),
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
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        height: 315,
        child: CustomPaint(painter: _FaceGuidePainter(active: active)),
      );
}

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter({required this.active});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = active ? Colors.greenAccent : Colors.white70;
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawOval(rect, paint);
    paint
      ..color = (active ? Colors.greenAccent : Colors.white).withValues(alpha: .22)
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) => oldDelegate.active != active;
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, this.onAction, this.actionLabel});
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.videocam), label: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}
