enum MessageStatus { sent, delivered, read }

extension MessageStatusValue on MessageStatus {
  /// نص مطابق لاسم القيمة، بدون الاعتماد على getter المدمج name.
  String get value {
    switch (this) {
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.read:
        return 'read';
    }
  }
}

extension MessageTypeValue on MessageType {
  String get value {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.location:
        return 'location';
      case MessageType.priceOffer:
        return 'priceOffer';
      case MessageType.offer:
        return 'offer';
    }
  }
}


enum MessageType { text, image, location, priceOffer, offer }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final int? offerAmount;

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
