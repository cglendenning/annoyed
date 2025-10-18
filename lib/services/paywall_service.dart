import '../services/firebase_service.dart';

class PaywallService {
  /// Check if user should see paywall based on OpenAI cost usage
  /// Free users: Show paywall at $0.10 spent
  /// Subscribed users: Hard stop at $0.50 per month
  static Future<Map<String, dynamic>> getCostStatus(String uid) async {
    try {
      return await FirebaseService.getUserCostStatus(uid: uid);
    } catch (e) {
      print('Error getting cost status: $e');
      // Return safe defaults on error
      return {
        'currentCost': 0.0,
        'limit': 0.10,
        'isSubscribed': false,
        'canUseAI': true,
        'percentUsed': 0,
      };
    }
  }

  /// Check if user should see paywall before using AI features
  static Future<bool> shouldShowPaywall(String uid, bool isPro) async {
    // If already pro, check against hard limit
    final status = await getCostStatus(uid);
    
    // If they can't use AI at all, show paywall/limit message
    if (!status['canUseAI']) {
      return true;
    }
    
    // For free users, show paywall if they're close to limit (90%+)
    if (!status['isSubscribed'] && status['percentUsed'] >= 90) {
      return true;
    }
    
    return false;
  }
  
  /// Get a user-friendly message about their usage
  static Future<String> getUsageMessage(String uid) async {
    final status = await getCostStatus(uid);
    final cost = status['currentCost'] as double;
    final limit = status['limit'] as double;
    final isSubscribed = status['isSubscribed'] as bool;
    final percent = status['percentUsed'] as int;
    
    if (!status['canUseAI']) {
      if (isSubscribed) {
        return 'You\'ve reached your monthly limit of \$${limit.toStringAsFixed(2)}. Your usage will reset at the start of next month.';
      } else {
        return 'You\'ve used your free trial (\$${cost.toStringAsFixed(2)} of \$${limit.toStringAsFixed(2)}). Subscribe to continue!';
      }
    }
    
    if (percent >= 75) {
      return 'You\'ve used $percent% of your ${isSubscribed ? "monthly" : "free"} usage (\$${cost.toStringAsFixed(3)}/\$${limit.toStringAsFixed(2)})';
    }
    
    return '';
  }
}








