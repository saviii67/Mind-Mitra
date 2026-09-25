import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_session.dart';
import '../models/patient_profile.dart';
import '../models/cognitive_score.dart';
import 'localization_service.dart';
import 'gemini_config.dart';

/// Storage & Offline-First Sync Service
/// Manages User Login Profile, Gemini API Key, Game Sessions, Cognitive Score, and Cloud Sync
class StorageService {
  StorageService._();

  static const String _sessionsKey = 'mindmitra_game_sessions_v3';
  static const String _profileKey = 'mindmitra_patient_profile_v3';
  static const String _isLoggedInKey = 'mindmitra_is_logged_in';
  static const String _scoreKey = 'mindmitra_cognitive_score_v3';
  static const String _moodKey = 'mindmitra_daily_mood_v3';
  static const String _isOnlineKey = 'mindmitra_simulated_online';
  static const String _geminiKeyPref = 'mindmitra_gemini_api_key';

  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<int> unsyncedCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<PatientProfile> profileNotifier =
      ValueNotifier<PatientProfile>(PatientProfile.defaultProfile());
  static final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> geminiApiKeyNotifier =
      ValueNotifier<String>(kDefaultGeminiApiKey);
  static final ValueNotifier<int> dataVersionNotifier = ValueNotifier<int>(0);

  static String get _userSessionsKey => '${_sessionsKey}_${profileNotifier.value.id}';
  static String get _userScoreKey => '${_scoreKey}_${profileNotifier.value.id}';
  static String get _userMoodKey => '${_moodKey}_${profileNotifier.value.id}';

  /// Initializes storage and loads saved user profile & Gemini key
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isOnlineNotifier.value = prefs.getBool(_isOnlineKey) ?? true;
    isLoggedInNotifier.value = prefs.getBool(_isLoggedInKey) ?? false;

    final savedKey = prefs.getString(_geminiKeyPref);
    if (savedKey != null && savedKey.trim().isNotEmpty) {
      geminiApiKeyNotifier.value = savedKey.trim();
    } else {
      geminiApiKeyNotifier.value = kDefaultGeminiApiKey.trim();
    }

    final loadedProfile = await getPatientProfile();
    profileNotifier.value = loadedProfile;
    LocalizationService.setLanguage(loadedProfile.selectedLanguage);

    await _updateUnsyncedCount();
    dataVersionNotifier.value++;
  }

  /// Save Google Gemini API Key locally and notify listeners
  static Future<void> saveGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = apiKey.trim();
    await prefs.setString(_geminiKeyPref, clean);
    geminiApiKeyNotifier.value = clean.isNotEmpty ? clean : kDefaultGeminiApiKey.trim();
  }

  /// Log in with a new user profile and start with fresh, isolated progress
  static Future<void> loginWithProfile(PatientProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, profile.toJson());
    await prefs.setBool(_isLoggedInKey, true);
    profileNotifier.value = profile;
    LocalizationService.setLanguage(profile.selectedLanguage);
    // Ensure a brand-new login starts with 0 sessions and fresh progress
    await prefs.remove(_userSessionsKey);
    await prefs.remove(_userScoreKey);
    await _updateUnsyncedCount();
    dataVersionNotifier.value++;
    isLoggedInNotifier.value = true;
  }

  /// Log out to return to the Login / Profile Setup screen
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    isLoggedInNotifier.value = false;
    dataVersionNotifier.value++;
  }

  static Future<void> toggleOnlineOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final newState = !isOnlineNotifier.value;
    isOnlineNotifier.value = newState;
    await prefs.setBool(_isOnlineKey, newState);
    if (newState) {
      await syncPendingSessions();
    }
  }

  static Future<void> saveGameSession(GameSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getGameSessions();
    final updatedSession = session.copyWith(isSynced: isOnlineNotifier.value);
    sessions.insert(0, updatedSession);

    final raw = jsonEncode(sessions.map((s) => s.toMap()).toList());
    await prefs.setString(_userSessionsKey, raw);
    await _updateUnsyncedCount();
    dataVersionNotifier.value++;
  }

  static Future<List<GameSession>> getGameSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userSessionsKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => GameSession.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<int> syncPendingSessions() async {
    if (!isOnlineNotifier.value) return 0;
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getGameSessions();
    int syncedCount = 0;
    final syncedList = sessions.map((s) {
      if (!s.isSynced) {
        syncedCount++;
        return s.copyWith(isSynced: true);
      }
      return s;
    }).toList();

    await prefs.setString(_userSessionsKey, jsonEncode(syncedList.map((s) => s.toMap()).toList()));
    await _updateUnsyncedCount();
    dataVersionNotifier.value++;
    return syncedCount;
  }

  static Future<void> _updateUnsyncedCount() async {
    final sessions = await getGameSessions();
    final pending = sessions.where((s) => !s.isSynced).length;
    unsyncedCountNotifier.value = pending;
  }

  static Future<void> saveDailyMood(String moodEmoji) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('${_userMoodKey}_$now', moodEmoji);
    dataVersionNotifier.value++;
  }

  static Future<String?> getTodayMood() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String().substring(0, 10);
    return prefs.getString('${_userMoodKey}_$now');
  }

  static Future<PatientProfile> getPatientProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null) {
      try {
        return PatientProfile.fromJson(raw);
      } catch (_) {}
    }
    return PatientProfile.defaultProfile();
  }

  static Future<void> savePatientProfile(PatientProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, profile.toJson());
    profileNotifier.value = profile;
    dataVersionNotifier.value++;
  }

  static Future<CognitiveScore> getCognitiveScore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userScoreKey);
    if (raw != null) {
      try {
        return CognitiveScore.fromMap(jsonDecode(raw));
      } catch (_) {}
    }
    return CognitiveScore.initial();
  }

  static Future<void> saveCognitiveScore(CognitiveScore score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userScoreKey, jsonEncode(score.toMap()));
  }
}
