import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/catalog_data.dart';
import '../theme/app_theme.dart';

class AccessoriesScreen extends StatefulWidget {
  const AccessoriesScreen({super.key});
  @override State<AccessoriesScreen> createState()=>_AccessoriesScreenState();
}
class _AccessoriesScreenState extends State<AccessoriesScreen>{
  List<Map<String,dynamic>> _items=[]; bool _loading=true; String _q='',_cat='الكل',_city='الكل';
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=await Supabase.instance.client.from('accessories').select('*').eq('status','active').order('created_at',ascending:false);if(mounted)setState(()=>_items=List<Map<String,dynamic>>.from(rows));}catch(_){}
    if(mounted)setState(()=>_loading=false);
  }
  Future<void> _add()async{
    final uid=Supabase.instance.client.auth.currentUser?.id;
    if(uid==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('سجّل الدخول أولاً')));return;}
    final title=TextEditingController(),price=TextEditingController(),desc=TextEditingController();
    String cat='جرابات',city=CatalogData.cities.first; final images=<XFile>[];
    await showDialog(context:context,builder:(d)=>StatefulBuilder(builder:(d,setDialog)=>AlertDialog(
      title:const Text('نشر إكسسوار'),
      content:SingleChildScrollView(child:Column(children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'العنوان')),
        DropdownButtonFormField<String>(value:cat,items:['جرابات','شواحن','شاشات','قطع غيار أخرى'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setDialog(()=>cat=v);}),
        TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعر')),
        DropdownButtonFormField<String>(value:city,items:CatalogData.cities.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setDialog(()=>city=v);}),
        TextField(controller:desc,maxLines:3,decoration:const InputDecoration(labelText:'الوصف')),
        OutlinedButton.icon(onPressed:()async{final p=await ImagePicker().pickMultiImage(imageQuality:80,maxWidth:1600);images..clear()..addAll(p.take(5));setDialog((){});},icon:const Icon(Icons.image),label:Text('الصور: ${images.length}')),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d),child:const Text('إلغاء')),
        ElevatedButton(onPressed:()async{
          if(title.text.trim().isEmpty)return;
          final urls=<String>[];
          for(var i=0;i<images.length;i++){
            final path=uid+'/accessory_'+DateTime.now().millisecondsSinceEpoch.toString()+'_'+i.toString()+'.jpg';
            await Supabase.instance.client.storage.from('listing-images').uploadBinary(path,await images[i].readAsBytes(),fileOptions:const FileOptions(contentType:'image/jpeg'));
            urls.add(Supabase.instance.client.storage.from('listing-images').getPublicUrl(path));
          }
          await Supabase.instance.client.from('accessories').insert({'seller_id':uid,'title':title.text.trim(),'category':cat,'price':int.tryParse(price.text.trim())??0,'city':city,'description':desc.text.trim(),'image_urls':urls,'status':'pending_review'});
          if(d.mounted)Navigator.pop(d);_load();
        },child:const Text('نشر')),
      ],
    )));
    title.dispose();price.dispose();desc.dispose();
  }
  @override Widget build(BuildContext context){
    final filtered=_items.where((x)=>x['title'].toString().toLowerCase().contains(_q)&&(_cat=='الكل'||x['category']==_cat)&&(_city=='الكل'||x['city']==_city)).toList();
    return Scaffold(appBar:AppBar(title:const Text('إكسسوارات'),actions:[IconButton(onPressed:_add,icon:const Icon(Icons.add))]),body:Column(children:[
      Padding(padding:const EdgeInsets.all(10),child:TextField(onChanged:(v)=>setState(()=>_q=v.toLowerCase()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'بحث'))),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        DropdownButton<String>(value:_cat,items:['الكل','جرابات','شواحن','شاشات','قطع غيار أخرى'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>_cat=v);}),
        const SizedBox(width:12),
        DropdownButton<String>(value:_city,items:['الكل',...CatalogData.cities].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setState(()=>_city=v);}),
      ])),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator(color:AppColors.gold)):filtered.isEmpty?const Center(child:Text('لا توجد إكسسوارات')):ListView.builder(itemCount:filtered.length,itemBuilder:(_,i){final x=filtered[i],imgs=x['image_urls'];return Card(child:ListTile(leading:imgs is List&&imgs.isNotEmpty?Image.network(imgs.first,width:60,height:60,fit:BoxFit.cover):const Icon(Icons.inventory_2_outlined,color:AppColors.gold),title:Text(x['title']),subtitle:Text(x['city'].toString()),trailing:Text('${x['price']} ج.س',style:const TextStyle(color:AppColors.gold,fontWeight:FontWeight.bold))));})),
    ]));
  }
}
