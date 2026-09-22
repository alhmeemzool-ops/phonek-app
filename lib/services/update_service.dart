import 'dart:convert';
import 'dart:io';

import 'package:apk_sideload/install_apk.dart';
import 'package:binary_patch/binary_patch.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

const String phoneKUpdateManifestUrl =
    'https://raw.githubusercontent.com/alhmeemzool-ops/phonek-app/main/update.json';

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
      patchUrl: (patchUrl != null && patchUrl.isNotEmpty) ? patchUrl : null,
      patchSha256: (patchSha256 != null && patchSha256.length == 64) ? patchSha256.toLowerCase() : null,
      patchBaseVersionCode: patchBase == null ? null : (patchBase as num).toInt(),
    );
  }

  bool hasUsablePatch(int currentBuildNumber) =>
      patchUrl != null && patchSha256 != null && patchBaseVersionCode == currentBuildNumber;
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
    try { return await _platform.invokeMethod<String>('getInstalledApkPath'); } catch (_) { return null; }
  }

  static Future<PhoneKUpdate?> check() async {
    if (!Platform.isAndroid) return null;

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

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final update = PhoneKUpdate.fromJson(data);

      if (update.apkUrl.isEmpty || update.sha256.length != 64) return null;

      if (update.versionCode <= currentBuildNumber) return null;

      return update;
    } catch (_) {
      return null;
    }
  }

  static Future<void> downloadAndInstall(
    PhoneKUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/phonek-update-${update.versionCode}.apk');
    await _deleteOldUpdateApks(file.path);

    var cachedApkIsValid = false;
      if (await file.exists() && await file.length() > 0) {
        final cachedDigest = sha256.convert(await file.readAsBytes()).toString();
        cachedApkIsValid = cachedDigest.toLowerCase() == update.sha256;
        if (cachedApkIsValid) onProgress?.call(1.0);
      }

      if (!cachedApkIsValid) {
        final builtFromPatch = await _tryBuildFromPatch(update, file, onProgress: onProgress);
        if (!builtFromPatch) {
          await _downloadFullApk(update, file, onProgress: onProgress);
        }
      }
      await _installApk(file);
  }

  static Future<bool> _tryBuildFromPatch(PhoneKUpdate update, File outputFile, {void Function(double progress)? onProgress}) async {
    File? patchFile;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      if (!update.hasUsablePatch(current)) return false;
      final path = await _installedApkPath();
      if (path == null) return false;
      final oldFile = File(path);
      if (!await oldFile.exists()) return false;
      final patch = File('${outputFile.path}.patch');
      patchFile = patch;
      if (await patch.exists()) await patch.delete();
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse(update.patchUrl!));
        req.followRedirects = true;
        final resp = await req.close();
        if (resp.statusCode != HttpStatus.ok) return false;
        final sink = patch.openWrite();
        final total = resp.contentLength;
        var received = 0;
        try { await for (final chunk in resp) { sink.add(chunk); received += chunk.length; if (total > 0) onProgress?.call((received / total * 0.6).clamp(0.0,0.6)); } }
        finally { await sink.flush(); await sink.close(); }
      } finally { client.close(force: true); }
      final patchBytes = await patch.readAsBytes();
      if (sha256.convert(patchBytes).toString().toLowerCase() != update.patchSha256) return false;
      onProgress?.call(0.7);
      final rebuilt = await BinaryPatch.applyBytes(oldData: await oldFile.readAsBytes(), patchData: patchBytes);
      if (sha256.convert(rebuilt).toString().toLowerCase() != update.sha256) return false;
      await outputFile.writeAsBytes(rebuilt, flush: true);
      onProgress?.call(1.0);
      return true;
    } catch (_) { return false; }
    finally { if (patchFile != null && await patchFile.exists()) await patchFile.delete().catchError((_) => patchFile!); }
  }

  static Future<void> _downloadFullApk(PhoneKUpdate update, File file, {void Function(double progress)? onProgress}) async {
    final client = HttpClient();
    try {
      await file.delete().catchError((_) => file);
        final request = await client.getUrl(Uri.parse(update.apkUrl));
        request.followRedirects = true;
        final response = await request.close();

        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('Download failed: ${response.statusCode}');
        }

        final total = response.contentLength;
        var received = 0;
        final sink = file.openWrite();
        try {
          await for (final chunk in response) {
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

        final digest = sha256.convert(await file.readAsBytes()).toString();
        if (digest.toLowerCase() != update.sha256) {
          await file.delete().catchError((_) => file);
          throw const FormatException('APK checksum mismatch');
        }

        onProgress?.call(1.0);
      } finally { client.close(force: true); }
  }

  static Future<void> _installApk(File file) async {
    try {
        await InstallApk().installApk(file.path);
      } on PlatformException catch (error) {
        if (error.code == 'INSTALL_ERROR') {
          // بعض إصدارات مُثبت APK تعيد INSTALL_ERROR لأسباب أخرى غير الصلاحية.
          // افحص حالة Android مرة ثانية قبل عرض زر الإعدادات للمستخدم.
          final permissionStillMissing = !(await canInstallPackages());
          throw PhoneKUpdateException(
            permissionStillMissing ? 'install_permission' : 'install',
          );
        }
        throw const PhoneKUpdateException('install');
      }
    }
}

class PhoneKUpdateException implements Exception {
  final String reason;

  const PhoneKUpdateException(this.reason);
}
