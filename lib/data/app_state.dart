import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_model.dart';
import '../models/phone_model.dart';
import 'mock_data.dart';

/// Global application state for authentication, listings, favorites, and account role.
class AppState extends ChangeNotifier {
  AppState() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      if (_session == null) {
        _userName = null;
        _isShopOwner = false;
        _shopName = null;
        _favoriteIds.clear();
      } else {
        _userName = data.session?.user.userMetadata?['full_name'] as String? ??
            data.session?.user.email ??
            'مستخدم PhoneK';
        unawaited(_loadProfile());
        unawaited(_loadFavorites());
        unawaited(loadChatThreads());
      }
      notifyListeners();
    });

    _session = Supabase.instance.client.auth.currentSession;
    if (_session != null) {
      _userName = _session!.user.userMetadata?['full_name'] as String? ??
          _session!.user.email ??
          'مستخدم PhoneK';
      unawaited(_loadProfile());
      unawaited(_loadFavorites());
      unawaited(loadChatThreads());
    }

    unawaited(loadListings());
  }

  final Set<String> _favoriteIds = {};
  final List<PhoneListing> _listings = [];
  final List<PhoneRequest> _phoneRequests = [...MockData.phoneRequests];
  final List<ChatThread> _chatThreads = [];
  final List<RealtimeChannel> _chatChannels = [];
  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  bool _isShopOwner = false;
  String? _shopName;
  String? _userName;
  bool _isLoadingListings = false;
  String? _listingsError;

  bool isFavorite(String id) => _favoriteIds.contains(id);

  void toggleFavorite(String id) {
    final wasFavorite = _favoriteIds.contains(id);
    if (wasFavorite) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();

    final userId = _session?.user.id;
    if (userId == null) return;
    unawaited(
        _persistFavorite(userId: userId, listingId: id, add: !wasFavorite));
  }

  Future<void> _loadFavorites() async {
    final userId = _session?.user.id;
    if (userId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('favorites')
          .select('listing_id')
          .eq('user_id', userId);
      _favoriteIds
        ..clear()
        ..addAll((rows as List)
            .whereType<Map<String, dynamic>>()
            .map((row) => row['listing_id'])
            .whereType<String>());
      notifyListeners();
    } catch (_) {
      // Keep optimistic/local behavior if the optional migration is not applied yet.
    }
  }

  Future<void> _persistFavorite({
    required String userId,
    required String listingId,
    required bool add,
  }) async {
    try {
      if (add) {
        await Supabase.instance.client.from('favorites').upsert({
          'user_id': userId,
          'listing_id': listingId,
        });
      } else {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('listing_id', listingId);
      }
    } catch (_) {
      // The UI remains usable while a missing migration or network failure is reported later.
    }
  }

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  List<PhoneListing> get listings => List.unmodifiable(_listings);
  List<PhoneRequest> get phoneRequests => List.unmodifiable(_phoneRequests);
  bool get isLoadingListings => _isLoadingListings;
  String? get listingsError => _listingsError;
  List<ChatThread> get chatThreads => List.unmodifiable(_chatThreads);
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

  void addPhoneRequest(PhoneRequest request) {
    _phoneRequests.insert(0, request);
    notifyListeners();
  }

  Future<void> updateListingPrice(String listingId, int newPrice) async {
    if (_session != null) {
      final listing = _listings.cast<PhoneListing?>().firstWhere(
            (item) => item?.id == listingId,
            orElse: () => null,
          );
      await Supabase.instance.client.from('listings').update({
        'price': newPrice,
        if (listing != null && listing.oldPrice == null)
          'old_price': listing.price,
      }).eq('id', listingId);
    }

    final index = _listings.indexWhere((listing) => listing.id == listingId);
    if (index == -1) return;
    final current = _listings[index];
    _listings[index] = current.copyWith(
      price: newPrice,
      oldPrice: current.oldPrice ?? current.price,
    );
    notifyListeners();
  }

  Future<void> deleteListing(String listingId) async {
    if (_session != null) {
      await Supabase.instance.client
          .from('listings')
          .delete()
          .eq('id', listingId);
    }
    _listings.removeWhere((listing) => listing.id == listingId);
    notifyListeners();
  }

  Future<void> loadChatThreads() async {
    final userId = _session?.user.id;
    if (userId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('chat_threads')
          .select('id, listing_id, buyer_id, seller_id, created_at')
          .or('buyer_id.eq.$userId,seller_id.eq.$userId')
          .order('created_at', ascending: false);
      _chatThreads
        ..clear()
        ..addAll((rows as List).whereType<Map<String, dynamic>>().map((row) {
          final listing = _listings.cast<PhoneListing?>().firstWhere(
                (item) => item?.id == row['listing_id'],
                orElse: () => null,
              );
          return ChatThread(
            id: row['id'] as String,
            phoneListingId: row['listing_id'] as String,
            phoneTitle: listing?.title ?? 'إعلان PhoneK',
            otherUserName: listing?.seller.name ?? 'مستخدم PhoneK',
          );
        }));
      notifyListeners();
    } catch (_) {
      // Chat is optional until a user opens a conversation.
    }
  }

  Future<String> ensureChatThread(PhoneListing listing) async {
    final userId = _session?.user.id;
    if (userId == null) throw const AuthException('سجّل الدخول لبدء محادثة');
    final existing = await Supabase.instance.client
        .from('chat_threads')
        .select('id')
        .eq('listing_id', listing.id)
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .limit(1);
    if ((existing as List).isNotEmpty) return existing.first['id'] as String;
    final inserted = await Supabase.instance.client
        .from('chat_threads')
        .insert({
          'listing_id': listing.id,
          'buyer_id': userId,
          'seller_id': listing.seller.id,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  Future<List<ChatMessage>> loadMessages(String threadId) async {
    final rows = await Supabase.instance.client
        .from('chat_messages')
        .select('id, sender_id, text, type, status, offer_amount, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(_messageFromRow)
        .toList();
  }

  Future<void> sendMessage(
      {required String threadId, required String text}) async {
    final userId = _session?.user.id;
    if (userId == null) throw const AuthException('سجّل الدخول لإرسال رسالة');
    await Supabase.instance.client.from('chat_messages').insert({
      'thread_id': threadId,
      'sender_id': userId,
      'text': text,
      'type': MessageType.text.name,
      'status': MessageStatus.sent.name,
    });
  }

  RealtimeChannel subscribeToMessages(
      String threadId, void Function(ChatMessage message) onMessage) {
    final channel = Supabase.instance.client.channel('phonek-chat-$threadId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) => onMessage(_messageFromRow(payload.newRecord)),
        )
        .subscribe();
    _chatChannels.add(channel);
    return channel;
  }

  ChatMessage _messageFromRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String,
      senderId: row['sender_id'] as String? ?? '',
      text: row['text'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (item) => item.name == row['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (item) => item.name == row['status'],
        orElse: () => MessageStatus.sent,
      ),
      offerAmount: (row['offer_amount'] as num?)?.toInt(),
    );
  }

  Future<void> loadListings() async {
    if (_isLoadingListings) return;
    _isLoadingListings = true;
    _listingsError = null;
    notifyListeners();

    try {
      final listingsQuery = Supabase.instance.client
          .from('listings')
          .select('*')
          .gt('expires_at', DateTime.now().toIso8601String());
      final rows = _session == null
          ? await listingsQuery
              .eq('status', 'active')
              .order('created_at', ascending: false)
          : await listingsQuery
              .or('status.eq.active,seller_id.eq.${_session!.user.id}')
              .order('created_at', ascending: false);
      final listingRows =
          (rows as List).whereType<Map<String, dynamic>>().toList();
      final sellerIds = listingRows
          .map((row) => row['seller_id'])
          .whereType<String>()
          .toSet()
          .toList();
      final sellerRows = sellerIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : (await Supabase.instance.client
                  .from('profiles')
                  .select('*')
                  .inFilter('id', sellerIds) as List)
              .whereType<Map<String, dynamic>>()
              .toList();
      final sellersById = <String, Map<String, dynamic>>{
        for (final seller in sellerRows)
          if (seller['id'] is String) seller['id'] as String: seller,
      };
      final loaded = listingRows
          .map((row) => _listingFromRow(row, sellersById[row['seller_id']]))
          .whereType<PhoneListing>()
          .toList();
      _listings
        ..clear()
        ..addAll(loaded.isEmpty ? MockData.listings : loaded);
      if (_session != null) unawaited(loadChatThreads());
    } on PostgrestException catch (_) {
      _listings
        ..clear()
        ..addAll(MockData.listings);
      _listingsError = null;
    } catch (_) {
      _listings
        ..clear()
        ..addAll(MockData.listings);
      _listingsError = null;
    } finally {
      _isLoadingListings = false;
      notifyListeners();
    }
  }

  PhoneListing? _listingFromRow(Map<String, dynamic> row,
      [Map<String, dynamic>? profile]) {
    try {
      final sellerRow = profile ?? <String, dynamic>{};
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
        imageUrls: _imageUrlsFromValue(row['image_urls']),
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
          replySpeedLabel: sellerRow['reply_speed_label'] as String? ??
              'يرد عادة خلال ساعات',
        ),
        status: _statusFromValue(row['status'] as String?),
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
        isFeatured: row['is_featured'] as bool? ?? false,
        description: row['description'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _imageUrlsFromValue(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) =>
              item.startsWith('http://') || item.startsWith('https://'))
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        return _imageUrlsFromValue(jsonDecode(value));
      } catch (_) {
        return const [];
      }
    }
    return const [];
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
        ? _webOAuthRedirectUri()
        : 'io.supabase.phonek://login-callback';
    final response = await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!response) {
      throw const AuthException('تعذر بدء تسجيل الدخول عبر Google');
    }
  }

  String _webOAuthRedirectUri() {
    final basePath = Uri.base.path.isEmpty ? '/' : Uri.base.path;
    final normalizedPath = basePath.endsWith('/') ? basePath : '$basePath/';
    return '${Uri.base.origin}$normalizedPath';
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
    for (final channel in _chatChannels) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }
}
