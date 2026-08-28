import 'package:intl/intl.dart';

class AppFormatters {
  static final _priceFormat = NumberFormat('#,###');

  /// يحوّل 250000 إلى "250,000 ج.س"
  static String priceSDG(int amount) {
    return '${_priceFormat.format(amount)} ج.س';
  }

  /// أول حرف من الاسم لعرضه داخل الأفاتار الدائري (آمن حتى لو كان النص فارغاً)
  static String firstChar(String? name) {
    if (name == null || name.trim().isEmpty) return '؟';
    return name.trim().substring(0, 1);
  }

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
    return DateFormat('yyyy/MM/dd').format(date);
  }
}
