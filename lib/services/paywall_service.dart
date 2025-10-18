import '../services/firebase_service.dart';

class PaywallService {
  /// Check if user should see paywall before getting next suggestion
  /// Free trial: through First Pattern Report + two daily suggestions
  /// Paywall: after the first two Coach Mode suggestions (3rd suggestion onwards)
  static Future<bool> shouldShowPaywall(String uid, bool isPro) async {
    // If already pro, never show paywall
    if (isPro) return false;

    // Get suggestion count
    final suggestionCount = await FirebaseService.getUserSuggestionCount(uid);

    // Show paywall if user has received 2 or more suggestions
    return suggestionCount >= 2;
  }
}







