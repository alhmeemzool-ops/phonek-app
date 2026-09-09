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
      if (user == null && widget.shopId == null) {
        throw StateError('يجب تسجيل الدخول لعرض شارات المتجر');
      }

      final shopId = widget.shopId ?? user!.id;
      final row = await client
          .from('shops')
          .select('id, orders_count, badge_level')
          .eq('id', shopId)
          .maybeSingle();

      if (row != null) {
        _sales = (row['orders_count'] as num?)?.toInt() ?? 0;
        final storedLevel = (row['badge_level'] as num?)?.toInt() ?? 0;
        _level = storedLevel > 0 ? storedLevel : levelForSales(_sales);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextBadge = _level < merchantBadges.length
        ? merchantBadges[_level]
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('شارات المتجر')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'تعذر تحميل الشارات:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'مستوى المتجر',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (_level > 0)
                                    MerchantBadgeChip(level: _level),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$_level / ${merchantBadges.length}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('المبيعات المكتملة: $_sales'),
                              if (nextBadge != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'المتبقي للوصول إلى ${nextBadge.nameAr}: '
                                  '${(nextBadge.requiredSales - _sales).clamp(0, nextBadge.requiredSales)} مبيعات',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: (_sales / nextBadge.requiredSales)
                                      .clamp(0.0, 1.0),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                const Text('وصل المتجر إلى أعلى مستوى.'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'جميع الشارات',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      MerchantBadgeGallery(currentLevel: _level),
                    ],
                  ),
                ),
    );
  }
}
