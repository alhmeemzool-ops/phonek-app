import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_model.dart';
import '../models/phone_model.dart';
import '../services/notification_service.dart';

/// Global application state for authentication, listings, favorites, and account role.
class AppState extends ChangeNotifier {
  AppState() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      if (_session == null) {
        _userName = null;
        _isShopOwner = false;
        _isAdmin = false;
        _shopName = null;
        _favoriteIds.clear();
        _chatThreads.clear();
      } else {
        // Reset account-specific shop/admin state before loading the new session.
        // This prevents the previous account's merchant status from leaking into
        // the next account while _loadProfile() is still running.
        _isShopOwner = false;
        _isAdmin = false;
        _shopName = null;
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

    unawaited(_loadDataSaver());
    unawaited(_initConnectivity());
    unawaited(loadListings());
  }

  final Set<String> _favoriteIds = {};
  final Set<String> _viewedListingIds = {};
  final List<PhoneListing> _listings = [];
  final List<ChatThread> _chatThreads = [];
  final List<RealtimeChannel> _chatChannels = [];
  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  bool _isShopOwner = false;
  bool _isAdmin = false;
  String? _shopName;
  String? _userName;
  bool _isLoadingListings = false;
  bool _dataSaver = false;
  bool _offline = false;
  List<PhoneListing> _recentOfflineListings = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _listingsError;

  bool isFavorite(String id) => _favoriteIds.contains(id);

  void toggleFavorite(String id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    unawaited(_persistFavorites());
    notifyListeners();
  }

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  List<PhoneListing> get listings => List.unmodifiable(_listings);
  bool get isLoadingListings => _isLoadingListings;
  String? get listingsError => _listingsError;
  List<ChatThread> get chatThreads => List.unmodifiable(_chatThreads);
  bool get isLoggedIn => _session != null;
  String? get userName => _userName;
  String? get userEmail => _session?.user.email;
  bool get isAdmin => _isAdmin;
  bool get isShopOwner => _isShopOwner;
  bool get dataSaverEnabled => _dataSaver;
  bool get isOffline => _offline;
  List<PhoneListing> get recentOfflineListings => List.unmodifiable(_recentOfflineListings);

  Future<void> _initConnectivity() async {
    final result=await Connectivity().checkConnectivity();
    _offline=result.contains(ConnectivityResult.none);
    _connectivitySubscription=Connectivity().onConnectivityChanged.listen((items){
      final next=items.contains(ConnectivityResult.none);
      final wasOffline=_offline; _offline=next; notifyListeners();
      if(wasOffline && !next) unawaited(loadListings());
    });
    await _loadOfflineCache();
  }

  Future<void> _loadOfflineCache() async {
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getStringList('phonek_recent_listings')??const <String>[];
    _recentOfflineListings=raw.map((s){try{return PhoneListing.fromJson(jsonDecode(s) as Map<String,dynamic>);}catch(_){return null;}}).whereType<PhoneListing>().take(20).toList();
    notifyListeners();
  }

  Future<void> _saveOfflineListing(PhoneListing listing) async {
    final prefs=await SharedPreferences.getInstance();
    final items=<String>[jsonEncode(listing.toJson()),...((prefs.getStringList('phonek_recent_listings')??const <String>[]).where((s){try{return (jsonDecode(s) as Map<String,dynamic>)['id']!=listing.id;}catch(_){return true;}}))].take(20).toList();
    await prefs.setStringList('phonek_recent_listings',items);
  }

  Future<void> _loadDataSaver() async {
    final prefs = await SharedPreferences.getInstance();
    _dataSaver = prefs.getBool('phonek_data_saver') ?? false;
    notifyListeners();
  }

  Future<void> setDataSaverEnabled(bool enabled) async {
    _dataSaver = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('phonek_data_saver', enabled);
    notifyListeners();
  }
  String? get shopName => _shopName;
  User? get currentUser => _session?.user;

