import 'package:flutter_test/flutter_test.dart';
import 'package:phonek_app/services/update_service.dart';

void main() {
  test('install status codes map to Arabic messages', () {
    expect(
      const PhoneKInstallStatus(PhoneKInstallStatus.aborted, '').userMessage,
      contains('إلغاء'),
    );
    expect(
      const PhoneKInstallStatus(PhoneKInstallStatus.conflict, '').userMessage,
      contains('تعارض'),
    );
    expect(
      const PhoneKInstallStatus(PhoneKInstallStatus.storage, '').userMessage,
      contains('مساحة'),
    );
    expect(
      const PhoneKInstallStatus(99, '').userMessage,
      contains('99'),
    );
  });

  test('install status flags', () {
    const pending = PhoneKInstallStatus(PhoneKInstallStatus.pending, '');
    const done = PhoneKInstallStatus(PhoneKInstallStatus.ok, '');
    const cancelled = PhoneKInstallStatus(PhoneKInstallStatus.aborted, '');
    expect(pending.isPending, isTrue);
    expect(pending.isFailure, isFalse);
    expect(done.isSuccess, isTrue);
    expect(done.isFailure, isFalse);
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.isFailure, isTrue);
  });

  test('install status parses the native map', () {
    final status = PhoneKInstallStatus.fromMap({'status': 2, 'message': 'x'});
    expect(status.code, PhoneKInstallStatus.blocked);
    expect(status.message, 'x');

    final broken = PhoneKInstallStatus.fromMap({});
    expect(broken.code, PhoneKInstallStatus.failure);
    expect(broken.message, '');
  });

  test('recognises update temp files and their versions', () {
    expect(
      PhoneKUpdateService.updateFileVersion(
          '/data/user/0/com.phonek.phonek_app/cache/phonek-update-66.apk'),
      66,
    );
    expect(PhoneKUpdateService.updateFileVersion('phonek-update-7.apk.part'), 7);
    expect(PhoneKUpdateService.updateFileVersion('phonek-update-7.apk.patch'), 7);
    expect(
      PhoneKUpdateService.updateFileVersion('phonek-update-7.apk.patch.part'),
      7,
    );
    expect(PhoneKUpdateService.updateFileVersion('other.apk'), isNull);
    expect(PhoneKUpdateService.updateFileVersion('phonek-update-7.apk.bak'), isNull);
  });

  test('rejection codes produce a clear message', () {
    expect(
      PhoneKUpdateService.describeRejection('APK_SIGNATURE_MISMATCH'),
      contains('توقيع'),
    );
    expect(
      PhoneKUpdateService.describeRejection('APK_NOT_NEWER: 5 <= 6'),
      contains('النسخة'),
    );
  });

  test('update exception keeps technical detail', () {
    const error = PhoneKUpdateException(
      'install',
      userMessage: 'رسالة',
      detail: 'INSTALL_ERROR: x',
    );
    expect(error.toString(), 'رسالة');
    expect(error.detail, 'INSTALL_ERROR: x');
  });
}
