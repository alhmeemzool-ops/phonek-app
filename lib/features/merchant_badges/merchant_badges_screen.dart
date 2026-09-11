import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'badge_model.dart';
import 'badge_widgets.dart';

class MerchantBadgesScreen extends StatefulWidget {
  const MerchantBadgesScreen({super.key, this.shopId});

  final String? shopId;

  @override
  State<MerchantBadgesScreen> createState() => _MerchantBadgesScreenState();
}

class _MerchantBadgesScreenState extends State<MerchantBadgesScreen> {
  bool _loading = true;
  int _sales = 0;
  int _level = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final profileId = widget.shopId ?? user?.id;
      if (profileId == null) throw StateError('يجب تسجيل الدخول لعرض شارات المتجر');

      // ShopAccountScreen stores merchant data in profiles. Keep the badge
      // system on the same source of truth instead of querying a separate,
      // undocumented shops table.
      final row = await client
          .from('profiles')
          .select('id, completed_sales')
          .eq('id', profileId)
          .maybeSingle();

      if (row == null) throw StateError('بيانات المتجر غير موجودة');
      _sales = (row['completed_sales'] as num?)?.toInt() ?? 0;
      _level = levelForSales(_sales).clamp(0, merchantBadges.length);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextBadge = _level < merchantBadges.length ? merchantBadges[_level] : null;
    return Scaffold(
      appBar: AppBar(title: const Text('شارات المتجر')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل الشارات:\n$_error', textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Expanded(child: Text('مستوى المتجر', style: TextStyle(color: AppColors.textSecondary))),
                              if (_level > 0) MerchantBadgeChip(level: _level),
                            ]),
                            const SizedBox(height: 6),
                            Text('$_level / ${merchantBadges.length}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 14),
                            Text('المبيعات المكتملة: $_sales'),
                            if (nextBadge != null) ...[
                              const SizedBox(height: 8),
                              Text('المتبقي للوصول إلى ${nextBadge.nameAr}: ${(nextBadge.requiredSales - _sales).clamp(0, nextBadge.requiredSales)} مبيعات', style: const TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: (_sales / nextBadge.requiredSales).clamp(0.0, 1.0)),
                            ] else ...[
                              const SizedBox(height: 8),
                              const Text('وصل المتجر إلى أعلى مستوى.'),
                            ],
                          ]),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('جميع الشارات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      MerchantBadgeGallery(currentLevel: _level),
                    ],
                  ),
                ),
    );
  }
}
