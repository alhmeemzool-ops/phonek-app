import 'package:flutter_test/flutter_test.dart';
import 'package:phonek_app/services/update_service.dart';

void main() {
  test('parses a valid update manifest and patch metadata', () {
    final update = PhoneKUpdate.fromJson({
      'versionCode': 57,
      'versionName': '1.0.57',
      'apkUrl': 'https://github.com/alhmeemzool-ops/phonek-app/releases/download/v1.0.57/app-release.apk',
      'sha256': 'a' * 64,
      'patchUrl': 'https://github.com/alhmeemzool-ops/phonek-app/releases/download/v1.0.57/patch.bin',
      'patchSha256': 'b' * 64,
      'patchBaseVersionCode': 56,
      'mandatory': false,
      'notes': 'تحديث',
    }, currentBuildNumber: 56);

    expect(update.versionCode, 57);
    expect(update.versionName, '1.0.57');
    expect(update.mandatory, isFalse);
    expect(update.hasUsablePatch(56), isTrue);
    expect(update.hasUsablePatch(55), isFalse);
  });

  test('minimum supported version makes an update mandatory', () {
    final update = PhoneKUpdate.fromJson({
      'versionCode': 60,
      'versionName': '1.0.60',
      'apkUrl': 'https://github.com/alhmeemzool-ops/phonek-app/releases/download/v1.0.60/app-release.apk',
      'sha256': 'a' * 64,
      'minSupportedVersionCode': 58,
      'mandatory': false,
      'notes': '',
    }, currentBuildNumber: 57);

    expect(update.minSupportedVersionCode, 58);
    expect(update.mandatory, isTrue);
  });

  test('mandatory flag remains true when explicitly set', () {
    final update = PhoneKUpdate.fromJson({
      'versionCode': 58,
      'versionName': '1.0.58',
      'apkUrl': 'https://github.com/alhmeemzool-ops/phonek-app/releases/download/v1.0.58/app-release.apk',
      'sha256': 'c' * 64,
      'mandatory': true,
      'notes': '',
    }, currentBuildNumber: 57);

    expect(update.mandatory, isTrue);
  });
}
