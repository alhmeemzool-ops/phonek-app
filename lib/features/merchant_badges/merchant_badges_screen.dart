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
  double _rating = 0;
  bool _identityVerified = false;
  bool _licenseVerified = false;
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

      try {
        final state = await client
            .from('merchant_badge_state')
            .select('current_level, eligible_level, completed_sales, rating, identity_verified, license_verified')
            .eq('profile_id', profileId)
            .maybeSingle();

        if (state != null) {
          _sales = (state['completed_sales'] as num?)?.toInt() ?? 0;
          _level = (state['current_level'] as num?)?.toInt() ?? 0;
          _rating = (state['rating'] as num?)?.toDouble() ?? 0;
          _identityVerified = state['identity_verified'] == true;
          _licenseVerified = state['license_verified'] == true;
        } else {
          _level = 0;
        }
      } catch (_) {
        // Compatibility fallback until migration 005 is applied remotely.
        final row = await client
            .from('profiles')
            .select('id, completed_sales')
            .eq('id', profileId)
            .maybeSingle();
        if (row == null) throw StateError('بيانات المتجر غير موجودة');
        _sales = (row['completed_sales'] as num?)?.toInt() ?? 0;
        _level = _sales > 0 ? levelForSales(_sales) : 0;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _requirementText(MerchantBadge badge) {
    final salesMissing = (badge.requiredSales - _sales).clamp(0, badge.requiredSales);
    final parts = <String>[];
    if (salesMissing > 0) parts.add('$salesMissing طلب ناجح متبقٍ');
    if (badge.requiresLicense && !_licenseVerified) parts.add('توثيق رخصة المحل');
    if (badge.minRating != null && _rating <= badge.minRating!) {
      parts.add('تقييم أعلى من ${badge.minRating!.toStringAsFixed(1)}');
    }
    if (parts.isEmpty) return 'مؤهل لهذا المستوى';
    return parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final nextBadge = _level < merchantBadges.length ? merchantBadges[_level] : null;
    final progress = nextBadge == null
        ? 1.0
        : nextBadge.requiredSales == 0
            ? 1.0
            : (_sales / nextBadge.requiredSales).clamp(0.0, 1.0);

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
                            const SizedBox(height: 12),
                            Row(children: [
                              const Icon(Icons.shopping_bag_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text('الطلبات الناجحة: $_sales'),
                              const Spacer(),
                              if (_rating > 0) Text('التقييم: ${_rating.toStringAsFixed(1)} ★'),
                            ]),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _StatusPill(label: 'الهوية', enabled: _identityVerified),
                              _StatusPill(label: 'الرخصة', enabled: _licenseVerified),
                            ]),
                            if (nextBadge != null) ...[
                              const SizedBox(height: 14),
                              Text('المستوى التالي: ${nextBadge.nameAr}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(_requirementText(nextBadge), style: const TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: progress),
                            ] else ...[
                              const SizedBox(height: 10),
                              const Text('🏆 وصل المتجر إلى أعلى مستوى: تاجر أسطوري.'),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.enabled});
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: enabled ? const Color(0x1A16A34A) : const Color(0x1A64748B),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(enabled ? Icons.verified : Icons.hourglass_empty, size: 14, color: enabled ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text('$label ${enabled ? 'موثق' : 'غير موثق'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}
