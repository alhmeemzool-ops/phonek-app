import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../screens/wanted_screen.dart';
import '../screens/accessories_screen.dart';
import '../screens/repair_directory_screen.dart';
import '../data/app_state.dart';
import '../data/catalog_data.dart' as catalog;
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_card.dart';
import '../widgets/listing_form.dart';
import 'phone_details_screen.dart';
import 'add_phone_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'chat_list_screen.dart';

enum SortOption { newest, priceLowHigh, priceHighLow }

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
  bool _swapOnly = false;
  final TextEditingController _searchController = TextEditingController();
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = info.version);
  }

  List<PhoneListing> _filteredListings(List<PhoneListing> source) {
    var list = source.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.brand.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCity = _selectedCity == null || p.city == _selectedCity;
      final matchesBrand = _selectedBrand == null || p.brand == _selectedBrand;
      return matchesQuery && matchesCity && matchesBrand && (!_swapOnly || p.acceptsSwap) && p.status != ListingStatus.sold;
    }).toList();

    switch (_sortOption) {
      case SortOption.newest:
        list.sort((a, b) { if(a.subscriptionActive != b.subscriptionActive) return a.subscriptionActive ? -1 : 1; return b.createdAt.compareTo(a.createdAt); });
        break;
      case SortOption.priceLowHigh:
        list.sort((a, b) => a.displayedPrice.compareTo(b.displayedPrice));
        break;
      case SortOption.priceHighLow:
        list.sort((a, b) => b.displayedPrice.compareTo(a.displayedPrice));
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
                onPressed: _openFilterSheet,
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
                    hintText: 'ابحث عن هاتف، ماركة، أو سعة...',
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
          SliverToBoxAdapter(child: _buildShortcuts(context)),
          SliverToBoxAdapter(child: _buildBrandChips()),
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
              child: _EmptyState(query: _searchQuery),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final phone = listings[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: AspectRatio(
                      // العرض كما هو، والطول ضعف العرض تماماً.
                      aspectRatio: 0.5,
                      child: PhoneCard(
                        listing: phone,
                        isFavorite: appState.isFavorite(phone.id),
                        onFavoriteToggle: () => appState.toggleFavorite(phone.id),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: phone)),
                        ),
                      ),
                    ),
                  );
                },
                childCount: listings.length,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
              child: Center(
                child: Text(
                  _appVersion.isEmpty ? 'PhoneK' : 'PhoneK v$_appVersion',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts(BuildContext context) => SizedBox(height:92,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),children:[
    _shortcut(context,'مطلوب',Icons.assignment_outlined,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WantedScreen()))),
    _shortcut(context,'إكسسوارات',Icons.cases_outlined,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccessoriesScreen()))),
    _shortcut(context,'دليل الصيانة',Icons.build_outlined,()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RepairDirectoryScreen()))),
  ]));
  Widget _shortcut(BuildContext context,String title,IconData icon,VoidCallback onTap)=>SizedBox(width:125,child:Padding(padding:const EdgeInsets.only(left:8),child:Card(child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:AppColors.gold),const SizedBox(width:7),Text(title,style:const TextStyle(fontWeight:FontWeight.bold))])))));
  
  Widget _buildBrandChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _brandChip(null, 'الكل'),
          ...catalog.CatalogData.brands.map((b) => _brandChip(b, b)),
        ],
      ),
    );
  }

  Widget _brandChip(String? brand, String label) {
    final selected = _selectedBrand == brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedBrand = selected ? null : brand),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الفلاتر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  const Text('المدينة', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showCityPicker(ctx, selectedCity: _selectedCity, includeAll: true);
                      setSheetState(() => _selectedCity = picked);
                    },
                    icon: const Icon(Icons.location_city),
                    label: Text(_selectedCity ?? 'الكل'),
                  ),
                  const SizedBox(height: 20),
                  const Text('الترتيب', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('الأحدث'),
                        selected: _sortOption == SortOption.newest,
                        onSelected: (_) => setSheetState(() => _sortOption = SortOption.newest),
                      ),
                      ChoiceChip(
                        label: const Text('الأقل سعراً'),
                        selected: _sortOption == SortOption.priceLowHigh,
                        onSelected: (_) => setSheetState(() => _sortOption = SortOption.priceLowHigh),
                      ),
                      ChoiceChip(
                        label: const Text('الأكثر سعراً'),
                        selected: _sortOption == SortOption.priceHighLow,
                        onSelected: (_) => setSheetState(() => _sortOption = SortOption.priceHighLow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {}); // يطبّق الفلاتر على الشاشة الرئيسية
                        Navigator.pop(ctx);
                      },
                      child: const Text('تطبيق الفلاتر'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('لم نجد ما تبحث عنه', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('جرب البحث باسم آخر', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
