import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  String _selectedLanguage = 'TH';

  String get selectedLanguage => _selectedLanguage;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedLanguage = prefs.getString('selected_language') ?? 'TH';
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _selectedLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', language);
    notifyListeners();
  }
  
  // Helper to get locale for Material App if needed, though we are doing custom translation map for now.
  // But for date pickers etc, we might want real Locales.
  Locale get locale {
    switch (_selectedLanguage) {
      case 'EN':
        return const Locale('en', 'US');
      case 'LO':
        return const Locale('lo', 'LA');
      case '中文':
        return const Locale('zh', 'CN');
      case '한국어':
        return const Locale('ko', 'KR');
      case 'TH':
      default:
        return const Locale('th', 'TH');
    }
  }
}
