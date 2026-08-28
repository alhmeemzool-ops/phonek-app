import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _messages = List.of(widget.thread?.messages ?? []);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'me',
        text: text,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ));
    });
    _controller.clear();
    // ملاحظة: عند ربط Firestore، هنا تُرسل الرسالة فعلياً وتصل بالوقت الحقيقي للطرف الآخر.
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
            child: _messages.isEmpty
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
    final isMe = m.senderId == 'me';
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
              onPressed: () {
                setState(() {
                  _messages.add(ChatMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    senderId: 'me',
                    text: 'تم إرسال الموقع الجغرافي 📍',
                    type: MessageType.location,
                    timestamp: DateTime.now(),
                  ));
                });
              },
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
