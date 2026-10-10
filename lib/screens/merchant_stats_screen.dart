import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/friendly_error.dart';

class MerchantStatsScreen extends StatefulWidget {
  const MerchantStatsScreen({super.key});
  @override
  State<MerchantStatsScreen> createState() => _MerchantStatsScreenState();
}

class _MerchantStatsScreenState extends State<MerchantStatsScreen> {
  int _days = 7;
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final result = await client.rpc('get_merchant_stats', params: {'p_days': _days});
      var rows = List<Map<String, dynamic>>.from(result as List);
      if (rows.isEmpty) {
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          final listings = await client
              .from('listings')
              .select('id,title,view_count')
              .eq('seller_id', uid)
              .limit(5000);
          rows = (listings as List).whereType<Map<String, dynamic>>().map((listing) => {
                'listing_id': listing['id'],
                'listing_title': listing['title'],
                'event_type': 'view',
                'event_count': (listing['view_count'] as num?)?.toInt() ?? 0,
              }).toList();
        }
      }
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error, fallback: 'تعذر تحميل الإحصائيات.'))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int total(String type) => _rows.where((row) => row['event_type'] == type).fold(0, (sum, row) => sum + ((row['event_count'] as num?)?.toInt() ?? 0));
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in _rows) grouped.putIfAbsent(row['listing_id'].toString(), () => []).add(row);
    return Scaffold(
      appBar: AppBar(title: const Text('إحصائيات المتجر')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: SegmentedButton<int>(
          segments: const [ButtonSegment(value: 1, label: Text('اليوم')), ButtonSegment(value: 7, label: Text('7 أيام')), ButtonSegment(value: 30, label: Text('30 يوم'))],
          selected: {_days},
          onSelectionChanged: (value) { _days = value.first; _load(); },
        )),
        Card(margin: const EdgeInsets.symmetric(horizontal: 12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _stat('مشاهدات', total('view')), _stat('مفضلة', total('favorite')), _stat('تواصل', total('contact')),
        ]))),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : grouped.isEmpty
                ? const Center(child: Text('لا توجد إعلانات أو بيانات بعد'))
                : ListView(padding: const EdgeInsets.all(12), children: grouped.entries.map((entry) => Card(child: ListTile(
                    leading: const Icon(Icons.analytics_outlined, color: AppColors.gold),
                    title: Text(entry.value.first['listing_title']?.toString() ?? 'إعلان ${entry.key}'),
                    subtitle: Text(entry.value.map((row) => '${row['event_type']}: ${row['event_count']}').join(' • ')),
                  ))).toList())),
      ]),
    );
  }

  Widget _stat(String title, int value) => Column(children: [Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gold)), Text(title)]);
}
