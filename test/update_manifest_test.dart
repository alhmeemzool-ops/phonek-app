import 'package:flutter_test/flutter_test.dart';
import 'package:phonek_app/services/update_service.dart';

void main() {
  const prefix =
      'https://github.com/alhmeemzool-ops/phonek-app/releases/download/';

  test('old-format manifest parses', () {
    final update = PhoneKUpdate.fromJson({
      'versionCode': 83,
      'versionName': '1.0.83',
      'apkUrl': '${prefix}v1.0.83/app-release.apk',
      'sha256': 'a' * 64,
      'patchUrl': '${prefix}v1.0.83/patch-from-82.bin',
      'patchSha256': 'b' * 64,
      'patchBaseVersionCode': 82,
      'minSupportedVersionCode': 58,
      'mandatory': false,
      'notes': 'تحديث',
    });
    expect(update.patches, isEmpty);
    expect(update.hasUsablePatch(82), isTrue);
  });

  test('new-format manifest parses', () {
    final update = PhoneKUpdate.fromJson({
      'versionCode': 85,
      'versionName': '1.0.85',
      'apkUrl': '${prefix}v1.0.85/app-release.apk',
      'sha256': 'a' * 64,
      'apkSize': 48000000,
      'patches': [
        {
          'baseVersionCode': 84,
          'baseSha256': 'c' * 64,
          'url': '${prefix}v1.0.85/patch-from-84.bin',
          'sha256': 'b' * 64,
          'size': 6200000,
        },
      ],
    });
    expect(update.apkSize, 48000000);
    expect(update.patches.single.baseVersionCode, 84);
    expect(update.patches.single.size, 6200000);
  });

  test('patch selected by baseVersionCode', () {
    final update = PhoneKUpdate.fromJson({
      'versionCode': 85,
      'versionName': '1.0.85',
      'apkUrl': '${prefix}v1.0.85/app-release.apk',
      'sha256': 'a' * 64,
      'patches': [
        {
          'baseVersionCode': 82,
          'baseSha256': '2' * 64,
          'url': '${prefix}v1.0.85/patch-from-82.bin',
          'sha256': 'b' * 64,
          'size': 100,
        },
        {
          'baseVersionCode': 84,
          'baseSha256': '4' * 64,
          'url': '${prefix}v1.0.85/patch-from-84.bin',
          'sha256': 'c' * 64,
          'size': 200,
        },
      ],
    });
    expect(choosePhoneKUpdatePatch(update, 84)!.baseVersionCode, 84);
    expect(choosePhoneKUpdatePatch(update, 83), isNull);
  });

  test('legacy fallback', () {
    final update = PhoneKUpdate.fromJson({
      'versionCode': 85,
      'versionName': '1.0.85',
      'apkUrl': '${prefix}v1.0.85/app-release.apk',
      'sha256': 'a' * 64,
      'patchUrl': '${prefix}v1.0.85/patch-from-84.bin',
      'patchSha256': 'b' * 64,
      'patchBaseVersionCode': 84,
    });
    final patch = choosePhoneKUpdatePatch(update, 84);
    expect(patch, isNotNull);
    expect(patch!.baseSha256, isNull);
  });

  test('malformed patch entries are ignored without throwing', () {
    final update = PhoneKUpdate.fromJson({
      'versionCode': 85,
      'versionName': '1.0.85',
      'apkUrl': '${prefix}v1.0.85/app-release.apk',
      'sha256': 'a' * 64,
      'patches': [
        'bad',
        {
          'baseVersionCode': 84,
          'baseSha256': 'not-a-sha',
          'url': '${prefix}v1.0.85/patch-from-84.bin',
          'sha256': 'b' * 64,
          'size': 10,
        },
        {
          'baseVersionCode': 83,
          'baseSha256': '3' * 64,
          'url': 'https://example.invalid/patch.bin',
          'sha256': 'c' * 64,
          'size': 10,
        },
      ],
    });
    expect(update.patches, isEmpty);
    expect(choosePhoneKUpdatePatch(update, 84), isNull);
  });
}
