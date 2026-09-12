import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/backend/services/api_service.dart';

class AppLocaleService {
  const AppLocaleService._();

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
    Locale('fr'),
    Locale('es'),
    Locale('ar'),
  ];

  static const defaultLocale = Locale('en');

  static Future<void> setLocale(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', locale.languageCode);
    _syncWithBackend(locale.languageCode);
  }

  static Future<void> _syncWithBackend(String languageCode) async {
    try {
      await ApiService.request(
        method: 'PUT',
        path: '/settings/language',
        body: {'language': languageCode},
      );
    } catch (error) {
      debugPrint('LANGUAGE BACKEND ERROR: $error');
    }
  }

  static Future<void> resetToEnglish(BuildContext context) async {
    if (context.locale != defaultLocale) {
      await context.setLocale(defaultLocale);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', defaultLocale.languageCode);
  }
}
