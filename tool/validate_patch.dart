import 'dart:io';

import 'package:binary_patch/binary_patch.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/validate_patch.dart <old.apk> <patch.bin> <output.apk>',
    );
    exit(64);
  }

  try {
    final result = await BinaryPatch.apply(
      oldFile: args[0],
      patchFile: args[1],
      outputFile: args[2],
      verifyChecksum: true,
    );

    stdout.writeln('Patch applied successfully: ${result.outputPath}');
  } catch (error, stackTrace) {
    stderr.writeln('Patch validation failed: $error');
    stderr.writeln(stackTrace);
    exit(1);
  }
}
