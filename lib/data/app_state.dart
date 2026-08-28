import 'package:flutter/material.dart';

/// إدارة حالة بسيطة عبر التطبيق (المفضلة، تسجيل الدخول).
/// عند ربط Firebase استبدل هذا بمصدر بيانات حقيقي (Firestore/Auth streams)
/// مع الإبقاء على نفس الواجهة (نفس الدوال) لتقليل التعديلات على الشاشات.
class AppState extends ChangeNotifier {
  final Set<String> _favoriteIds = {};
  bool _isLoggedIn = false;
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

  Set<String> get favoriteIds => _favoriteIds;

  bool get isLoggedIn => _isLoggedIn;
  String? get userName => _userName;

  void login(String name) {
    _isLoggedIn = true;
    _userName = name;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _userName = null;
    notifyListeners();
  }
}
