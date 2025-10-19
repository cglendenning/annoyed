/// Application-wide constants
class AppConstants {
  // Recording
  static const int maxRecordingSeconds = 30;
  static const int transcriptMaxLines = 3;
  
  // Coaching
  static const int annoyancesPerCoaching = 5;
  static const int annoyancesForAuthGate = 5; // Show sign-up prompt after N annoyances
  static const int minAnnoyancesForPatterns = 3;
  static const int loadingMessageIntervalSeconds = 3;
  static const int newAnnoyancesForCoachingRegeneration = 5;
  
  // Delays and timeouts
  static const int snackbarShortDelayMs = 800;
  static const int snackbarStandardDelayMs = 1500;
  static const Duration snackbarShortDuration = Duration(seconds: 1);
  static const Duration snackbarStandardDuration = Duration(seconds: 2);
  static const Duration feedbackAutoCloseDuration = Duration(seconds: 2);
  
  // Limits
  static const int maxCoachingHistory = 100;
  static const int maxAnnoyancesForAnalysis = 15;
  static const int daysForCoachingAnalysis = 7;
  
  // Cost limits
  static const double freeUserCostLimit = 0.10;
  static const double subscribedUserCostLimit = 0.50;
  static const int costWarningPercentage = 90;
  
  // Animation durations
  static const Duration gradientAnimationDuration = Duration(seconds: 3);
  static const Duration gradientAnimationDurationSlow = Duration(seconds: 4);
  static const Duration gradientAnimationDurationFast = Duration(seconds: 2);
  
  // Security
  static const int maxAnnoyanceLength = 5000;
  static const int passwordResetThrottleSeconds = 60;
  static const int maxLoadingMessageIterations = 60; // 3 minutes max
}

/// Error messages - use generic messages to prevent account enumeration
class AppErrorMessages {
  static const String invalidCredentials = 'Invalid email or password';
  static const String authenticationFailed = 'Authentication failed. Please try again.';
  static const String emailAlreadyInUse = 'This email is already registered. Try signing in.';
  static const String weakPassword = 'Password is too weak. Use at least 8 characters with uppercase, lowercase, and numbers.';
}

