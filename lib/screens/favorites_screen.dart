import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'phone_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final favorites = appState.listings.where((p) => appState.isFavorite(p.id)).toList();

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
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: p.imageUrls.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: p.imageUrls.first,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const _FavoriteImagePlaceholder(),
                                  placeholder: (context, url) => const _FavoriteImagePlaceholder(),
                                )
                              : const _FavoriteImagePlaceholder(),
                        ),
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

class _FavoriteImagePlaceholder extends StatelessWidget {
  const _FavoriteImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2A2A2A),
      child: Icon(Icons.phone_android_rounded, color: Colors.white38),
    );
  }
}
