import 'dart:convert';
import 'dart:io';

import 'package:apk_sideload/install_apk.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

const int phoneKBuildNumber = int.fromEnvironment(
  'PHONEK_BUILD_NUMBER',
  defaultValue: 1,
);

const String phoneKUpdateManifestUrl =
    'https://raw.githubusercontent.com/alhmeemzool-ops/phonek-app/main/update.json';

class PhoneKUpdate {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String sha256;
  final bool mandatory;
  final String notes;

  const PhoneKUpdate({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.mandatory,
    required this.notes,
  });

  factory PhoneKUpdate.fromJson(Map<String, dynamic> json) {
    return PhoneKUpdate(
      versionCode: (json['versionCode'] as num).toInt(),
      versionName: json['versionName'] as String,
      apkUrl: json['apkUrl'] as String,
      sha256: (json['sha256'] as String).toLowerCase(),
      mandatory: json['mandatory'] == true,
      notes: (json['notes'] as String?) ?? '',
    );
  }
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

  static Future<PhoneKUpdate?> check() async {
    if (!Platform.isAndroid) return null;

    try {
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

      if (update.versionCode <= phoneKBuildNumber) return null;

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

    final client = HttpClient();
    try {
      var cachedApkIsValid = false;
      if (await file.exists() && await file.length() > 0) {
        final cachedDigest = sha256.convert(await file.readAsBytes()).toString();
        cachedApkIsValid = cachedDigest.toLowerCase() == update.sha256;
        if (cachedApkIsValid) onProgress?.call(1.0);
      }

      if (!cachedApkIsValid) {
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
      }
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
    } finally {
      client.close(force: true);
    }
  }
}

class PhoneKUpdateException implements Exception {
  final String reason;

  const PhoneKUpdateException(this.reason);
}
