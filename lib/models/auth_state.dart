/// Represents all possible authentication states in the app.
/// This is the single source of truth for what screen/flow the user should see.
enum AuthState {
  /// App just launched, checking Firebase Auth and loading initial state
  initializing,

  /// New user needs to see onboarding screens
  needsOnboarding,

  /// User is viewing onboarding screens
  onboardingInProgress,

  /// User is signed in anonymously and using the app normally
  anonymousActive,

  /// Anonymous user has hit the 5-annoyance limit and must sign up
  /// This is a HARD gate - no "continue as guest" option
  anonymousAtAuthWall,

  /// User is signed in with email and using the app normally
  authenticatedActive,

  /// User has email account but hasn't verified their email yet
  /// This is a blocking state - must verify to continue
  authenticatedUnverified,

  /// In progress: upgrading anonymous account to email account
  upgradingAnonymous,

  /// In progress: signing in with existing email account
  signingIn,

  /// In progress: signing out
  signingOut,

  /// An error occurred during auth operation
  /// Will auto-retry with timeout, or show user action if retry fails
  authError,
}

/// Extension to add helper methods to AuthState
extension AuthStateExtension on AuthState {
  /// Whether this state represents an active user session
  bool get isActive => this == AuthState.anonymousActive || 
                       this == AuthState.authenticatedActive;

  /// Whether this state represents a loading/transitional state
  bool get isLoading => this == AuthState.initializing ||
                        this == AuthState.upgradingAnonymous ||
                        this == AuthState.signingIn ||
                        this == AuthState.signingOut;

  /// Whether this state represents a blocking state (user can't proceed)
  bool get isBlocking => this == AuthState.anonymousAtAuthWall ||
                         this == AuthState.authenticatedUnverified ||
                         this == AuthState.authError;
}

