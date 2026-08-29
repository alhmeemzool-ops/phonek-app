import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/phone_model.dart';

/// Global application state for authentication, listings, favorites, and account role.
class AppState extends ChangeNotifier {
  AppState() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      if (_session == null) {
        _userName = null;
        _isShopOwner = false;
        _shopName = null;
      } else {
        _userName = data.session?.user.userMetadata?['full_name'] as String? ??
            data.session?.user.email ??
            'مستخدم PhoneK';
        unawaited(_loadProfile());
      }
      notifyListeners();
    });

    _session = Supabase.instance.client.auth.currentSession;
    if (_session != null) {
      _userName = _session!.user.userMetadata?['full_name'] as String? ??
          _session!.user.email ??
          'مستخدم PhoneK';
      unawaited(_loadProfile());
    }

    unawaited(loadListings());
  }

  final Set<String> _favoriteIds = {};
  final List<PhoneListing> _listings = [];
  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  bool _isShopOwner = false;
  String? _shopName;
  String? _userName;
  bool _isLoadingListings = false;
  String? _listingsError;

  bool isFavorite(String id) => _favoriteIds.contains(id);

  void toggleFavorite(String id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();
  }

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  List<PhoneListing> get listings => List.unmodifiable(_listings);
  bool get isLoadingListings => _isLoadingListings;
  String? get listingsError => _listingsError;
  bool get isLoggedIn => _session != null;
  String? get userName => _userName;
  bool get isShopOwner => _isShopOwner;
  String? get shopName => _shopName;
  User? get currentUser => _session?.user;

  /// Keeps the demo login API available for local previews and tests.
  void login(String name) {
    _userName = name;
    notifyListeners();
  }

  Future<void> loadListings() async {
    if (_isLoadingListings) return;
    _isLoadingListings = true;
    _listingsError = null;
    notifyListeners();

    try {
      final rows = await Supabase.instance.client
          .from('listings')
          .select('*, profiles(*)')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final loaded = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(_listingFromRow)
          .whereType<PhoneListing>()
          .toList();
      _listings
        ..clear()
        ..addAll(loaded);
    } on PostgrestException catch (error) {
      _listingsError = error.message;
    } catch (error) {
      _listingsError = 'تعذر تحميل الإعلانات: $error';
    } finally {
      _isLoadingListings = false;
      notifyListeners();
    }
  }

  PhoneListing? _listingFromRow(Map<String, dynamic> row) {
    try {
      final sellerRow = row['profiles'] is Map<String, dynamic>
          ? row['profiles'] as Map<String, dynamic>
          : <String, dynamic>{};
      return PhoneListing(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        brand: row['brand'] as String? ?? '',
        price: (row['price'] as num?)?.toInt() ?? 0,
        priceIsNegotiable: row['price_is_negotiable'] as bool? ?? true,
        priceOnCall: row['price_on_call'] as bool? ?? false,
        oldPrice: (row['old_price'] as num?)?.toInt(),
        storage: row['storage'] as String? ?? '',
        ram: row['ram'] as String? ?? '',
        batteryHealthPercent: (row['battery_health_percent'] as num?)?.toInt(),
        condition: _conditionFromValue(row['condition'] as String?),
        damageNotes: row['damage_notes'] as String?,
        hasBox: row['has_box'] as bool? ?? false,
        hasCharger: row['has_charger'] as bool? ?? false,
        hasInvoice: row['has_invoice'] as bool? ?? false,
        hasEarphones: row['has_earphones'] as bool? ?? false,
        warranty: _warrantyFromValue(row['warranty'] as String?),
        city: row['city'] as String? ?? '',
        imageUrls: (row['image_urls'] as List?)?.whereType<String>().toList() ?? const [],
        seller: SellerInfo(
          id: row['seller_id'] as String? ?? '',
          name: sellerRow['name'] as String? ?? 'بائع PhoneK',
          phone: sellerRow['phone'] as String? ?? '',
          whatsapp: sellerRow['whatsapp'] as String?,
          bio: sellerRow['bio'] as String?,
          avatarUrl: sellerRow['avatar_url'] as String?,
          isVerifiedStore: sellerRow['is_verified_store'] as bool? ?? false,
          isShop: sellerRow['is_shop'] as bool? ?? false,
          rating: (sellerRow['rating'] as num?)?.toDouble() ?? 0,
          completedSales: (sellerRow['completed_sales'] as num?)?.toInt() ?? 0,
          city: sellerRow['city'] as String? ?? row['city'] as String? ?? '',
          replySpeedLabel: sellerRow['reply_speed_label'] as String? ?? 'يرد عادة خلال ساعات',
        ),
        status: _statusFromValue(row['status'] as String?),
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
        viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
        isFeatured: row['is_featured'] as bool? ?? false,
        description: row['description'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  DeviceCondition _conditionFromValue(String? value) {
    switch (value) {
      case 'new':
      case 'newDevice':
        return DeviceCondition.newDevice;
      case 'minor_scratches':
      case 'minorScratches':
        return DeviceCondition.minorScratches;
      case 'cracked':
        return DeviceCondition.cracked;
      default:
        return DeviceCondition.excellent;
    }
  }

  WarrantyType _warrantyFromValue(String? value) {
    switch (value) {
      case 'store_warranty':
      case 'storeWarranty':
        return WarrantyType.storeWarranty;
      case 'agent_warranty':
      case 'agentWarranty':
        return WarrantyType.agentWarranty;
      default:
        return WarrantyType.none;
    }
  }

  ListingStatus _statusFromValue(String? value) {
    switch (value) {
      case 'sold':
        return ListingStatus.sold;
      case 'frozen':
        return ListingStatus.frozen;
      case 'expired':
        return ListingStatus.expired;
      case 'pending_review':
      case 'pendingReview':
        return ListingStatus.pendingReview;
      default:
        return ListingStatus.active;
    }
  }

  Future<void> signInWithGoogle() async {
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path.endsWith('/') ? Uri.base.path : '${Uri.base.path}/'}'
        : 'io.supabase.phonek://login-callback';
    final response = await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!response) {
      throw const AuthException('تعذر بدء تسجيل الدخول عبر Google');
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _loadProfile() async {
    final userId = _session?.user.id;
    if (userId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('name, is_shop')
          .eq('id', userId)
          .maybeSingle();
      if (row != null) {
        _userName = (row['name'] as String?)?.trim().isNotEmpty == true
            ? row['name'] as String
            : _userName;
        _isShopOwner = row['is_shop'] as bool? ?? false;
        _shopName = _isShopOwner ? row['name'] as String? : null;
        notifyListeners();
      }
    } catch (_) {
      // The profile table is optional during the initial demo setup.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
