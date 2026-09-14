import 'package:flutter/material.dart';

import '../../screens/shop_profile_screen.dart';
import 'merchant_catalog_screen.dart';

/// إجراءات إدارة المتجر الخاصة بالتاجر.
/// المعاينة تفتح صفحة المتجر العامة نفسها التي يراها الزائر، وليس لوحة الإدارة.
class MerchantStoreHeaderActions extends StatelessWidget {
  const MerchantStoreHeaderActions({super.key, required this.isMerchant, this.shopId});
  final bool isMerchant;
  final String? shopId;

  @override
  Widget build(BuildContext context) {
    if (!isMerchant) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'إدارة المتجر',
      icon: const Icon(Icons.more_horiz_rounded),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('إدارة الكتالوج'),
                  subtitle: const Text('إضافة وتعديل وتجميد وحذف الإعلانات'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MerchantCatalogScreen(shopId: shopId),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text('معاينة المتجر كزائر'),
                  subtitle: const Text('عرض الصفحة العامة كما يراها الزوار'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (shopId == null || shopId!.trim().isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ShopProfileScreen(shopId: shopId!),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
