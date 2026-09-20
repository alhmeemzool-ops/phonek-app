// أداة تُستخدم من GitHub Actions فقط (workflow: android-release.yml) لبناء
// ملف فرق (patch) تزايدي بين إصدار الـ APK القديم والجديد باستخدام خوارزمية
// bsdiff، بحيث يحمّل المستخدم هذا الملف الصغير فقط بدل التطبيق كاملاً.
//
// الاستخدام:
//   dart run tool/build_patch.dart <old.apk> <new.apk> <patch-output-path>
//
// يطبع على stdout سطراً واحداً بصيغة JSON يحوي حجم الفرق ونسبة التوفير،
 // حتى تستطيع خطوة الـ CI قراءته إن احتاجت ذلك.
import 'dart:convert';
import 'dart:io';

import 'package:binary_patch/binary_patch.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/build_patch.dart <old.apk> <new.apk> <patch-output-path>',
    );
    exit(64);
  }

  final oldPath = args[0];
  final newPath = args[1];
  final outputPath = args[2];

  final oldFile = File(oldPath);
  final newFile = File(newPath);

  if (!await oldFile.exists()) {
    stderr.writeln('Old APK not found: $oldPath');
    exit(1);
  }
  if (!await newFile.exists()) {
    stderr.writeln('New APK not found: $newPath');
    exit(1);
  }

  try {
    final result = await BinaryPatch.create(
      oldFile: oldPath,
      newFile: newPath,
      outputPatch: outputPath,
      options: PatchOptions.balanced(),
    );

    stdout.writeln(
      jsonEncode({
        'ok': true,
        'patchPath': outputPath,
        'summary': result.summary,
      }),
    );
  } catch (error) {
    // أي فشل في بناء الفرق (مثلاً أول إصدار بدون نسخة سابقة، أو خطأ غير
    // متوقع) لا يجب أن يوقف عملية الإصدار؛ نكتفي بالإبلاغ ونترك الـ CI
    // يتابع بدون ملف فرق لهذا الإصدار (سيستخدم المستخدمون التحميل الكامل).
    stdout.writeln(jsonEncode({'ok': false, 'error': error.toString()}));
    exit(0);
  }
}
