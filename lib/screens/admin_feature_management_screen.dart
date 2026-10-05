import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/friendly_error.dart';

class AdminFeatureManagementScreen extends StatefulWidget{
  const AdminFeatureManagementScreen({super.key,this.section});
  final String? section;
  @override State<AdminFeatureManagementScreen> createState()=>_AdminFeatureManagementScreenState();
}
class _AdminFeatureManagementScreenState extends State<AdminFeatureManagementScreen>{
  List<Map<String,dynamic>> accessories=[],subs=[],shops=[]; bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final a=await Supabase.instance.client.from('accessories').select('*').eq('status','pending_review').order('created_at',ascending:false);
      final s=await Supabase.instance.client.from('shop_subscriptions').select('*').inFilter('status',['pending','active']).order('requested_at',ascending:false);
      final r=await Supabase.instance.client.from('repair_shops').select('*').order('created_at',ascending:false);
      if(mounted)setState(() { accessories=List<Map<String,dynamic>>.from(a); subs=List<Map<String,dynamic>>.from(s); shops=List<Map<String,dynamic>>.from(r); });
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyError(e,fallback:'تعذر تحميل إدارة الميزات.'))));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _accessory(Map<String,dynamic>x,bool ok)async{await Supabase.instance.client.from('accessories').update({'status':ok?'active':'rejected'}).eq('id',x['id']);_load();}
  Future<void> _sub(Map<String,dynamic>x,bool approve)async{
    final active=x['status']=='active';
    final data=active
      ? {'status':'ended','reviewed_by':Supabase.instance.client.auth.currentUser!.id}
      : {'status':approve?'active':'rejected','starts_at':approve?DateTime.now().toUtc().toIso8601String():null,'ends_at':approve?DateTime.now().toUtc().add(const Duration(days:30)).toIso8601String():null,'reviewed_by':Supabase.instance.client.auth.currentUser!.id};
    await Supabase.instance.client.from('shop_subscriptions').update(data).eq('id',x['id']);_load();
  }
  Future<void> _proof(String path)async{final url=await Supabase.instance.client.storage.from('subscription-proofs').createSignedUrl(path,3600);final uri=Uri.tryParse(url);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);}
  Future<void> _shopDialog({Map<String,dynamic>? x})async{
    final name=TextEditingController(text:x?['name']?.toString()),city=TextEditingController(text:x?['city']?.toString()),address=TextEditingController(text:x?['address']?.toString()),phone=TextEditingController(text:x?['phone']?.toString()),hours=TextEditingController(text:x?['working_hours']?.toString()),services=TextEditingController(text:x?['services']?.toString());
    await showDialog(context:context,builder:(d)=>AlertDialog(title:Text(x==null?'إضافة محل صيانة':'تعديل محل صيانة'),content:SingleChildScrollView(child:Column(children:[TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),TextField(controller:city,decoration:const InputDecoration(labelText:'المدينة')),TextField(controller:address,decoration:const InputDecoration(labelText:'العنوان')),TextField(controller:phone,decoration:const InputDecoration(labelText:'الهاتف')),TextField(controller:hours,decoration:const InputDecoration(labelText:'ساعات العمل')),TextField(controller:services,decoration:const InputDecoration(labelText:'الخدمات'))])),actions:[ElevatedButton(onPressed:()async{final data={'name':name.text,'city':city.text,'address':address.text,'phone':phone.text,'working_hours':hours.text,'services':services.text};if(x==null)await Supabase.instance.client.from('repair_shops').insert(data);else await Supabase.instance.client.from('repair_shops').update(data).eq('id',x['id']);if(d.mounted)Navigator.pop(d);_load();},child:const Text('حفظ'))]));
  }
  @override Widget build(BuildContext context){
    if(loading)return Scaffold(appBar:AppBar(title:const Text('إدارة الميزات')),body:const Center(child:CircularProgressIndicator(color:AppColors.gold)));
    return Scaffold(appBar:AppBar(title:const Text('إدارة الميزات')),body:ListView(padding:const EdgeInsets.all(12),children:[
      const Text('إكسسوارات بانتظار المراجعة',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      ...accessories.map((x)=>Card(child:ListTile(title:Text(x['title'].toString()),subtitle:Text('${x['price']} ج.س • ${x['city']}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>_accessory(x,false),icon:const Icon(Icons.close)),IconButton(onPressed:()=>_accessory(x,true),icon:const Icon(Icons.check,color:AppColors.success))]))),
      const Divider(),const Text('طلبات اشتراك المعارض',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      ...subs.map((x)=>Card(child:ListTile(title:Text('متجر ${x['shop_id']}'),subtitle:Text('الحالة: ${x['status']}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[
        if(x['payment_proof_path']?.toString().isNotEmpty==true)IconButton(onPressed:()=>_proof(x['payment_proof_path'].toString()),icon:const Icon(Icons.receipt_long,color:AppColors.gold)),
        if(x['status']=='pending')IconButton(onPressed:()=>_sub(x,false),icon:const Icon(Icons.close)),
        if(x['status']=='pending')IconButton(onPressed:()=>_sub(x,true),icon:const Icon(Icons.check,color:AppColors.success)),
        if(x['status']=='active')IconButton(onPressed:()=>_sub(x,false),icon:const Icon(Icons.stop_circle_outlined,color:AppColors.danger)),
      ]))),
      const Divider(),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('محلات الصيانة',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),IconButton(onPressed:()=>_shopDialog(),icon:const Icon(Icons.add,color:AppColors.gold))]),
      ...shops.map((x)=>Card(child:ListTile(title:Text(x['name'].toString()),subtitle:Text('${x['city']} • ${x['phone']}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>_shopDialog(x:x),icon:const Icon(Icons.edit)),IconButton(onPressed:()async{await Supabase.instance.client.from('repair_shops').delete().eq('id',x['id']);_load();},icon:const Icon(Icons.delete_outline))]))),
    ]));
  }
}
