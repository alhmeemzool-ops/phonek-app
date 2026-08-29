import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        if (!mounted || _messages.any((item) => item.id == message.id)) return;
        setState(() => _messages.add(message));
        _scrollToBottom();
      });
      if (mounted) setState(() { _messages = messages; _loading = false; });
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل المحادثة: ${error.message}')));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: ${error.message}')));
    }
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
            Text(widget.thread?.otherUserName ?? widget.listing.seller.name, style: const TextStyle(fontSize: 15)),
            Text(widget.listing.title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? AppColors.gold : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text, style: TextStyle(color: isMe ? Colors.black : Colors.white)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppFormatters.timeAgo(m.timestamp),
                  style: TextStyle(fontSize: 9, color: isMe ? Colors.black54 : AppColors.textSecondary),
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

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.location_on_outlined, color: AppColors.gold),
              onPressed: _threadId == null
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('إرسال الموقع سيُفعّل بعد إضافة صلاحية الموقع')),
                      ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'اكتب رسالتك...'),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              backgroundColor: AppColors.gold,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.black, size: 18),
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
