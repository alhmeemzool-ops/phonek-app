import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/friendly_error.dart';

class InviteFriendScreen extends StatefulWidget {
  const InviteFriendScreen({super.key});
  @override State<InviteFriendScreen> createState()=>_InviteFriendScreenState();
}
class _InviteFriendScreenState extends State<InviteFriendScreen>{
  final _controller=TextEditingController();
  bool _loading=true,_redeeming=false; String? _code; int _friends=0,_days=0;
  Future<void> _load() async {
    try {
      final db=Supabase.instance.client;
      final code=await db.rpc('get_or_create_invite_code');
      final uid=context.read<AppState>().currentUser!.id;
      final refs=await db.from('referrals').select('invitee_id').eq('inviter_id',uid);
      final credit=await db.from('feature_credits').select('days_available').eq('user_id',uid).maybeSingle();
      if(mounted)setState((){_code=code.toString();_friends=(refs as List).length;_days=(credit?['days_available'] as num?)?.toInt()??0;});
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyError(e,fallback:'تعذر تحميل الدعوة.'))));}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _redeem() async {
    final code=_controller.text.trim(); if(code.isEmpty)return; setState(()=>_redeeming=true);
    try{await Supabase.instance.client.rpc('redeem_invite_code',params:{'p_code':code});_controller.clear();if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم استخدام كود الصديق.')));await _load();}}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyError(e,fallback:'تعذر استخدام الكود.'))));}
    finally{if(mounted)setState(()=>_redeeming=false);}
  }
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_){_load();});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('ادعُ صديقاً')),body:_loading?const Center(child:CircularProgressIndicator(color:AppColors.gold)):ListView(padding:const EdgeInsets.all(16),children:[
    Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[const Text('كود دعوتك',style:TextStyle(color:AppColors.textSecondary)),const SizedBox(height:8),Text(_code??'—',style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:AppColors.gold)),const SizedBox(height:12),ElevatedButton.icon(onPressed:_code==null?null:()=>Share.share('انضم إلى فونك باستخدام كود الدعوة: $_code'),icon:const Icon(Icons.share),label:const Text('مشاركة الكود'))]))),
    const SizedBox(height:12),Text('الأصدقاء المسجلون: $_friends'),Text('أيام التمييز المتاحة: $_days'),
    const SizedBox(height:16),
    OutlinedButton.icon(
      onPressed: _days < 1 ? null : () async {
        final state = context.read<AppState>();
        if (state.isOffline) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن استخدام التمييز بدون اتصال بالإنترنت')));
          return;
        }
        final listings = state.listings.where((x) => x.seller.id == state.currentUser?.id && x.status.name == 'active').toList();
        if (listings.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد إعلان نشط لتمييزه')));
          return;
        }
        final selected = await showDialog<String>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('اختر إعلاناً لتمييزه 24 ساعة'),
            content: SizedBox(width: 360, child: ListView(shrinkWrap: true, children: listings.map((x) => ListTile(title: Text(x.title), subtitle: Text(x.city), onTap: () => Navigator.pop(d, x.id))).toList())),
          ),
        );
        if (selected == null) return;
        try {
          await Supabase.instance.client.rpc('use_feature_credit', params: {'p_listing_id': selected});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تمييز الإعلان لمدة 24 ساعة')));
            await _load();
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: 'تعذر استخدام رصيد التمييز.'))));
        }
      },
      icon: const Icon(Icons.rocket_launch_outlined),
      label: const Text('استخدم يوم تمييز لإعلان'),
    ),
    const SizedBox(height:24),const Text('عندي كود صديق',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),
    TextField(controller:_controller,decoration:const InputDecoration(hintText:'أدخل الكود')),const SizedBox(height:10),
    ElevatedButton(onPressed:_redeeming?null:_redeem,child:Text(_redeeming?'جارٍ التحقق...':'استخدام الكود')),
  ]));
}
