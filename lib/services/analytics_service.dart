import 'firebase_service.dart';

/// Analytics service for tracking user events (no PII)
class AnalyticsService {
  // Event types
  static const String eventInstall = 'install';
  static const String eventPermissionMicGranted = 'permission_mic_granted';
  static const String eventAnnoyanceSaved = 'annoyance_saved';
  static const String eventPatternReportShown = 'pattern_report_shown';
  static const String eventCoachYes = 'coach_yes';
  static const String eventCoachNotNow = 'coach_not_now';
  static const String eventSuggestionShown = 'suggestion_shown';
  static const String eventResonanceHellYes = 'resonance_hell_yes';
  static const String eventResonanceMeh = 'resonance_meh';
  static const String eventDidIt = 'did_it';
  static const String eventPaywallView = 'paywall_view';
  static const String eventTrialStart = 'trial_start';
  static const String eventSubStart = 'sub_start';
  static const String eventDeleteAll = 'delete_all';

  /// Log an event
  static Future<void> logEvent(String type, {Map<String, dynamic>? meta}) async {
    await FirebaseService.logEvent(type, meta);
  }

  // Convenience methods for specific events
  static Future<void> logInstall() async {
    await logEvent(eventInstall);
  }

  static Future<void> logPermissionMicGranted() async {
    await logEvent(eventPermissionMicGranted);
  }

  static Future<void> logAnnoyanceSaved(String category) async {
    await logEvent(eventAnnoyanceSaved, meta: {'category': category});
  }

  static Future<void> logPatternReportShown() async {
    await logEvent(eventPatternReportShown);
  }

  static Future<void> logCoachYes() async {
    await logEvent(eventCoachYes);
  }

  static Future<void> logCoachNotNow() async {
    await logEvent(eventCoachNotNow);
  }

  static Future<void> logSuggestionShown(String suggestionId) async {
    await logEvent(eventSuggestionShown, meta: {'suggestion_id': suggestionId});
  }

  static Future<void> logResonanceHellYes(String suggestionId) async {
    await logEvent(eventResonanceHellYes, meta: {'suggestion_id': suggestionId});
  }

  static Future<void> logResonanceMeh(String suggestionId) async {
    await logEvent(eventResonanceMeh, meta: {'suggestion_id': suggestionId});
  }

  static Future<void> logDidIt(String suggestionId) async {
    await logEvent(eventDidIt, meta: {'suggestion_id': suggestionId});
  }

  static Future<void> logPaywallView() async {
    await logEvent(eventPaywallView);
  }

  static Future<void> logTrialStart() async {
    await logEvent(eventTrialStart);
  }

  static Future<void> logSubStart() async {
    await logEvent(eventSubStart);
  }

  static Future<void> logDeleteAll() async {
    await logEvent(eventDeleteAll);
  }
}







