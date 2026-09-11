import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_card.dart';
import 'phone_details_screen.dart';

/// Shows the user's currently active listings loaded from Supabase.
/// Pending/rejected/sold management will be added with the moderation CRUD layer.
class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final userId = state.currentUser?.id;
    final listings = userId == null
        ? const []
        : state.listings.where((listing) => listing.seller.id == userId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي')),
      body: RefreshIndicator(
        onRefresh: state.loadListings,
        child: state.isLoadingListings && state.listings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.listingsError != null && state.listings.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 140),
                      const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Center(child: Text('تعذر تحميل إعلاناتك')),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: state.loadListings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ),
                    ],
                  )
                : listings.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 160),
                          Icon(Icons.inventory_2_outlined, size: 52, color: AppColors.textSecondary),
                          SizedBox(height: 12),
                          Center(child: Text('لا توجد لديك إعلانات نشطة حالياً')),
                          SizedBox(height: 6),
                          Center(
                            child: Text(
                              'يمكنك نشر إعلان جديد من زر إضافة إعلان.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: listings.length,
                        itemBuilder: (context, index) {
                          final listing = listings[index];
                          return PhoneCard(
                            listing: listing,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: listing)),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
