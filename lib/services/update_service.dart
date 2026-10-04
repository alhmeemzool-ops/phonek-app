import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:binary_patch/binary_patch.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const String phoneKUpdateManifestUrl =
    'https://raw.githubusercontent.com/alhmeemzool-ops/phonek-app/main/update.json';
const String _releaseAssetPrefix =
    'https://github.com/alhmeemzool-ops/phonek-app/releases/download/';

class PhoneKUpdate {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String sha256;
  final bool mandatory;
  final String notes;
  final int? minSupportedVersionCode;
  final String? patchUrl;
  final String? patchSha256;
  final int? patchBaseVersionCode;

  const PhoneKUpdate({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.mandatory,
    required this.notes,
    this.minSupportedVersionCode,
    this.patchUrl,
    this.patchSha256,
    this.patchBaseVersionCode,
  });

  factory PhoneKUpdate.fromJson(
    Map<String, dynamic> json, {
    int currentBuildNumber = 0,
  }) {
    final patchUrl = json['patchUrl'] as String?;
    final minSupported = json['minSupportedVersionCode'];
    final minSupportedVersionCode =
        minSupported == null ? null : (minSupported as num).toInt();
    final patchSha256 = json['patchSha256'] as String?;
    final patchBase = json['patchBaseVersionCode'];
    return PhoneKUpdate(
      versionCode: (json['versionCode'] as num).toInt(),
      versionName: json['versionName'] as String,
      apkUrl: json['apkUrl'] as String,
      sha256: (json['sha256'] as String).toLowerCase(),
      mandatory: json['mandatory'] == true ||
          (minSupportedVersionCode != null &&
              minSupportedVersionCode > currentBuildNumber),
      notes: (json['notes'] as String?) ?? '',
      minSupportedVersionCode: minSupportedVersionCode,
      patchUrl: patchUrl != null && patchUrl.isNotEmpty ? patchUrl : null,
      patchSha256: patchSha256 != null && patchSha256.length == 64
          ? patchSha256.toLowerCase()
          : null,
      patchBaseVersionCode:
          patchBase == null ? null : (patchBase as num).toInt(),
    );
  }

  bool hasUsablePatch(int currentBuildNumber) =>
      patchUrl != null &&
      patchSha256 != null &&
      patchBaseVersionCode == currentBuildNumber;
}

/// مراحل التحديث كما تُعرض للمستخدم في نافذة التحديث.
enum PhoneKUpdatePhase {
  preparing,
  downloadingPatch,
  applyingPatch,
  downloadingApk,
  verifying,
  installing,
}

/// نتيجة التثبيت كما يعيدها نظام أندرويد (PackageInstaller).
class PhoneKInstallStatus {
  static const int pending = -1;
  static const int ok = 0;
  static const int failure = 1;
  static const int blocked = 2;
  static const int aborted = 3;
  static const int invalid = 4;
  static const int conflict = 5;
  static const int storage = 6;
  static const int incompatible = 7;
  static const int timeout = 8;
  static const int confirmFailed = -100;

  final int code;
  final String message;

  const PhoneKInstallStatus(this.code, this.message);

  factory PhoneKInstallStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawCode = map['status'];
    final rawMessage = map['message'];
    return PhoneKInstallStatus(
      rawCode is num ? rawCode.toInt() : failure,
      rawMessage is String ? rawMessage : '',
    );
  }

  bool get isPending => code == pending;
  bool get isSuccess => code == ok;
  bool get isCancelled => code == aborted;
  bool get isFailure => !isPending && !isSuccess;

  String get userMessage {
    switch (code) {
      case blocked:
        return 'منع النظام عملية التثبيت. عطّل مؤقتاً «Auto Blocker» أو حماية الجهاز (Play Protect) ثم أعد المحاولة.';
      case aborted:
        return 'تم إلغاء التثبيت. اضغط «إعادة المحاولة» عندما تكون جاهزاً.';
      case invalid:
        return 'ملف التحديث غير صالح أو تالف. سيُعاد تنزيله عند المحاولة التالية.';
      case conflict:
        return 'يوجد تعارض مع النسخة المثبتة (غالباً اختلاف التوقيع). احذف PhoneK ثم ثبّت أحدث نسخة يدوياً مرة واحدة.';
      case storage:
        return 'مساحة تخزين الجهاز غير كافية. احذف بعض الملفات ثم أعد المحاولة.';
      case incompatible:
        return 'هذا التحديث غير متوافق مع جهازك.';
      case timeout:
        return 'انتهت مهلة التثبيت. أعد المحاولة.';
      case confirmFailed:
        return 'تعذر فتح نافذة تأكيد التثبيت. أعد المحاولة.';
      default:
        return 'فشل التثبيت (رمز $code). أعد المحاولة.';
    }
  }
}

