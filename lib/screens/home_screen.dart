import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'phone_details_screen.dart';
import 'add_phone_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'chat_list_screen.dart';
import 'phone_requests_screen.dart';

enum SortOption { newest, priceLowHigh, priceHighLow }
enum _FilterType { city, brand, price }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';
  String? _selectedCity;
  String? _selectedBrand;
  SortOption _sortOption = SortOption.newest;
  double? _minPrice;
  double? _maxPrice;
  final TextEditingController _searchController = TextEditingController();

  List<PhoneListing> _filteredListings(List<PhoneListing> source) {
    var list = source.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.brand.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCity = _selectedCity == null || p.city == _selectedCity;
      final matchesBrand = _selectedBrand == null || p.brand == _selectedBrand;
      final matchesPrice = p.priceOnCall ||
          (_minPrice == null || p.price >= _minPrice!) &&
              (_maxPrice == null || p.price <= _maxPrice!);
      return matchesQuery && matchesCity && matchesBrand && matchesPrice && p.status != ListingStatus.sold;
    }).toList();

    switch (_sortOption) {
      case SortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.priceLowHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHighLow:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack يحافظ على حالة كل تبويب (مثل موضع التمرير) عند التنقل بينها
    final pages = [
      _buildHomeBody(),
      const FavoritesScreen(),
      const AddPhoneScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _currentIndex, children: pages)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'المفضلة'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'إضافة هاتف'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'المحادثات'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _buildHomeBody() {
    final appState = context.watch<AppState>();
    final listings = _filteredListings(appState.listings);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: appState.loadListings,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            backgroundColor: AppColors.surface,
            title: const Text('فونك | PhoneK'),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _openFilterSheet(_FilterType.city),
                tooltip: 'الفلاتر',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن هاتف أو ماركة...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildFilterBar()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          if (appState.isLoadingListings && listings.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
            )
          else if (appState.listingsError != null && listings.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _LoadErrorState(
                message: appState.listingsError!,
                onRetry: appState.loadListings,
              ),
            )
          else if (listings.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                query: _searchQuery,
                suggestions: _suggestions(appState.listings),
                onSuggestionTap: (suggestion) {
                  _searchController.text = suggestion;
                  setState(() => _searchQuery = suggestion);
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final phone = listings[index];
                    return _ListingListTile(
                      listing: phone,
                      isFavorite: appState.isFavorite(phone.id),
                      onFavoriteToggle: () => appState.toggleFavorite(phone.id),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: phone)),
                      ),
                    );
                  },
                  childCount: listings.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PhoneRequestsScreen()),
        ),
        icon: const Icon(Icons.campaign_outlined, size: 18),
        label: const Text('لم تجد هاتفك؟ انشر طلب شراء'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تصفية الإعلانات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('المدينة', _selectedCity ?? 'الكل', () => _openFilterSheet(_FilterType.city)),
                  _filterChip('الماركة', _selectedBrand ?? 'الكل', () => _openFilterSheet(_FilterType.brand)),
                  _filterChip('السعر', _priceLabel(), () => _openFilterSheet(_FilterType.price)),
                ],
              ),
            ),
            if (_selectedCity != null || _selectedBrand != null || _minPrice != null || _maxPrice != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _selectedCity = null;
                    _selectedBrand = null;
                    _minPrice = null;
                    _maxPrice = null;
                  }),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('مسح الفلاتر'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ActionChip(
        avatar: const Icon(Icons.tune, size: 16, color: AppColors.gold),
        label: Text('$label: $value'),
        onPressed: onTap,
      ),
    );
  }

  String _priceLabel() {
    if (_minPrice == null && _maxPrice == null) return 'الكل';
    return '${_minPrice == null ? '0' : AppFormatters.priceSDG(_minPrice!.round())} - ${_maxPrice == null ? 'مفتوح' : AppFormatters.priceSDG(_maxPrice!.round())}';
  }

  void _openFilterSheet(_FilterType type) {
    final title = switch (type) {
      _FilterType.city => 'اختر المدينة',
      _FilterType.brand => 'اختر الماركة',
      _FilterType.price => 'حدد نطاق السعر',
    };
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: switch (type) {
          _FilterType.city => _choiceList(ctx, title, 'المدينة', MockData.cities, _selectedCity, (value) {
              setState(() => _selectedCity = value);
              Navigator.pop(ctx);
            }),
          _FilterType.brand => _choiceList(ctx, title, 'الماركة', MockData.brands, _selectedBrand, (value) {
              setState(() => _selectedBrand = value);
              Navigator.pop(ctx);
            }),
          _FilterType.price => _priceFilter(ctx, title),
        },
      ),
    );
  }

  Widget _choiceList(BuildContext ctx, String title, String label, List<String> values, String? selected, ValueChanged<String?> onSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        Text('قائمة $label مستقلة عن بقية الفلاتر', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 14),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(label: const Text('الكل'), selected: selected == null, onSelected: (_) => onSelected(null)),
                ...values.map((value) => ChoiceChip(label: Text(value), selected: selected == value, onSelected: (_) => onSelected(value))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceFilter(BuildContext ctx, String title) {
    return StatefulBuilder(
      builder: (ctx, setSheetState) {
        final values = RangeValues(_minPrice ?? 0, _maxPrice ?? 10000000);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 20),
            RangeSlider(
              min: 0,
              max: 10000000,
              divisions: 100,
              values: values,
              labels: RangeLabels(AppFormatters.priceSDG(values.start.round()), AppFormatters.priceSDG(values.end.round())),
              onChanged: (next) {
                setState(() {
                  _minPrice = next.start == 0 ? null : next.start;
                  _maxPrice = next.end >= 10000000 ? null : next.end;
                });
                setSheetState(() {});
              },
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(AppFormatters.priceSDG(values.start.round()), style: const TextStyle(color: AppColors.textSecondary)),
              Text(AppFormatters.priceSDG(values.end.round()), style: const TextStyle(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('تطبيق السعر'))),
          ],
        );
      },
    );
  }

  List<String> _suggestions(List<PhoneListing> source) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final values = <String>{};
    for (final listing in source) {
      if (listing.status == ListingStatus.sold) continue;
      if (normalizedQuery.isEmpty ||
          listing.brand.toLowerCase().contains(normalizedQuery) ||
          listing.title.toLowerCase().contains(normalizedQuery)) {
        values.add(listing.brand);
        values.add(listing.title);
      }
      if (values.length >= 6) break;
    }
    return values.take(5).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _LoadErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _LoadErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.warning),
            const SizedBox(height: 12),
            const Text('تعذر تحميل الإعلانات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  const _EmptyState({
    required this.query,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('لم نجد ما تبحث عنه', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              query.isEmpty ? 'جرّب اختيار ماركة أو استخدام الفلاتر' : 'ابحث باسم آخر أو اختر اقتراحًا قريبًا',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: suggestions
                    .map((suggestion) => ActionChip(
                          label: Text(suggestion),
                          avatar: const Icon(Icons.search, size: 16),
                          onPressed: () => onSuggestionTap(suggestion),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _ListingListTile extends StatelessWidget {
  const _ListingListTile({
    required this.listing,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onTap,
  });

  final PhoneListing listing;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = listing.priceOnCall ? 'اتصل للسعر' : AppFormatters.priceSDG(listing.price);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 138,
          child: Row(
            children: [
              SizedBox(
                width: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    listing.imageUrls.isEmpty
                        ? const _ListImagePlaceholder()
                        : CachedNetworkImage(
                            imageUrl: listing.imageUrls.first,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const _ListImagePlaceholder(),
                          ),
                    if (listing.isFeatured)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: _ListBadge(label: 'مميز'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          IconButton(
                            onPressed: onFavoriteToggle,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? AppColors.danger : AppColors.textSecondary, size: 20),
                          ),
                        ],
                      ),
                      Text('${listing.brand} • ${listing.storage} • ${listing.ram}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(child: Text(listing.city, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(price, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListImagePlaceholder extends StatelessWidget {
  const _ListImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceLight,
      child: Center(child: Icon(Icons.phone_android_rounded, size: 42, color: AppColors.textSecondary)),
    );
  }
}

class _ListBadge extends StatelessWidget {
  const _ListBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.all(Radius.circular(6))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
