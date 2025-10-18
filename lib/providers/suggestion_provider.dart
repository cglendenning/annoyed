import 'package:flutter/foundation.dart';
import '../models/suggestion.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';

class SuggestionProvider with ChangeNotifier {
  List<Suggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  List<Suggestion> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get suggestionCount => _suggestions.length;

  /// Load user suggestions
  Future<void> loadSuggestions(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _suggestions = await FirebaseService.getUserSuggestions(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error loading suggestions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generate a new suggestion
  Future<Suggestion?> generateSuggestion({
    required String uid,
    required String category,
    required String trigger,
  }) async {
    try {
      final result = await FirebaseService.generateSuggestion(
        uid: uid,
        category: category,
        trigger: trigger,
      );

      final suggestion = Suggestion(
        id: '', // Will be set by Firestore
        uid: uid,
        annoyanceId: '', // Can be set if we track which annoyance triggered this
        timestamp: DateTime.now(),
        text: result['text'] ?? 'Take a deep breath and reassess.',
        category: category,
        type: result['type'] ?? 'behavior',
        durationDays: result['days'] ?? 5,
      );

      final id = await FirebaseService.saveSuggestion(suggestion);

      // Log analytics
      await AnalyticsService.logSuggestionShown(id);

      // Reload suggestions
      await loadSuggestions(uid);

      return suggestion.copyWith(id: id);
    } catch (e) {
      _error = e.toString();
      print('Error generating suggestion: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update suggestion resonance (HELL YES / Meh)
  Future<void> setResonance(
    Suggestion suggestion,
    String resonance, // 'hell_yes' or 'meh'
  ) async {
    try {
      final updated = suggestion.copyWith(
        resonance: resonance,
        resonanceTimestamp: DateTime.now(),
      );

      await FirebaseService.updateSuggestion(updated);

      // Log analytics
      if (resonance == 'hell_yes') {
        await AnalyticsService.logResonanceHellYes(suggestion.id);
      } else {
        await AnalyticsService.logResonanceMeh(suggestion.id);
      }

      // Reload suggestions
      await loadSuggestions(suggestion.uid);
    } catch (e) {
      _error = e.toString();
      print('Error setting resonance: $e');
      notifyListeners();
    }
  }

  /// Mark suggestion as completed
  Future<void> markCompleted(Suggestion suggestion) async {
    try {
      final updated = suggestion.copyWith(
        completedTimestamp: DateTime.now(),
      );

      await FirebaseService.updateSuggestion(updated);

      // Log analytics
      await AnalyticsService.logDidIt(suggestion.id);

      // Reload suggestions
      await loadSuggestions(suggestion.uid);
    } catch (e) {
      _error = e.toString();
      print('Error marking completed: $e');
      notifyListeners();
    }
  }

  /// Get count of suggestions for paywall check
  Future<int> getSuggestionCount(String uid) async {
    return await FirebaseService.getUserSuggestionCount(uid);
  }
}







