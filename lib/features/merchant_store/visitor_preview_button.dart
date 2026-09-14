import 'package:flutter/material.dart';

/// زر أيقوني للتاجر لمعاينة صفحة المتجر كما يراها الزائر.
/// لا يظهر أي نص على الزر، ويُستخدم داخل واجهة التاجر فقط.
class MerchantVisitorPreviewButton extends StatelessWidget {
  const MerchantVisitorPreviewButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'معاينة المتجر كزائر',
      onPressed: onPressed,
      icon: const Icon(Icons.visibility_outlined),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}
