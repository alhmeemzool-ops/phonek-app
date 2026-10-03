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
    this.patchUrl,
    this.patchSha256,
    this.patchBaseVersionCode,
  });

  factory PhoneKUpdate.fromJson(Map<String, dynamic> json) {
    final patchUrl = json['patchUrl'] as String?;
    final patchSha256 = json['patchSha256'] as String?;
    final patchBase = json['patchBaseVersionCode'];
    return PhoneKUpdate(
      versionCode: (json['versionCode'] as num).toInt(),
      versionName: json['versionName'] as String,
      apkUrl: json['apkUrl'] as String,
      sha256: (json['sha256'] as String).toLowerCase(),
      mandatory: json['mandatory'] == true,
      notes: (json['notes'] as String?) ?? '',
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

enum PhoneKUpdateCheckStatus { updateAvailable, upToDate, failed }

class PhoneKUpdateCheckResult {
  final PhoneKUpdateCheckStatus status;
  final PhoneKUpdate? update;
  final String? error;

  const PhoneKUpdateCheckResult._(this.status, {this.update, this.error});

  const PhoneKUpdateCheckResult.updateAvailable(PhoneKUpdate update)
      : this._(PhoneKUpdateCheckStatus.updateAvailable, update: update);

  const PhoneKUpdateCheckResult.upToDate()
      : this._(PhoneKUpdateCheckStatus.upToDate);

  const PhoneKUpdateCheckResult.failed(String error)
      : this._(PhoneKUpdateCheckStatus.failed, error: error);
}

class PhoneKUpdateService {
  static const _platform = MethodChannel('phonek/update_permissions');

  static Future<void> _deleteOldUpdateApks(String keepPath) async {
    final tempDir = Directory.systemTemp;
    await for (final entity in tempDir.list()) {
      if (entity is File &&
          entity.path != keepPath &&
          entity.path.contains('/phonek-update-') &&
          entity.path.endsWith('.apk')) {
        await entity.delete().catchError((_) => entity);
      }
    }
  }

  static Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _platform.invokeMethod<void>('openInstallPermissionSettings');
  }

  static Future<bool> canInstallPackages() async {
    if (!Platform.isAndroid) return true;
    return await _platform.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  static Future<String?> _installedApkPath() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _platform.invokeMethod<String>('getInstalledApkPath');
    } catch (error) {
      debugPrint('PhoneK update: cannot get installed APK path: $error');
      return null;
    }
  }

  static Future<PhoneKUpdateCheckResult> check() async {
    if (!Platform.isAndroid) {
      debugPrint('PhoneK update check skipped: platform is not Android.');
      return const PhoneKUpdateCheckResult.upToDate();
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse(phoneKUpdateManifestUrl).replace(
          queryParameters: {'t': now.toString()},
        ),
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        final reason = 'manifest HTTP ${response.statusCode}';
        debugPrint('PhoneK update check failed: $reason');
        return PhoneKUpdateCheckResult.failed(reason);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        const reason = 'manifest is not a JSON object';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(reason);
      }
      final update = PhoneKUpdate.fromJson(decoded);

      if (update.apkUrl.isEmpty || !_isReleaseAssetUrl(update.apkUrl)) {
        const reason = 'manifest contains an invalid apkUrl';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(reason);
      }
      if (update.sha256.length != 64 || !_isHexSha256(update.sha256)) {
        const reason = 'manifest contains an invalid APK SHA-256';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(reason);
      }
      if (update.patchUrl != null && !_isReleaseAssetUrl(update.patchUrl!)) {
        const reason = 'manifest contains an invalid patchUrl';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(reason);
      }
      if (update.patchUrl != null &&
          (update.patchSha256 == null || !_isHexSha256(update.patchSha256!))) {
        const reason = 'manifest contains an invalid patch SHA-256';
        debugPrint('PhoneK update check failed: $reason');
        return const PhoneKUpdateCheckResult.failed(reason);
      }

      if (update.versionCode <= currentBuildNumber) {
        debugPrint('PhoneK update check: no update available.');
        return const PhoneKUpdateCheckResult.upToDate();
      }

      return PhoneKUpdateCheckResult.updateAvailable(update);
    } catch (error, stackTrace) {
      debugPrint('PhoneK update check failed: $error');
      debugPrint('$stackTrace');
      return PhoneKUpdateCheckResult.failed(error.toString());
    }
  }

  static bool _isReleaseAssetUrl(String value) =>
      value.startsWith(_releaseAssetPrefix);

  static bool _isHexSha256(String value) =>
      RegExp(r'^[0-9a-f]{64}$', caseSensitive: false).hasMatch(value);

  static Future<String> _sha256File(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<void> downloadAndInstall(
    PhoneKUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = Directory.systemTemp;
    final file =
        File('${tempDir.path}/phonek-update-${update.versionCode}.apk');
    await _deleteOldUpdateApks(file.path);

    var cachedApkIsValid = false;
    if (await file.exists() && await file.length() > 0) {
      final cachedDigest = await _sha256File(file);
      cachedApkIsValid = cachedDigest.toLowerCase() == update.sha256;
      if (cachedApkIsValid) onProgress?.call(1.0);
    }

    if (!cachedApkIsValid) {
      final builtFromPatch = await _tryBuildFromPatch(
        update,
        file,
        onProgress: onProgress,
      );
      if (!builtFromPatch) {
        await _downloadFullApk(update, file, onProgress: onProgress);
      }
    }

    await _installApk(file);
  }

  static Future<bool> _tryBuildFromPatch(
    PhoneKUpdate update,
    File outputFile, {
    void Function(double progress)? onProgress,
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

      patchFile = File('${outputFile.path}.patch');
      await _downloadWithResume(
        Uri.parse(update.patchUrl!),
        patchFile,
        onProgress: (value) => onProgress?.call(value * 0.6),
      );
      if (await _sha256File(patchFile) != update.patchSha256) return false;
      onProgress?.call(0.7);

      final oldPath = oldFile.path;
      final patchPath = patchFile.path;
      final rebuilt = await Isolate.run(() async {
        final oldData = await File(oldPath).readAsBytes();
        final patchData = await File(patchPath).readAsBytes();
        return BinaryPatch.applyBytes(oldData: oldData, patchData: patchData);
      });
      await outputFile.writeAsBytes(rebuilt, flush: true);
      if (await _sha256File(outputFile) != update.sha256) {
        await outputFile.delete().catchError((_) => outputFile);
        return false;
      }
      onProgress?.call(1.0);
      return true;
    } catch (error) {
      debugPrint('PhoneK update patch failed; using full APK: $error');
      return false;
    } finally {
      if (patchFile != null && await patchFile.exists()) {
        await patchFile.delete().catchError((_) => patchFile!);
      }
    }
  }

  static Future<void> _downloadFullApk(
    PhoneKUpdate update,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    await _downloadWithResume(
      Uri.parse(update.apkUrl),
      file,
      onProgress: onProgress,
    );
    final digest = await _sha256File(file);
    if (digest.toLowerCase() != update.sha256) {
      await file.delete().catchError((_) => file);
      throw const FormatException('APK checksum mismatch');
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
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      } finally {
        client.close(force: true);
      }
    }

    throw HttpException('Download failed after 3 attempts: $lastError');
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
  }

  static Future<void> _installApk(File file) async {
    try {
      await _platform.invokeMethod<void>('installApk', {'filePath': file.path});
    } on PlatformException catch (error) {
      if (error.code == 'INSTALL_ERROR') {
        final permissionStillMissing = !(await canInstallPackages());
        throw PhoneKUpdateException(
          permissionStillMissing
              ? 'install_permission'
              : 'install:${error.message ?? 'unknown_error'}',
        );
      }
      throw PhoneKUpdateException(
          'install:${error.message ?? 'unknown_error'}');
    }
  }
}

class PhoneKUpdateException implements Exception {
  final String reason;

  const PhoneKUpdateException(this.reason);
}
