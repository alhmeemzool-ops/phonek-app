import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override State<NotificationSettingsScreen> createState()=>_NotificationSettingsScreenState();
}
class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>{
  bool messages=true,offers=true,listings=true,system=true,loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    final u=Supabase.instance.client.auth.currentUser;
    if(u==null){if(mounted)setState(()=>loading=false);return;}
    try{
      final r=await Supabase.instance.client.from('notification_preferences').select().eq('user_id',u.id).maybeSingle();
      if(r!=null&&mounted)setState((){messages=r['messages']??true;offers=r['offers']??true;listings=r['listings']??true;system=r['system']??true;});
    }catch(e){debugPrint('PhoneK notification prefs failed: $e');}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> _set(String key,bool value) async {
    setState((){if(key=='messages')messages=value;if(key=='offers')offers=value;if(key=='listings')listings=value;if(key=='system')system=value;});
    try{
      final u=Supabase.instance.client.auth.currentUser;if(u==null)return;
      await Supabase.instance.client.from('notification_preferences').upsert({'user_id':u.id,'messages':messages,'offers':offers,'listings':listings,'system':system,'updated_at':DateTime.now().toUtc().toIso8601String()});
      await NotificationService.setEnabled(messages||offers||listings||system);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ الإعداد: $e')));}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('إعدادات الإشعارات')),body:loading?const Center(child:CircularProgressIndicator()):ListView(children:[
    SwitchListTile(title:const Text('الرسائل'),subtitle:const Text('تنبيه عند وصول رسالة'),value:messages,onChanged:(v)=>_set('messages',v)),
    SwitchListTile(title:const Text('العروض'),subtitle:const Text('تنبيه عند وصول عرض شراء'),value:offers,onChanged:(v)=>_set('offers',v)),
    SwitchListTile(title:const Text('الإعلانات'),subtitle:const Text('تنبيهات الإعلانات'),value:listings,onChanged:(v)=>_set('listings',v)),
    SwitchListTile(title:const Text('النظام'),subtitle:const Text('التنبيهات العامة المهمة'),value:system,onChanged:(v)=>_set('system',v)),
  ]); 
}