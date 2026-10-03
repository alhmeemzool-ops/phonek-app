import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

String friendlyError(Object error, {String fallback = 'حدث خطأ غير متوقع. حاول مرة أخرى.'}) {
  debugPrint('PhoneK error: $error');
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login') || message.contains('invalid credentials')) {
      return 'بيانات تسجيل الدخول غير صحيحة.';
    }
    if (message.contains('expired') || message.contains('otp')) {
      return 'رمز التحقق غير صحيح أو انتهت صلاحيته.';
    }
    return 'تعذر إكمال عملية الحساب. حاول مرة أخرى.';
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return 'البيانات موجودة بالفعل.';
      case '42501':
        return 'ليس لديك صلاحية لتنفيذ هذه العملية.';
      case '23503':
        return 'لا يمكن تنفيذ العملية بسبب بيانات مرتبطة.';
      default:
        return fallback;
    }
  }
  if (error is TimeoutException) return 'انتهت مهلة الاتصال. تحقق من الإنترنت وحاول مرة أخرى.';
  return fallback;
}