enum PhoneKUpdateCheckStatus { updateAvailable, upToDate, failed }

class PhoneKUpdateCheckResult {
  final PhoneKUpdateCheckStatus status;
  final PhoneKUpdate? update;
  final PhoneKUpdateException? error;

  const PhoneKUpdateCheckResult._(this.status, {this.update, this.error});

  const PhoneKUpdateCheckResult.updateAvailable(PhoneKUpdate update)
      : this._(PhoneKUpdateCheckStatus.updateAvailable, update: update);

  const PhoneKUpdateCheckResult.upToDate()
      : this._(PhoneKUpdateCheckStatus.upToDate);

  const PhoneKUpdateCheckResult.failed(PhoneKUpdateException error)
      : this._(PhoneKUpdateCheckStatus.failed, error: error);
}

class PhoneKUpdateService {
  static const _platform = MethodChannel('phonek/update_permissions');

  /// آخر نتيجة تثبيت أبلغ عنها النظام (تستمع لها نافذة التحديث).
  static final ValueNotifier<PhoneKInstallStatus?> installStatus =
      ValueNotifier<PhoneKInstallStatus?>(null);

  static bool _handlerReady = false;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// يربط القناة لاستقبال نتائج التثبيت القادمة من Kotlin.
  static void _ensureHandler() {
    if (_handlerReady || !_supported) return;
    _handlerReady = true;
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'installStatus') {
        final args = call.arguments;
        if (args is Map) {
          installStatus.value = PhoneKInstallStatus.fromMap(args);
        }
      }
      return null;
    });
  }

  /// يسترجع آخر نتيجة تثبيت محفوظة (مفيد عند عودة التطبيق من شاشة التثبيت).
  static Future<PhoneKInstallStatus?> lastInstallResult() async {
    if (!_supported) return null;
    _ensureHandler();
    try {
      final raw = await _platform.invokeMethod<Object?>('getLastInstallResult');
      if (raw is Map) return PhoneKInstallStatus.fromMap(raw);
    } catch (error) {
      debugPrint('PhoneK update: cannot read install result: $error');
    }
    return null;
  }

  /// اسم الملف المؤقت للتحديث: phonek-update-<رقم>.apk وما يتبعه من .patch/.part
  /// يعيد رقم الإصدار أو null إذا لم يكن الملف من ملفات التحديث.
  static int? updateFileVersion(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final match =
        RegExp(r'^phonek-update-(\d+)\.apk(?:\.patch)?(?:\.part)?$')
            .firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static Future<void> _deleteUpdateFiles(
    bool Function(int version) shouldDelete,
  ) async {
    try {
      await for (final entity in Directory.systemTemp.list()) {
        if (entity is! File) continue;
        final version = updateFileVersion(entity.path);
        if (version == null || !shouldDelete(version)) continue;
        try {
          await entity.delete();
        } catch (_) {
          // ملف مستخدم حالياً؛ سيُحذف لاحقاً.
        }
      }
    } catch (error) {
      debugPrint('PhoneK update: cleanup failed: $error');
    }
  }

  /// يُستدعى عند بدء التطبيق: يحذف ملفات التحديث القديمة (بما فيها APK الإصدار
  /// المثبّت حالياً والملفات الجزئية) حتى لا تتراكم عشرات الميغابايتات في الجهاز.
  static Future<void> cleanupStaleFiles() async {
    if (!_supported) return;
    _ensureHandler();
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      await _deleteUpdateFiles((version) => version <= current);
      await _platform.invokeMethod<void>('clearInstallResult');
    } catch (error) {
      debugPrint('PhoneK update: startup cleanup failed: $error');
    }
  }

  /// يحذف نسخة APK المخزنة لهذا الإصدار (مثلاً إذا رفضها النظام كملف تالف).
  static Future<void> discardCachedApk(PhoneKUpdate update) async {
    if (!_supported) return;
    await _deleteUpdateFiles((version) => version == update.versionCode);
  }

  static Future<void> openInstallPermissionSettings() async {
    if (!_supported) return;
    await _platform.invokeMethod<void>('openInstallPermissionSettings');
  }

  static Future<bool> canInstallPackages() async {
    if (!_supported) return true;
    return await _platform.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  static Future<String?> _installedApkPath() async {
    if (!_supported) return null;
    try {
      return await _platform.invokeMethod<String>('getInstalledApkPath');
    } catch (error) {
      debugPrint('PhoneK update: cannot get installed APK path: $error');
      return null;
    }
  }

  static Future<http.Response> _fetchManifest() async {
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        return await http.get(
          Uri.parse(phoneKUpdateManifestUrl).replace(
            queryParameters: {'t': now.toString()},
          ),
          headers: const {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 15));
      } catch (error) {
        lastError = error;
        if (attempt < 2) await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    throw lastError!;
  }

  static Future<PhoneKUpdateCheckResult> check() async {
    if (!_supported) {
      debugPrint('PhoneK update check skipped: platform is not Android.');
      return const PhoneKUpdateCheckResult.upToDate();
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final response = await _fetchManifest();

      if (response.statusCode != 200) {
        final reason = 'manifest HTTP ${response.statusCode}';
        debugPrint('PhoneK update check failed: $reason');
        return PhoneKUpdateCheckResult.failed(PhoneKUpdateException(
          'check_http',
          userMessage: 'تعذر الوصول إلى خادم التحديث. تحقق من الإنترنت وحاول مرة أخرى.',
          detail: reason,
        ));
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        const reason = 'manifest is not a JSON object';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(PhoneKUpdateException('check_manifest', userMessage: 'بيانات التحديث غير صحيحة حالياً. حاول لاحقاً.', detail: reason));
      }
      final update = PhoneKUpdate.fromJson(
        decoded,
        currentBuildNumber: currentBuildNumber,
      );

      if (update.apkUrl.isEmpty || !_isReleaseAssetUrl(update.apkUrl)) {
        const reason = 'manifest contains an invalid apkUrl';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(PhoneKUpdateException('check_invalid', userMessage: 'بيانات التحديث غير صالحة حالياً. حاول لاحقاً.', detail: reason));
      }
      if (update.sha256.length != 64 || !_isHexSha256(update.sha256)) {
        const reason = 'manifest contains an invalid APK SHA-256';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(PhoneKUpdateException('check_invalid', userMessage: 'بيانات التحديث غير صالحة حالياً. حاول لاحقاً.', detail: reason));
      }
      if (update.patchUrl != null && !_isReleaseAssetUrl(update.patchUrl!)) {
        const reason = 'manifest contains an invalid patchUrl';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(PhoneKUpdateException('check_invalid', userMessage: 'بيانات التحديث غير صالحة حالياً. حاول لاحقاً.', detail: reason));
      }
      if (update.patchUrl != null &&
          (update.patchSha256 == null || !_isHexSha256(update.patchSha256!))) {
        const reason = 'manifest contains an invalid patch SHA-256';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(PhoneKUpdateException('check_invalid', userMessage: 'بيانات التحديث غير صالحة حالياً. حاول لاحقاً.', detail: reason));
      }

      if (update.versionCode <= currentBuildNumber) {
        debugPrint('PhoneK update check: no update available.');
        return const PhoneKUpdateCheckResult.upToDate();
      }

      return PhoneKUpdateCheckResult.updateAvailable(update);
    } catch (error, stackTrace) {
      debugPrint('PhoneK update check failed: $error');
      debugPrint('$stackTrace');
      final isNetwork = error is SocketException ||
          error is TimeoutException ||
          error is http.ClientException;
      return PhoneKUpdateCheckResult.failed(PhoneKUpdateException(
        isNetwork ? 'check_network' : 'check_unknown',
        userMessage: isNetwork
            ? 'تعذر الاتصال بخادم التحديث. تحقق من الإنترنت وحاول مرة أخرى.'
            : 'تعذر التحقق من وجود تحديث حالياً. حاول مرة أخرى.',
        detail: error.toString(),
      ));
    }
  }

  static bool _isReleaseAssetUrl(String value) =>
      value.startsWith(_releaseAssetPrefix);

  static bool _isHexSha256(String value) =>
      RegExp(r'^[0-9a-f]{64}$', caseSensitive: false).hasMatch(value);

  static Future<String> _sha256File(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static bool _isNoSpace(FileSystemException error) =>
      error.osError?.errorCode == 28; // ENOSPC

  static Future<void> downloadAndInstall(
    PhoneKUpdate update, {
    void Function(double progress)? onProgress,
    void Function(PhoneKUpdatePhase phase)? onPhase,
  }) async {
    _ensureHandler();
    installStatus.value = null;
    try {
      final file = File(
        '${Directory.systemTemp.path}/phonek-update-${update.versionCode}.apk',
      );
      onPhase?.call(PhoneKUpdatePhase.preparing);
      await _deleteUpdateFiles((version) => version != update.versionCode);

      var cachedApkIsValid = false;
      if (await file.exists() && await file.length() > 0) {
        onPhase?.call(PhoneKUpdatePhase.verifying);
        final cachedDigest = await _sha256File(file);
        cachedApkIsValid = cachedDigest.toLowerCase() == update.sha256;
        if (cachedApkIsValid) {
          onProgress?.call(1.0);
        } else {
          await file.delete().catchError((_) => file);
        }
      }

      if (!cachedApkIsValid) {
        final builtFromPatch = await _tryBuildFromPatch(
          update,
          file,
          onProgress: onProgress,
          onPhase: onPhase,
        );
        if (!builtFromPatch) {
          await _downloadFullApk(
            update,
            file,
            onProgress: onProgress,
            onPhase: onPhase,
          );
        }
      }

      onPhase?.call(PhoneKUpdatePhase.installing);
      await _installApk(file);
    } on FileSystemException catch (error) {
      if (_isNoSpace(error)) {
        throw PhoneKUpdateException(
          'storage_full',
          userMessage: 'مساحة تخزين الجهاز ممتلئة. احذف بعض الملفات ثم أعد المحاولة.',
          detail: error.toString(),
        );
      }
      throw PhoneKUpdateException(
        'file_system',
        userMessage: 'تعذر حفظ ملف التحديث على الجهاز. أعد المحاولة.',
        detail: error.toString(),
      );
    }
  }

  static Future<bool> _tryBuildFromPatch(
    PhoneKUpdate update,
    File outputFile, {
    void Function(double progress)? onProgress,
    void Function(PhoneKUpdatePhase phase)? onPhase,
  }) async {
    File? patchFile;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      if (!update.hasUsablePatch(current)) return false;
      final path = await _installedApkPath();
      if (path == null) return false;
      final oldFile = File(path);
      if (!await oldFile.exists()) return false;

      onPhase?.call(PhoneKUpdatePhase.downloadingPatch);
      patchFile = File('${outputFile.path}.patch');
      await _downloadWithResume(
        Uri.parse(update.patchUrl!),
        patchFile,
        onProgress: (value) => onProgress?.call(value * 0.6),
      );
      onPhase?.call(PhoneKUpdatePhase.verifying);
      if (await _sha256File(patchFile) != update.patchSha256) return false;
      onProgress?.call(0.7);

      onPhase?.call(PhoneKUpdatePhase.applyingPatch);
      // Apply the patch directly from files instead of loading the entire
      // old APK and patch into RAM. This is substantially lighter on phones.
      await BinaryPatch.apply(
        oldFile: oldFile.path,
        patchFile: patchFile.path,
        outputFile: outputFile.path,
        verifyChecksum: true,
      );
      onPhase?.call(PhoneKUpdatePhase.verifying);
      if (await _sha256File(outputFile) != update.sha256) {
        await outputFile.delete().catchError((_) => outputFile);
        return false;
      }
      onProgress?.call(1.0);
      return true;
    } catch (error) {
      debugPrint('PhoneK update patch failed; using full APK: $error');
      onProgress?.call(0.0);
      return false;
    } finally {
      if (patchFile != null) {
        final leftover = patchFile;
        if (await leftover.exists()) {
          await leftover.delete().catchError((_) => leftover);
        }
        final leftoverPart = File('${leftover.path}.part');
        if (await leftoverPart.exists()) {
          await leftoverPart.delete().catchError((_) => leftoverPart);
        }
      }
    }
  }

  static Future<void> _downloadFullApk(
    PhoneKUpdate update,
    File file, {
    void Function(double progress)? onProgress,
    void Function(PhoneKUpdatePhase phase)? onPhase,
  }) async {
    onPhase?.call(PhoneKUpdatePhase.downloadingApk);
    await _downloadWithResume(
      Uri.parse(update.apkUrl),
      file,
      onProgress: onProgress,
    );
    onPhase?.call(PhoneKUpdatePhase.verifying);
    final digest = await _sha256File(file);
    if (digest.toLowerCase() != update.sha256) {
      await file.delete().catchError((_) => file);
      throw const PhoneKUpdateException('apk_checksum', userMessage: 'فشل التحقق من ملف التحديث. لن يتم تثبيت ملف غير موثوق. أعد المحاولة.');
    }
    onProgress?.call(1.0);
  }

  static Future<void> _downloadWithResume(
    Uri url,
    File destination, {
    void Function(double progress)? onProgress,
  }) async {
    final partial = File('${destination.path}.part');
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        var offset = await partial.exists() ? await partial.length() : 0;
        final request = await client.getUrl(url);
        request.followRedirects = true;
        if (offset > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
        }
        final response = await request.close();

        if (offset > 0 && response.statusCode != HttpStatus.partialContent) {
          await response.drain<void>();
          await partial.delete().catchError((_) => partial);
          offset = 0;
          final restartRequest = await client.getUrl(url);
          restartRequest.followRedirects = true;
          final restartResponse = await restartRequest.close();
          if (restartResponse.statusCode != HttpStatus.ok) {
            throw HttpException(
                'Download failed: ${restartResponse.statusCode}');
          }
          await _consumeResponse(restartResponse, partial, 0, onProgress);
        } else {
          if (response.statusCode != HttpStatus.ok &&
              response.statusCode != HttpStatus.partialContent) {
            throw HttpException('Download failed: ${response.statusCode}');
          }
          await _consumeResponse(
            response,
            partial,
            response.statusCode == HttpStatus.partialContent ? offset : 0,
            onProgress,
          );
        }

        await destination.delete().catchError((_) => destination);
        await partial.rename(destination.path);
        return;
      } on FileSystemException {
        // خطأ تخزين (مثل امتلاء المساحة): لا فائدة من إعادة المحاولة.
        rethrow;
      } catch (error) {
        lastError = error;
        debugPrint('PhoneK update: download attempt $attempt failed: $error');
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      } finally {
        client.close(force: true);
      }
    }

    throw PhoneKUpdateException(
      'download',
      userMessage: 'تعذر تنزيل التحديث بعد عدة محاولات. تحقق من الإنترنت وحاول مرة أخرى.',
      detail: lastError?.toString(),
    );
  }

  static Future<void> _consumeResponse(
    HttpClientResponse response,
    File partial,
    int alreadyReceived,
    void Function(double progress)? onProgress,
  ) async {
    final total = response.contentLength > 0
        ? response.contentLength + alreadyReceived
        : -1;
    var received = alreadyReceived;
    final sink = partial.openWrite(
      mode: alreadyReceived > 0 ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (total > 0 && received < total) {
      // انقطع الاتصال مبكراً: نُبقي الملف الجزئي ونعيد المحاولة بالاستئناف.
      throw HttpException('Incomplete download: $received/$total');
    }
  }

  static String describeRejection(String message) {
    if (message.startsWith('APK_SIGNATURE_MISMATCH')) {
      return 'توقيع نسخة التحديث يختلف عن النسخة المثبتة على جهازك لذلك يرفضها أندرويد. احذف PhoneK ثم ثبّت أحدث نسخة يدوياً مرة واحدة.';
    }
    if (message.startsWith('APK_WRONG_PACKAGE')) {
      return 'ملف التحديث يخص تطبيقاً مختلفاً. أبلغ الدعم.';
    }
    if (message.startsWith('APK_NOT_NEWER')) {
      return 'النسخة المثبتة حالياً مساوية لملف التحديث أو أحدث منه.';
    }
    return 'تم رفض ملف التحديث قبل التثبيت.';
  }

  static Future<void> _installApk(File file) async {
    try {
      await _platform.invokeMethod<String>('installApk', {'filePath': file.path});
    } on PlatformException catch (error) {
      final message = error.message ?? '';
      if (error.code == 'INSTALL_PERMISSION') {
        throw const PhoneKUpdateException('install_permission');
      }
      if (error.code == 'APK_REJECTED') {
        throw PhoneKUpdateException(
          'apk_rejected',
          userMessage: describeRejection(message),
          detail: message,
        );
      }
      throw PhoneKUpdateException(
        'install',
        userMessage: 'تم تنزيل التحديث، لكن تعذر فتح شاشة التثبيت.',
        detail: '${error.code}: $message',
      );
    } on MissingPluginException catch (error) {
      throw PhoneKUpdateException(
        'install',
        userMessage: 'هذه النسخة لا تدعم التثبيت التلقائي. ثبّت أحدث نسخة يدوياً.',
        detail: error.toString(),
      );
    }
  }
}

class PhoneKUpdateException implements Exception {
  final String reason;
  final String userMessage;

  /// تفاصيل تقنية تظهر بخط صغير في نافذة التحديث (لتسهيل تشخيص أي مشكلة).
  final String? detail;

  const PhoneKUpdateException(
    this.reason, {
    this.userMessage = 'حدث خطأ أثناء التحديث. حاول مرة أخرى.',
    this.detail,
  });

  @override
  String toString() => userMessage;
}
