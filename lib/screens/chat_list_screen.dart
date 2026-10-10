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
      appBar: AppBar(
        title: const Text('المحادثات', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: appState.loadChatThreads, icon: const Icon(Icons.refresh), tooltip: 'تحديث')],
      ),
      body: threads.isEmpty
          ? RefreshIndicator(
              onRefresh: appState.loadChatThreads,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                SizedBox(height: 150),
                Icon(Icons.forum_outlined, size: 64, color: AppColors.gold),
                SizedBox(height: 16),
                Center(child: Text('لا توجد محادثات بعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                SizedBox(height: 6),
                Center(child: Text('ابدأ محادثة من صفحة أي إعلان', style: TextStyle(color: AppColors.textSecondary))),
              ]),
            )
          : RefreshIndicator(
              onRefresh: appState.loadChatThreads,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: threads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  final last = thread.lastMessage;
                  final unread = thread.unreadCount;
                  return Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openThread(context, appState, thread),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          Stack(children: [
                            CircleAvatar(radius: 27, backgroundColor: AppColors.surfaceLight, child: Text(AppFormatters.firstChar(thread.otherUserName), style: const TextStyle(color: AppColors.gold, fontSize: 19, fontWeight: FontWeight.w800))),
                            if (thread.otherUserOnline) Positioned(bottom: 1, right: 1, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 2)))),
                          ]),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Expanded(child: Text(thread.otherUserName, style: const TextStyle(fontWeight: FontWeight.w800))), if (last != null) Text(AppFormatters.timeAgo(last.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]),
                            const SizedBox(height: 5),
                            Text(thread.phoneTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(last?.displayText ?? 'ابدأ المحادثة الآن', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? Colors.white : AppColors.textSecondary, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.normal)),
                          ])),
                          if (unread > 0) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle), child: Text('$unread', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)))],
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _openThread(BuildContext context, AppState appState, dynamic thread) {
    final matches = appState.listings.where((listing) => listing.id == thread.phoneListingId).toList();
    final listing = matches.isEmpty ? null : matches.first;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(listing: listing, thread: thread)));
  }
}
