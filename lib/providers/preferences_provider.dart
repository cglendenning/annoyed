import 'package:flutter/foundation.dart';
import '../models/user_preferences.dart';
import '../services/firebase_service.dart';

class PreferencesProvider with ChangeNotifier {
  UserPreferences? _preferences;
  bool _isLoading = false;
  String? _error;

  UserPreferences? get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPro => _preferences?.isPro ?? false;

  /// Load user preferences
  Future<void> loadPreferences(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _preferences = await FirebaseService.getUserPreferences(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading preferences: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update preferred hours
  Future<void> updatePreferredHours({
    required String uid,
    required String goodStart,
    required String goodEnd,
  }) async {
    try {
      final updated = (_preferences ?? UserPreferences(uid: uid)).copyWith(
        goodStart: goodStart,
        goodEnd: goodEnd,
      );

      await FirebaseService.updateUserPreferences(updated);
      _preferences = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating preferred hours: $e');
      notifyListeners();
    }
  }

  /// Update DND respect
  Future<void> updateDndRespect({
    required String uid,
    required bool dndRespect,
  }) async {
    try {
      final updated = (_preferences ?? UserPreferences(uid: uid)).copyWith(
        dndRespect: dndRespect,
      );

      await FirebaseService.updateUserPreferences(updated);
      _preferences = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating DND respect: $e');
      notifyListeners();
    }
  }

  /// Update pro status
  Future<void> updateProStatus({
    required String uid,
    required DateTime? proUntil,
  }) async {
    try {
      final updated = (_preferences ?? UserPreferences(uid: uid)).copyWith(
        proUntil: proUntil,
      );

      await FirebaseService.updateUserPreferences(updated);
      _preferences = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating pro status: $e');
      notifyListeners();
    }
  }
}








