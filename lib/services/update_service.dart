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

  static Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _platform.invokeMethod<void>('openInstallPermissionSettings');
  }

  static Future<PhoneKUpdate?> check() async {
    if (!Platform.isAndroid) return null;

    try {
      final response = await http.get(
        Uri.parse(phoneKUpdateManifestUrl),
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final update = PhoneKUpdate.fromJson(data);

      if (update.versionCode <= phoneKBuildNumber) return null;
      if (update.apkUrl.isEmpty || update.sha256.length != 64) return null;

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

    if (await file.exists()) {
      await file.delete();
    }

    final client = HttpClient();
    try {
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
      try {
        await InstallApk().installApk(file.path);
      } on PlatformException catch (error) {
        if (error.code == 'INSTALL_ERROR') {
          throw const PhoneKUpdateException(
            'install_permission',
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
