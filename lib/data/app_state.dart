import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global application state for authentication, favorites, and account role.
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
  }

  final Set<String> _favoriteIds = {};
  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;
  bool _isShopOwner = false;
  String? _shopName;
  String? _userName;

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
          .select('display_name, account_type, shop_name')
          .eq('id', userId)
          .maybeSingle();
      if (row != null) {
        _userName = (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? row['display_name'] as String
            : _userName;
        _isShopOwner = row['account_type'] == 'shop';
        _shopName = row['shop_name'] as String?;
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