  String get _favoriteStorageKey => 'phonek_favorites_${_session?.user.id ?? 'guest'}';

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _favoriteIds
        ..clear()
        ..addAll(prefs.getStringList(_favoriteStorageKey) ?? const <String>[]);
      notifyListeners();
    } catch (_) {
      // Favorites remain available for the current session if local storage is unavailable.
    }
  }

  Future<void> _persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoriteStorageKey, _favoriteIds.toList());
    } catch (_) {
      // Do not block the UI if local persistence fails.
    }
  }

  Future<void> syncAuthState() async {
    _session = Supabase.instance.client.auth.currentSession;
    if (_session == null) {
      _userName = null;
      _isShopOwner = false;
      _isAdmin = false;
      _shopName = null;
      _favoriteIds.clear();
      _chatThreads.clear();
      notifyListeners();
      return;
    }
    _isShopOwner = false;
    _isAdmin = false;
    _shopName = null;
    _userName = _session!.user.userMetadata?['full_name'] as String? ??
        _session!.user.email ??
        'مستخدم PhoneK';
    notifyListeners();
    await Future.wait<void>([
      _loadProfile(),
      _loadFavorites(),
      loadChatThreads(),
    ]);
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
      final loadedThreads = <ChatThread>[];
      for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
        final listing = _listings.cast<PhoneListing?>().firstWhere(
              (item) => item?.id == row['listing_id'],
              orElse: () => null,
            );
        String otherUserName = 'مستخدم PhoneK';
        try {
          final participant = await Supabase.instance.client.rpc(
            'get_chat_participants',
            params: {'p_thread_id': row['id']},
          );
          if (participant is Map && participant['other_user_name'] != null) {
            otherUserName = participant['other_user_name'].toString();
          }
        } catch (error) {
          debugPrint('PhoneK chat participant lookup failed: $error');
          otherUserName = listing?.seller.name ?? otherUserName;
        }
        loadedThreads.add(ChatThread(
          id: row['id'] as String,
          phoneListingId: row['listing_id'] as String,
          phoneTitle: listing?.title ?? 'إعلان PhoneK',
          otherUserName: otherUserName,
        ));
      }
      if (_session?.user.id != userId) return;
      _chatThreads
        ..clear()
        ..addAll(loadedThreads);
      notifyListeners();
    } catch (_) {
      // Chat is optional until a user opens a conversation.
    }
  }

  Future<String> ensureChatThread(PhoneListing listing) async {
    final userId = _session?.user.id;
    if (userId == null) throw const AuthException('سجّل الدخول لبدء محادثة');
    if (userId == listing.seller.id) {
      throw const AuthException('لا يمكنك بدء محادثة مع نفسك');
    }
    final existing = await Supabase.instance.client
        .from('chat_threads')
        .select('id')
        .eq('listing_id', listing.id)
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .limit(1);
    if ((existing as List).isNotEmpty) return existing.first['id'] as String;
    try {
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
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final raced = await Supabase.instance.client
          .from('chat_threads')
          .select('id')
          .eq('listing_id', listing.id)
          .eq('buyer_id', userId)
          .limit(1);
      if ((raced as List).isEmpty) rethrow;
      return raced.first['id'] as String;
    }
  }

  Future<List<ChatMessage>> loadMessages(String threadId) async {
    final rows = await Supabase.instance.client
        .from('chat_messages')
        .select('id, sender_id, text, type, status, offer_amount, payload, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);
    return (rows as List).whereType<Map<String, dynamic>>().map(_messageFromRow).toList();
  }

  Future<void> sendMessage({required String threadId, required String text}) async {
    final userId = _session?.user.id;
    if (userId == null) throw const AuthException('سجّل الدخول لإرسال رسالة');
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final inserted = await Supabase.instance.client
        .from('chat_messages')
        .insert({
          'thread_id': threadId,
          'sender_id': userId,
          'text': cleanText,
          'type': MessageType.text.value,
          'status': MessageStatus.sent.value,
        })
        .select('id')
        .single();

    unawaited(_sendPushForMessage(
      threadId: threadId,
      messageId: inserted['id'] as String,
    ));
  }

  Future<void> sendVoice({required String threadId,required String path,required int durationSeconds}) async {
    final uid=_session?.user.id;if(uid==null)throw const AuthException('سجّل الدخول لإرسال رسالة صوتية');
    final inserted=await Supabase.instance.client.from('chat_messages').insert({'thread_id':threadId,'sender_id':uid,'text':'','type':MessageType.voice.value,'status':MessageStatus.sent.value,'payload':{'path':path,'duration_seconds':durationSeconds}}).select('id').single();
    unawaited(_sendPushForMessage(threadId:threadId,messageId:inserted['id'] as String));
  }

  Future<void> sendSwap({required PhoneListing listing, required String model, required DeviceCondition condition, required int diffAmount, required String diffDirection, String? imageUrl}) async {
    final userId=_session?.user.id;
    if(userId==null) throw const AuthException('سجّل الدخول لإرسال عرض تبديل');
    if(userId==listing.seller.id) throw const AuthException('لا يمكنك التبديل مع إعلانك');
    if(!listing.acceptsSwap) throw const AuthException('هذا الإعلان لا يقبل التبديل');
    final threadId=await ensureChatThread(listing);
    final inserted=await Supabase.instance.client.from('chat_messages').insert({
      'thread_id':threadId,'sender_id':userId,'text':'','type':MessageType.swap.value,'status':MessageStatus.sent.value,
      'payload':{'model':model.trim(),'condition':condition.value,'diff_amount':diffAmount,'diff_direction':diffDirection,'image_url':imageUrl,'status':'pending'},
    }).select('id').single();
    unawaited(_sendPushForMessage(threadId:threadId,messageId:inserted['id'] as String));
  }

  Future<void> sendOffer({required PhoneListing listing, required int amount}) async {
    final userId = _session?.user.id;
    if (userId == null) throw const AuthException('سجّل الدخول لإرسال عرض');
    if (userId == listing.seller.id) {
      throw const AuthException('لا يمكنك تقديم عرض على إعلانك');
    }
    if (amount <= 0) throw const AuthException('أدخل سعراً صحيحاً');
    if (listing.priceOnCall) throw const AuthException('هذا الإعلان سعره عند الاتصال');

    final threadId = await ensureChatThread(listing);
    final inserted = await Supabase.instance.client
        .from('chat_messages')
        .insert({
          'thread_id': threadId,
          'sender_id': userId,
          'text': '',
          'type': MessageType.offer.value,
          'offer_amount': amount,
          'status': MessageStatus.sent.value,
        })
        .select('id')
        .single();

    unawaited(_sendPushForMessage(
      threadId: threadId,
      messageId: inserted['id'] as String,
    ));
  }

  Future<void> _sendPushForMessage({
    required String threadId,
    required String messageId,
  }) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final thread = await Supabase.instance.client
          .from('chat_threads')
          .select('buyer_id, seller_id')
          .eq('id', threadId)
          .maybeSingle();
      if (thread == null) return;

      final buyerId = thread['buyer_id']?.toString();
      final sellerId = thread['seller_id']?.toString();
      if (buyerId == null || sellerId == null) return;
      if (currentUserId != buyerId && currentUserId != sellerId) return;

      final recipientId =
          currentUserId == buyerId ? sellerId : buyerId;

      await Supabase.instance.client.functions.invoke(
        'send-push-notification',
        body: {
          'thread_id': threadId,
          'chatId': threadId,
          'message_id': messageId,
          'senderId': currentUserId,
          'recipientId': recipientId,
          'recipient_user_id': recipientId,
        },
      );
    } catch (error) {
      debugPrint('PhoneK push notification request failed: $error');
    }
  }

  Future<PhoneListing?> getListingById(String listingId) async {
    final cached = _listings.cast<PhoneListing?>().firstWhere(
          (item) => item?.id == listingId,
          orElse: () => null,
        );
    if (cached != null) return cached;

    try {
      final row = await Supabase.instance.client
          .from('listings')
          .select('*')
          .eq('id', listingId)
          .maybeSingle();
      if (row == null) return null;

      final sellerId = row['seller_id']?.toString();
      Map<String, dynamic>? seller;
      if (sellerId != null && sellerId.isNotEmpty) {
        seller = await Supabase.instance.client
            .from('public_seller_cards')
            .select('*')
            .eq('id', sellerId)
            .maybeSingle();
      }
      return _listingFromRow(
        Map<String, dynamic>.from(row),
        seller == null ? null : Map<String, dynamic>.from(seller),
      );
    } catch (error) {
      debugPrint('PhoneK notification listing lookup failed: $error');
      return null;
    }
  }

  Future<ChatThread?> getChatThreadById(String threadId) async {
    try {
      final row = await Supabase.instance.client
          .from('chat_threads')
          .select('id, listing_id, buyer_id, seller_id, created_at')
          .eq('id', threadId)
          .maybeSingle();
      if (row == null) return null;

      final listingId = row['listing_id']?.toString();
      if (listingId == null || listingId.isEmpty) return null;

      final listing = await getListingById(listingId);
      if (listing == null) return null;

      var otherUserName = listing.seller.name;
      try {
        final participant = await Supabase.instance.client.rpc(
          'get_chat_participants',
          params: {'p_thread_id': threadId},
        );
        if (participant is Map && participant['other_user_name'] != null) {
          otherUserName = participant['other_user_name'].toString();
        }
      } catch (_) {}

      return ChatThread(
        id: threadId,
        phoneListingId: listing.id,
        phoneTitle: listing.title,
        otherUserName: otherUserName,
      );
    } catch (error) {
      debugPrint('PhoneK notification thread lookup failed: $error');
      return null;
    }
  }

  RealtimeChannel subscribeToMessages(String threadId, void Function(ChatMessage message) onMessage) {
    final channel = Supabase.instance.client.channel('phonek-chat-$threadId');
    channel.onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'chat_messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'thread_id', value: threadId), callback: (payload) => onMessage(_messageFromRow(payload.newRecord)));
    channel.onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'chat_messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'thread_id', value: threadId), callback: (payload) => onMessage(_messageFromRow(payload.newRecord)));
    return channel..subscribe();
  }

  ChatMessage _messageFromRow(Map<String, dynamic> row) {
    final rawType = row['type']?.toString() ?? 'text';
    final type = MessageType.values.firstWhere((item) => item.value == rawType, orElse: () => MessageType.text);
    return ChatMessage(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      text: row['text']?.toString() ?? '',
      type: type,
      timestamp: DateTime.parse(row['created_at'].toString()).toLocal(),
      status: MessageStatus.values.firstWhere((item) => item.value == row['status'], orElse: () => MessageStatus.sent),
      offerAmount: (row['offer_amount'] as num?)?.toInt(),
      payload: row['payload'] is Map ? Map<String,dynamic>.from(row['payload'] as Map) : null,
    );
  }

  Future<void> loadListings() async {
    if (_isLoadingListings) return;
    _isLoadingListings = true;
    _listingsError = null;
    notifyListeners();

    try {
      final rows = await Supabase.instance.client
          .from('listings')
          .select('*')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final rawRows = (rows as List).whereType<Map<String, dynamic>>().toList();
      final sellerIds = rawRows
          .map((row) => row['seller_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final sellerCards = <String, Map<String, dynamic>>{};
      if (sellerIds.isNotEmpty) {
        final cards = await Supabase.instance.client
            .from('public_seller_cards')
            .select('*')
            .inFilter('id', sellerIds);
        for (final card in (cards as List).whereType<Map<String, dynamic>>()) {
          sellerCards[card['id'].toString()] = card;
        }
      }

      final loaded = rawRows
          .map((row) => _listingFromRow(row, sellerCards[row['seller_id']?.toString()]))
          .whereType<PhoneListing>()
          .toList();
      _listings
        ..clear()
        ..addAll(loaded);
      if (_session != null) unawaited(loadChatThreads());
    } on PostgrestException catch (error) {
      _listingsError = error.message;
    } catch (error) {
      _listingsError = 'تعذر تحميل الإعلانات: $error';
    } finally {
      _isLoadingListings = false;
      notifyListeners();
    }
  }

  Future<Map<String, String>> getSellerContact(String sellerId) async {
    if (_session == null) throw const AuthException('سجّل الدخول لرؤية رقم البائع');
    final result = await Supabase.instance.client.rpc(
      'get_seller_contact',
      params: {'seller_id': sellerId},
    );
    final row = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
    return {
      'phone': row['phone']?.toString() ?? '',
      'whatsapp': row['whatsapp']?.toString() ?? '',
    };
  }

  Future<void> recordListingView(String listingId) async {
    if (_viewedListingIds.contains(listingId)) return;
    _viewedListingIds.add(listingId);
    try {
      await Supabase.instance.client.rpc(
        'increment_listing_view',
        params: {'p_listing_id': listingId},
      );
    } catch (error) {
      debugPrint('PhoneK listing view increment failed: $error');
      _viewedListingIds.remove(listingId);
    }
  }

  Future<void> updateListing({
    required String id,
    required String title,
    required String brand,
    required int price,
    required bool priceIsNegotiable,
    required bool priceOnCall,
    required String storage,
    required String ram,
    required int? batteryHealthPercent,
    required DeviceCondition condition,
    required String? damageNotes,
    required bool hasBox,
    required bool hasCharger,
    required bool hasInvoice,
    required bool hasEarphones,
    required String city,
    required String description,
    required List<String> imageUrls,
    bool acceptsSwap = false,
    List<XFile> newImages = const [],
    List<String> originalImageUrls = const [],
  }) async {
    final userId = _session?.user.id;
    if (userId == null) throw const AuthException('سجّل الدخول لتعديل الإعلان');

    final client = Supabase.instance.client;
    final uploadedPaths = <String>[];
    final finalImageUrls = <String>[...imageUrls];

    try {
      for (var index = 0; index < newImages.length; index++) {
        final image = newImages[index];
        final path = userId +
            '/' +
            DateTime.now().microsecondsSinceEpoch.toString() +
            '_edit_' +
            index.toString() +
            '.' +
            _imageExtension(image.name);
        await client.storage.from('listing-images').uploadBinary(
          path,
          await image.readAsBytes(),
          fileOptions: FileOptions(contentType: _imageContentType(image.name), upsert: false),
        );
        uploadedPaths.add(path);
        finalImageUrls.add(client.storage.from('listing-images').getPublicUrl(path));
      }

      await client.from('listings').update({
        'title': title.trim(),
        'brand': brand.trim(),
        'price': price,
        'price_is_negotiable': priceIsNegotiable,
        'price_on_call': priceOnCall,
        'storage': storage,
        'ram': ram,
        'battery_health_percent': batteryHealthPercent,
        'condition': condition.value,
        'damage_notes': damageNotes?.trim().isEmpty == true ? null : damageNotes?.trim(),
        'has_box': hasBox,
        'has_charger': hasCharger,
        'has_invoice': hasInvoice,
        'has_earphones': hasEarphones,
        'city': city.trim(),
        'description': description.trim(),
        'image_urls': finalImageUrls,
        'accepts_swap': acceptsSwap,
      }).eq('id', id).eq('seller_id', userId);

      final removedUrls = originalImageUrls.where((url) => !imageUrls.contains(url)).toList();
      if (removedUrls.isNotEmpty) {
        final removedPaths = removedUrls.map(_listingImagePath).whereType<String>().toList();
        if (removedPaths.isNotEmpty) {
          try {
            await client.storage.from('listing-images').remove(removedPaths);
          } catch (error) {
            debugPrint('PhoneK removed listing image cleanup failed: $error');
          }
        }
      }
      await loadListings();
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await client.storage.from('listing-images').remove(uploadedPaths);
        } catch (error) {
          debugPrint('PhoneK new listing image rollback failed: $error');
        }
      }
      rethrow;
    }
  }

  String _imageExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? 'jpg' : name.substring(dot + 1).toLowerCase();
  }

  String _imageContentType(String name) {
    switch (_imageExtension(name)) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String? _listingImagePath(String url) {
    const marker = '/listing-images/';
    final index = url.indexOf(marker);
    if (index == -1) return null;
    final path = url.substring(index + marker.length);
    return path.isEmpty ? null : path;
  }

  Future<void> deleteListing(String id) async {
    final userId = _session?.user.id;
    if (userId == null) throw const AuthException('سجّل الدخول لحذف الإعلان');
    await Supabase.instance.client.from('listings').update({'status': 'expired'}).eq('id', id).eq('seller_id', userId);
    await loadListings();
  }

  PhoneListing? _listingFromRow(Map<String, dynamic> row, [Map<String, dynamic>? sellerRow]) {
    try {
      final seller = sellerRow ?? const <String, dynamic>{};
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
          name: seller['name'] as String? ?? 'بائع PhoneK',
          phone: seller['phone'] as String? ?? '',
          whatsapp: seller['whatsapp'] as String?,
          bio: seller['bio'] as String?,
          avatarUrl: seller['avatar_url'] as String?,
          isVerifiedStore: seller['is_verified_store'] as bool? ?? false,
          isShop: seller['is_shop'] as bool? ?? false,
          rating: (seller['rating'] as num?)?.toDouble() ?? 0,
          completedSales: (seller['completed_sales'] as num?)?.toInt() ?? 0,
          city: seller['city'] as String? ?? row['city'] as String? ?? '',
          replySpeedLabel: seller['reply_speed_label'] as String? ?? 'يرد عادة خلال ساعات',
        ),
        status: _statusFromValue(row['status'] as String?),
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
        viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
        isFeatured: row['is_featured'] as bool? ?? false,
        description: row['description'] as String? ?? '',
      acceptsSwap: row['accepts_swap'] == true,
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
    // This exact URI must also exist in Supabase Authentication > URL Configuration.
    // The trailing slash is intentional and matches Supabase's Flutter deep-link guidance.
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path.endsWith('/') ? Uri.base.path : '${Uri.base.path}/'}'
        : 'io.supabase.phonek://login-callback/';
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
    // Keep this account's refresh token available for automatic account switching.
    // Local sign-out clears the active session on this device without revoking
    // the server-side session, so a notification can switch back to this account.
    await NotificationService.rememberCurrentAccountSession();
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
  }

  Future<void> _loadProfile() async {
    final userId = _session?.user.id;
    if (userId == null) return;

    try {
      final row = await Supabase.instance.client
          .from('public_seller_cards')
          .select('name, is_shop')
          .eq('id', userId)
          .maybeSingle();
      if (_session?.user.id != userId) return;
      if (row != null) {
        _userName = (row['name'] as String?)?.trim().isNotEmpty == true
            ? row['name'] as String
            : _userName;
        _isShopOwner = row['is_shop'] as bool? ?? false;
        _shopName = _isShopOwner ? row['name'] as String? : null;
        notifyListeners();
      }
    } catch (_) {
      // Profile data is optional; it must not prevent the admin check below.
    }

    try {
      final adminResult = await Supabase.instance.client.rpc('is_admin');
      if (_session?.user.id != userId) return;
      _isAdmin = adminResult == true;
      notifyListeners();
    } catch (_) {
      if (_session?.user.id != userId) return;
      _isAdmin = false;
      // Fail closed if the admin RPC is unavailable.
      notifyListeners();
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
