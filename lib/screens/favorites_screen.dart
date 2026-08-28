import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'phone_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final favorites = MockData.listings.where((p) => appState.isFavorite(p.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: favorites.isEmpty
          ? const Center(
              child: Text('لا توجد أجهزة في المفضلة بعد', style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = favorites[index];
                return Dismissible(
                  key: ValueKey(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => appState.toggleFavorite(p.id),
                  child: Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: p)),
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.phone_android, color: Colors.white24),
                      ),
                      title: Text(p.title),
                      subtitle: Text(AppFormatters.priceSDG(p.price), style: const TextStyle(color: AppColors.gold)),
                      trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
