import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/friendly_error.dart';

class MerchantStatsScreen extends StatefulWidget{
  const MerchantStatsScreen({super.key});
  @override State<MerchantStatsScreen> createState()=>_MerchantStatsScreenState();
}
class _MerchantStatsScreenState extends State<MerchantStatsScreen>{
  int _days=7; bool _loading=true; List<Map<String,dynamic>> _rows=[];
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    setState(()=>_loading=true);
    try{final rows=await Supabase.instance.client.rpc('get_merchant_stats',params:{'p_days':_days});if(mounted)setState(()=>_rows=List<Map<String,dynamic>>.from(rows));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyError(e,fallback:'تعذر تحميل الإحصائيات.'))));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  @override Widget build(BuildContext context) {
    int total(String t) => _rows.where((x) => x['event_type'] == t).fold(0, (s, x) => s + (x['event_count'] as num).toInt());
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final x in _rows) { grouped.putIfAbsent(x['listing_id'].toString(), () => []).add(x); }
    final cards = <Widget>[];
    for (final e in grouped.entries) {
      cards.add(Card(child: ListTile(
        title: Text('إعلان '+e.key),
        subtitle: Text(e.value.map((x) => x['event_type'].toString()+': '+x['event_count'].toString()).join(' • ')),
      )));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إحصائيات المتجر')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('اليوم')),
            ButtonSegment(value: 7, label: Text('7 أيام')),
            ButtonSegment(value: 30, label: Text('30 يوم')),
          ],
          selected: {_days},
          onSelectionChanged: (v) { _days = v.first; _load(); },
        )),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _stat('مشاهدات', total('view')), _stat('مفضلة', total('favorite')), _stat('تواصل', total('contact')),
        ]),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.gold)) : cards.isEmpty ? const Center(child: Text('لا توجد بيانات')) : ListView(children: cards)),
      ]),
    );
  }

  Widget _stat(String t,int n)=>Column(children:[Text(n.toString(),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:AppColors.gold)),Text(t)]);
}
