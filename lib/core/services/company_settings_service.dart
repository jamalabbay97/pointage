import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/company_settings.dart';

class CompanySettingsService {
  static const _cacheKey = 'cached_company_settings_v1';
  static CompanySettings? _memoryCache;

  /// Retrieves the current company settings with offline-first caching.
  /// If offline or on network error/timeout, it immediately returns the cached settings.
  static Future<CompanySettings> getSettings({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _memoryCache != null) {
      return _memoryCache!;
    }

    // 1. Try reading from SharedPreferences cache first
    final cachedSettings = await _loadFromCache();
    if (cachedSettings != null) {
      _memoryCache = cachedSettings;
    }

    // 2. Fetch from Firestore with a fast 3-second timeout
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('company')
          .get()
          .timeout(const Duration(seconds: 3));

      if (doc.exists && doc.data() != null) {
        final settings = CompanySettings.fromJson(doc.data()!);
        _memoryCache = settings;
        await _saveToCache(settings);
        return settings;
      }
    } catch (e) {
      debugPrint(
        'Warning: Could not fetch company settings online ($e). Using cached.',
      );
    }

    // Return cached settings if available, else hardcoded default
    return _memoryCache ?? CompanySettings.defaultSettings;
  }

  /// Synchronous memory cache getter if available
  static CompanySettings get currentSettings =>
      _memoryCache ?? CompanySettings.defaultSettings;

  /// Loads settings from local SharedPreferences cache
  static Future<CompanySettings?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> json = jsonDecode(raw);
      return CompanySettings.fromJson(json);
    } catch (e) {
      debugPrint('Error reading cached company settings: $e');
      return null;
    }
  }

  /// Saves settings to local SharedPreferences cache
  static Future<void> _saveToCache(CompanySettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('Error saving company settings to cache: $e');
    }
  }

  /// Updates settings both locally and in Firestore
  static Future<void> updateSettings(CompanySettings newSettings) async {
    _memoryCache = newSettings;
    await _saveToCache(newSettings);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('company')
          .set(newSettings.toJson(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error saving company settings to Firestore: $e');
      rethrow;
    }
  }
}
