import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/catalog_data.dart';
import '../theme/app_theme.dart';

class RepairDirectoryScreen extends StatefulWidget{
  const RepairDirectoryScreen({super.key});
  @override State<RepairDirectoryScreen> createState()=>_RepairDirectoryScreenState();
}
class _RepairDirectoryScreenState extends State<RepairDirectoryScreen>{
  List<Map<String,dynamic>> _items=[]; bool _loading=true; String _city='الكل';
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=await Supabase.instance.client.from('repair_shops').select('*,repair_shop_ratings(stars)').order('created_at',ascending:false);if(mounted)setState(()=>_items=List<Map<String,dynamic>>.from(rows));}catch(_){}
    if(mounted)setState(()=>_loading=false);
  }
  Future<void> _rate(Map<String,dynamic>x)async{
    final uid=Supabase.instance.client.auth.currentUser?.id;
    if(uid==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('سجّل الدخول للتقييم')));return;}
    int stars=5;
    await showDialog(context:context,builder:(d)=>AlertDialog(title:const Text('تقييم محل الصيانة'),content:StatefulBuilder(builder:(d,set)=>DropdownButton<int>(value:stars,items:[1,2,3,4,5].map((n)=>DropdownMenuItem(value:n,child:Text('$n نجوم'))).toList(),onChanged:(v){if(v!=null)set(()=>stars=v);})),actions:[ElevatedButton(onPressed:()async{await Supabase.instance.client.from('repair_shop_ratings').upsert({'shop_id':x['id'],'user_id':uid,'stars':stars});if(d.mounted)Navigator.pop(d);_load();},child:const Text('حفظ'))]));
  }
  @override Widget build(BuildContext context){
    final items=_items.where((x)=>_city=='الكل'||x['city']==_city).toList();
    return Scaffold(appBar:AppBar(title:const Text('دليل الصيانة')),body:_loading?const Center(child:CircularProgressIndicator(color:AppColors.gold)):Column(children:[
      Padding(padding:const EdgeInsets.all(10),child:DropdownButton<String>(value:_city,items:['الكل',...CatalogData.cities].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>_city=v);})),
      Expanded(child:ListView.builder(itemCount:items.length,itemBuilder:(_,i){
        final x=items[i],ratings=List<Map<String,dynamic>>.from(x['repair_shop_ratings']??[]);
        final avg=ratings.isEmpty?0.0:ratings.map((r)=>(r['stars'] as num).toDouble()).reduce((a,b)=>a+b)/ratings.length;
        return Card(child:ListTile(title:Text(x['name'].toString()),subtitle:Text('${x['city']} • ${x['address']}\\n${x['working_hours']}\\n${x['services']}'),isThreeLine:true,trailing:Column(mainAxisSize:MainAxisSize.min,children:[Text('★ ${avg.toStringAsFixed(1)}'),Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>launchUrl(Uri(scheme:'tel',path:x['phone'].toString())),icon:const Icon(Icons.call,color:AppColors.gold)),IconButton(onPressed:()=>_rate(x),icon:const Icon(Icons.star_border,color:AppColors.gold))])])));}))
    ]));
  }
}
