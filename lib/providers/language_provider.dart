import 'package:flutter/material.dart';

enum UserRole {
  patient,
  doctor,
  secretary,
  admin,
  security,
  dental_student
}

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('ar');
  bool _isEnglish = false;
  UserRole? _currentUserRole;

  Locale get currentLocale => _currentLocale;
  bool get isEnglish => _isEnglish;
  UserRole? get currentUserRole => _currentUserRole;

  void toggleLanguage() {
    _isEnglish = !_isEnglish;
    _currentLocale = _isEnglish ? const Locale('en') : const Locale('ar');
    notifyListeners();
  }

  void setUserRole(UserRole role) {
    _currentUserRole = role;
    notifyListeners();
  }
}