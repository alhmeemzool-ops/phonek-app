import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/friendly_error.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../data/app_state.dart';
import '../models/chat_model.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ChatScreen extends StatefulWidget {
  final PhoneListing listing;
  final ChatThread? thread;
  const ChatScreen({super.key, required this.listing, this.thread});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  String? _threadId;
  bool _loading = true;
  RealtimeChannel? _channel;
  final AudioRecorder _recorder=AudioRecorder();
  final AudioPlayer _player=AudioPlayer();
  Timer? _recordTimer;
  bool _recording=false; int _recordSeconds=0; String? _recordedPath; int _recordedDuration=0; String? _playingMessageId;

  @override
  void initState() {
    super.initState();
    _messages = List.of(widget.thread?.messages ?? []);
    _threadId = widget.thread?.id;
    _initialize();
  }

  Future<void> _initialize() async {
    final appState = context.read<AppState>();
    try {
      _threadId ??= await appState.ensureChatThread(widget.listing);
      final messages = await appState.loadMessages(_threadId!);
      _channel = appState.subscribeToMessages(_threadId!, (message) {
        if (!mounted) return;
        setState(() {
          final index = _messages.indexWhere((item) => item.id == message.id);
          if (index >= 0) { _messages[index] = message; } else { _messages.add(message); }
        });
        _scrollToBottom();
      });
      if (mounted) setState(() { _messages = messages; _loading = false; });
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error, fallback: 'تعذر تحميل المحادثة.'))));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error, fallback: 'تعذر تحميل المحادثة.'))));
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _threadId == null) return;
    final appState = context.read<AppState>();
    _controller.clear();
    try {
      await appState.sendMessage(threadId: _threadId!, text: text);
      final messages = await appState.loadMessages(_threadId!);
      if (mounted) {
        setState(() => _messages = messages);
        _scrollToBottom();
      }
    } on AuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } on PostgrestException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error, fallback: 'تعذر إرسال الرسالة.'))));
    }
  }

  Future<void> _toggleRecording() async {
    if(_recording){await _stopRecording();return;}
    if(!await _recorder.hasPermission()){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا يمكن التسجيل بدون إذن الميكروفون')));return;}
    final dir=await getTemporaryDirectory();final uid=context.read<AppState>().currentUser!.id;final path=dir.path+'/phonek_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder:AudioEncoder.aacLc,bitRate:128000,sampleRate:44100), path: path);
    setState(() {});
    _recording=true;_recordSeconds=0;_recordTimer=Timer.periodic(const Duration(seconds:1),(t){if(!mounted)return;setState(()=>_recordSeconds++);if(_recordSeconds>=120)_stopRecording();});setState(() {});
  }
  Future<void> _stopRecording() async {
    if(!_recording)return;_recordTimer?.cancel();final path=await _recorder.stop();_recording=false;
    if(path==null||_recordSeconds<1){_recordedPath=null;_recordedDuration=0;}else{_recordedPath=path;_recordedDuration=_recordSeconds;}if(mounted)setState(() {});
  }
  Future<void> _cancelRecording() async {if(_recording){_recordTimer?.cancel();await _recorder.cancel();}_recording=false;_recordedPath=null;_recordedDuration=0;if(mounted)setState(() {});}
  Future<void> _sendRecordedVoice() async {
    if(_recordedPath==null||_threadId==null)return;final uid=context.read<AppState>().currentUser!.id;final path='${_threadId!}/${uid}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try{await Supabase.instance.client.storage.from('chat-voice').uploadBinary(path,await File(_recordedPath!).readAsBytes(),fileOptions:const FileOptions(contentType:'audio/mp4',upsert:false));await context.read<AppState>().sendVoice(threadId:_threadId!,path:path,durationSeconds:_recordedDuration);_recordedPath=null;_recordedDuration=0;final messages=await context.read<AppState>().loadMessages(_threadId!);if(mounted)setState(()=>_messages=messages);}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyError(e,fallback:'تعذر إرسال الرسالة الصوتية.'))));}
  }
  String _duration(int seconds)=>'${(seconds~/60).toString().padLeft(2,'0')}:${(seconds%60).toString().padLeft(2,'0')}';
  Future<void> _playVoice(ChatMessage m) async {
    final path=m.payload?['path']?.toString();if(path==null)return;
    if(_playingMessageId==m.id){await _player.stop();if(mounted)setState(()=>_playingMessageId=null);return;}
    try{final url=await Supabase.instance.client.storage.from('chat-voice').createSignedUrl(path,3600);_playingMessageId=m.id;if(mounted)setState(() {});await _player.play(UrlSource(url));_player.onPlayerComplete.listen((_){if(mounted)setState(()=>_playingMessageId=null);});}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyError(e,fallback:'تعذر تشغيل الرسالة الصوتية.'))));}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.thread?.otherUserName ?? widget.listing.seller.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(widget.listing.title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.surfaceLight,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Text(
              'التقِ بالبائع في مكان عام ونهاري، ولا تدفع قبل المعاينة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : _messages.isEmpty
                    ? const Center(child: Text('ابدأ المحادثة الآن', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildBubble(_messages[index]),
                  ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage m) {
    final isMe = m.senderId == context.read<AppState>().currentUser?.id;
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMe ? AppColors.gold : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if(m.type==MessageType.swap) _swapCard(m,isMe) else if(m.type==MessageType.voice) ...[
              Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>_playVoice(m),icon:Icon(_playingMessageId==m.id?Icons.pause_circle:Icons.play_circle)),Text(_duration((m.payload?['duration_seconds'] as num?)?.toInt()??0))]),
            ] else Text(m.displayText, style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 15, height: 1.45)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppFormatters.timeAgo(m.timestamp),
                  style: TextStyle(fontSize: 11, color: isMe ? Colors.black54 : AppColors.textSecondary),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    m.status == MessageStatus.read ? Icons.done_all : Icons.done,
                    size: 12,
                    color: m.status == MessageStatus.read ? Colors.blue[800] : Colors.black45,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _swapCard(ChatMessage m,bool isMe) {
    final p=m.payload??{};final status=p['status']?.toString()??'pending';final sellerIsCurrent=context.read<AppState>().currentUser?.id==widget.listing.seller.id;
    final statusText=status=='accepted'?'تم القبول':status=='rejected'?'تم الرفض':'بانتظار الرد';
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('عرض تبديل',style:TextStyle(fontWeight:FontWeight.bold)),
      Text('الموديل: '+(p['model']?.toString()??'—')),Text('الحالة: '+(p['condition']?.toString()??'—')),
      Text((p['diff_amount']??0).toString()=='0'?'بدون فرق':(p['diff_direction']=='pay'?'أدفع الفرق: ':'أطلب الفرق: ')+(p['diff_amount']??0).toString()+' ج.س'),
      const SizedBox(height:4),Text(statusText,style:const TextStyle(color:AppColors.gold,fontWeight:FontWeight.bold)),
      if(sellerIsCurrent&&status=='pending')Row(children:[TextButton(onPressed:()=>_respondSwap(m,true),child:const Text('قبول')),TextButton(onPressed:()=>_respondSwap(m,false),child:const Text('رفض'))]),
    ]);
  }
  Future<void> _respondSwap(ChatMessage m,bool accept) async {
    try{await Supabase.instance.client.rpc('respond_to_swap',params:{'p_message_id':m.id,'p_accept':accept});final messages=await context.read<AppState>().loadMessages(_threadId!);if(mounted)setState(()=>_messages=messages);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(friendlyError(e,fallback:'تعذر تحديث عرض التبديل.'))));}
  }

  Widget _composer() {
    const quick = ['متاح؟', 'آخر سعر؟', 'وين الموقع؟'];
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_loading)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: quick.map((text) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    label: Text(text),
                    onPressed: _threadId == null ? null : () async {
                      await context.read<AppState>().sendMessage(threadId: _threadId!, text: text);
                      final messages = await context.read<AppState>().loadMessages(_threadId!);
                      if (mounted) setState(() => _messages = messages);
                    },
                  ),
                )).toList(),
              ),
            ),
          if (_recording || _recordedPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                if (_recording) const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                Text(_duration(_recordSeconds)),
                const Spacer(),
                IconButton(onPressed: _cancelRecording, icon: const Icon(Icons.close)),
                if (!_recording) IconButton(onPressed: _sendRecordedVoice, icon: const Icon(Icons.send, color: AppColors.gold)),
              ]),
            ),
          if (!_recording && _recordedPath == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.location_on_outlined, color: AppColors.gold),
                  onPressed: _threadId == null ? null : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إرسال الموقع سيُفعّل بعد إضافة صلاحية الموقع'))),
                ),
                IconButton(onPressed: _toggleRecording, icon: const Icon(Icons.mic, color: AppColors.gold)),
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'اكتب رسالتك...'), onSubmitted: (_) => _send())),
                const SizedBox(width: 6),
                CircleAvatar(backgroundColor: AppColors.gold, child: IconButton(icon: const Icon(Icons.send, color: Colors.black, size: 18), onPressed: _send)),
              ]),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    _controller.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
