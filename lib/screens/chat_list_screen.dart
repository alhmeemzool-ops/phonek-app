import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final threads = appState.chatThreads;

    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات')),
      body: threads.isEmpty
          ? const Center(child: Text('لا توجد محادثات بعد', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = threads[index];
                final last = t.lastMessage;
                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.surfaceLight,
                        child: Text(AppFormatters.firstChar(t.otherUserName), style: const TextStyle(color: AppColors.gold)),
                      ),
                      if (t.otherUserOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(t.otherUserName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${t.phoneTitle} • ${last?.text ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  trailing: last == null
                      ? null
                      : Text(AppFormatters.timeAgo(last.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  onTap: () {
                    final matches = appState.listings.where((p) => p.id == t.phoneListingId).toList();
                    if (matches.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر العثور على الإعلان المرتبط بالمحادثة')),
                      );
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(listing: matches.first, thread: t)));
                  },
                );
              },
            ),
    );
  }
}
