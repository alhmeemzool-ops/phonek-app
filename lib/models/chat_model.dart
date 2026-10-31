import 'dart:async';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      case MessageType.swap:
        return 'swap';
      case MessageType.voice:
        return 'voice';
    }
  }
}


enum MessageType { text, image, location, priceOffer, offer, swap, voice }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final int? offerAmount;
  final Map<String, dynamic>? payload;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.offerAmount,
    this.payload,
  }) {
    _scheduleReceipt();
  }

  void _scheduleReceipt() {
    unawaited(_advanceReceipt());
  }

  Future<void> _advanceReceipt() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null || senderId == currentUserId) return;
      if (status == MessageStatus.read) return;

      // The message has reached this signed-in PhoneK client. Advance the
      // sender's receipt to delivered first so the UI can show the gray
      // double-check before the read receipt is emitted.
      await Supabase.instance.client.rpc(
        'mark_chat_message_delivered',
        params: {'p_message_id': id},
      );

      if (status == MessageStatus.read) return;
      await Future<void>.delayed(const Duration(milliseconds: 700));

      await Supabase.instance.client.rpc(
        'mark_chat_message_read',
        params: {'p_message_id': id},
      );
    } catch (_) {
      // Receipt updates must never block or break the chat UI.
    }
  }

  String get displayText {
    if (type == MessageType.swap) return 'عرض تبديل';
    if (type == MessageType.voice) return 'رسالة صوتية';
    if (type == MessageType.offer && offerAmount != null) {
      return 'عرض سعر: ' + NumberFormat.decimalPattern('en_US').format(offerAmount) + ' ج.س';
    }
    return text;
  }
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
