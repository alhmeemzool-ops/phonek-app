enum MessageStatus { sent, delivered, read }

enum MessageType { text, image, location, priceOffer }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final int? offerAmount; // لرسائل تقديم عرض السعر

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.offerAmount,
  });
}

class ChatThread {
  final String id;
  final String phoneListingId;
  final String phoneTitle;
  final String otherUserName;
  final String? otherUserAvatar;
  final bool otherUserOnline;
  final List<ChatMessage> messages;

  const ChatThread({
    required this.id,
    required this.phoneListingId,
    required this.phoneTitle,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserOnline = false,
    this.messages = const [],
  });

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;
  int get unreadCount => messages.where((m) => m.status != MessageStatus.read && m.senderId != 'me').length;
}
