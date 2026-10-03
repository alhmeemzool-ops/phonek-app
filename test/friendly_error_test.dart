import 'package:flutter_test/flutter_test.dart';
import 'package:phonek_app/utils/friendly_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps duplicate data to an Arabic user message', () {
    final error = PostgrestException(message: 'duplicate key', code: '23505');
    expect(friendlyError(error), 'البيانات موجودة بالفعل.');
  });

  test('maps permission errors without exposing database details', () {
    final error = PostgrestException(message: 'permission denied for table profiles', code: '42501');
    expect(friendlyError(error), 'ليس لديك صلاحية لتنفيذ هذه العملية.');
  });

  test('uses a safe fallback for unknown database errors', () {
    final error = PostgrestException(message: 'internal database detail', code: 'XX000');
    expect(friendlyError(error), 'حدث خطأ غير متوقع. حاول مرة أخرى.');
  });
}
