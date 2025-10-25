# Annoyed — Personal Friction Coach

**Annoyed → Aligned.**

A focused personal coach that meets you in two moments of your day: when something irritates you (Capture Mode) and when you're ready for actionable coaching (Coach Mode).

---

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Setup Guide](#setup-guide)
- [Authentication Flow](#authentication-flow)
- [Cost Protection](#cost-protection)
- [Firebase Functions](#firebase-functions)
- [Development](#development)
- [Deployment](#deployment)
- [App Store Submission](#app-store-submission)
- [Legal & Compliance](#legal--compliance)
- [Coaching Screens](#coaching-screens)
- [Troubleshooting](#troubleshooting)

---

## Features

### Capture Mode
- **Tap-to-record** voice capture (30s, on-device transcription)
- **Auto-categorization** into 5 patterns: Boundaries, Environment, Systems Debt, Communication, Energy
- **PII redaction** before any network call
- **Text fallback** if mic is unavailable

### Coach Mode
- **4-screen immersive coaching experience** with swipeable interface
- **Mindset Shift** — Personalized recommendations with inspirational backgrounds
- **Deep Dive** — Action steps with native text-to-speech functionality
- **Annoyance Analysis** — Beautiful pie charts and data visualizations
- **Wisdom & CTA** — Deep quotes and 1:1 coaching invitation
- **Coaching history** — all past coaching sessions saved permanently
- **One action only** — no overwhelm

### Privacy First
- Audio **never leaves your phone** (on-device transcription only)
- Client-side PII redaction
- User-controlled data deletion (GDPR compliant)

---

## Quick Start

### Prerequisites
- Flutter SDK (3.x+)
- Firebase account
- OpenAI API key
- RevenueCat account (for IAP)
- Xcode (iOS) / Android Studio (Android)

### Installation

1. **Clone and install dependencies**
```bash
git clone <repo-url>
cd annoyed
flutter pub get
cd functions && npm install && cd ..
```

2. **Create environment file**
Create `.env` in the project root:
```
REVENUECAT_IOS_KEY=your_ios_key
REVENUECAT_ANDROID_KEY=your_android_key
```

3. **Set up Firebase** (see detailed guide below)
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure --project=your-project-id

# Deploy functions
cd functions
firebase login
firebase use --add
firebase functions:config:set openai.key="your-openai-key"
firebase deploy --only functions
```

4. **Deploy Firestore rules and indexes**
```bash
firebase deploy --only firestore:rules,firestore:indexes
```

5. **Run the app**
```bash
flutter run --release
```

---

## Tech Stack

- **Frontend**: Flutter (iOS + Android)
- **Backend**: Firebase (Auth, Firestore, Cloud Functions)
- **AI**: OpenAI GPT-4o-mini for classification and coaching
- **Payments**: RevenueCat for cross-platform subscriptions
- **Speech**: Platform native speech recognition (iOS Speech Framework, Android SpeechRecognizer)

---

## Project Structure

```
lib/
├── models/              # Data models (Annoyance, Suggestion, AuthState)
│   ├── annoyance.dart
│   ├── suggestion.dart
│   ├── user_preferences.dart
│   └── auth_state.dart              # NEW: Auth state enum
├── providers/           # State management (Provider)
│   ├── auth_state_manager.dart      # NEW: Single source of truth for auth
│   ├── annoyance_provider.dart
│   ├── suggestion_provider.dart
│   └── preferences_provider.dart
├── screens/             # UI screens (17 screens)
├── services/            # Business logic (Firebase, Speech, Analytics, Paywall)
├── utils/              # Utilities (Colors, Constants, Validators)
├── widgets/             # Reusable UI components
└── main.dart            # App entry point + AuthGate declarative router

functions/
├── index.js             # Cloud Functions (classify, suggest, coaching)
├── package.json         # Node dependencies
└── README.md            # Functions documentation

firestore.rules          # Firestore security rules
firestore.indexes.json   # Composite indexes for queries
```

---

## Setup Guide

### Step 1: Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create project: "annoyed" (or your preferred name)
3. Add iOS app: bundle ID `com.cglendenning.annoyed`
4. Add Android app: package `com.cglendenning.annoyed`
5. Download config files:
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`
   - Android: `google-services.json` → `android/app/`

### Step 2: Firebase Services

#### Authentication
1. Enable "Anonymous" sign-in
2. Enable "Email/Password" sign-in

#### Firestore Database
1. Create database (production mode)
2. Select region (closest to your users)
3. Deploy security rules:
```bash
firebase deploy --only firestore:rules
```

#### Cloud Functions
```bash
cd functions
npm install
firebase login
firebase use --add  # Select your project
firebase functions:config:set openai.key="YOUR_OPENAI_KEY"
firebase deploy --only functions
```

### Step 3: RevenueCat Setup

1. Create account at [RevenueCat](https://www.revenuecat.com/)
2. Create products:
   - `pro_monthly` — $3.99/month
   - `pro_annual` — $24.99/year
3. Link to App Store Connect / Google Play Console
4. Add API keys to `.env` file

---

## Authentication Architecture

### Overview: Single Source of Truth

The app uses a clean **state machine architecture** where Firebase Auth is the **only source of truth** for authentication state. Everything else derives from it—no parallel state tracking, no race conditions, no navigation complexity.

### Core Principle

```
Firebase Auth (changes) 
    ↓
AuthStateManager (listens via authStateChanges)
    ↓  
Computes AuthState from Firebase + 2 minimal flags
    ↓
notifyListeners()
    ↓
AuthGate (Consumer) rebuilds
    ↓
Shows correct screen declaratively (switch statement)
```

### The Auth State Machine

**10 Finite States:**

```dart
enum AuthState {
  // Initial
  initializing,              // App just launched, checking Firebase Auth
  
  // Onboarding
  needsOnboarding,          // New user, show onboarding
  onboardingInProgress,     // User in onboarding flow
  
  // Anonymous
  anonymousActive,          // Signed in anonymously, using app normally
  anonymousAtAuthWall,      // Hit 5 annoyances, MUST upgrade (hard gate)
  
  // Authenticated
  authenticatedActive,      // Signed in with email, using app normally
  
  // Transitional
  upgradingAnonymous,       // Linking anonymous to email (in progress)
  signingIn,                // Signing in with email (in progress)
  signingOut,               // Signing out (in progress)
  
  // Error
  authError,                // Operation failed, show retry/cancel
}
```

### State Transitions

```
initializing
  ├─→ needsOnboarding (no onboarding flag + no Firebase user)
  ├─→ anonymousActive (onboarding done + anonymous user)
  ├─→ anonymousAtAuthWall (onboarding done + anonymous + hit wall)
  └─→ authenticatedActive (onboarding done + email user)

needsOnboarding
  └─→ onboardingInProgress (user starts onboarding)

onboardingInProgress
  └─→ anonymousActive (completes, auto-signs in anonymously)

anonymousActive
  ├─→ anonymousAtAuthWall (records 5th annoyance)
  ├─→ upgradingAnonymous (chooses to sign up)
  └─→ signingIn (chooses to sign in with existing account)

anonymousAtAuthWall (HARD GATE - no bypass)
  ├─→ upgradingAnonymous (user signs up)
  └─→ signingIn (user signs in instead)

upgradingAnonymous
  ├─→ authenticatedActive (success, UID preserved!)
  └─→ authError (failure)

signingIn
  ├─→ authenticatedActive (success)
  └─→ authError (failure)

authenticatedActive
  └─→ signingOut (user signs out)

signingOut
  └─→ anonymousActive (signs back in anonymously)

authError
  ├─→ [previous state] (retry or cancel)
  └─→ [auto-retry up to 3x with exponential backoff]
```

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Firebase Auth                           │
│  (Single Source of Truth for User Identity)                 │
│                                                             │
│  • authStateChanges() stream                                │
│  • currentUser.uid (preserved during linking)               │
│  • currentUser.isAnonymous                                  │
│  • currentUser.email                                        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ Stream of User? objects
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                  AuthStateManager                           │
│  (Computes AuthState from Firebase + minimal flags)         │
│                                                             │
│  Inputs:                                                    │
│   • Firebase Auth User? (from stream)                       │
│   • SharedPrefs: onboarding_completed (bool)                │
│   • SharedPrefs: auth_wall_hit (bool)                       │
│                                                             │
│  Output:                                                    │
│   • AuthState enum (via ChangeNotifier)                     │
│                                                             │
│  Actions:                                                   │
│   • upgradeToEmail() → calls linkWithCredential()           │
│   • signInWithEmail() → calls signInWithEmailAndPassword()  │
│   • triggerAuthWall() → sets flag, recomputes state         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ AuthState enum
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                       AuthGate                              │
│  (Declarative Router - switches on state)                   │
│                                                             │
│  switch (authState) {                                       │
│    case anonymousActive: return HomeScreen();               │
│    case anonymousAtAuthWall: return AuthWallScreen();       │
│    case authenticatedActive: return HomeScreen();           │
│    // etc...                                                │
│  }                                                          │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                      UI Screens                             │
│  (No navigation logic, just trigger actions)                │
│                                                             │
│  • HomeScreen: authStateManager.triggerAuthWall()           │
│  • EmailAuthScreen: authStateManager.signInWithEmail()      │
│  • AuthWallScreen: authStateManager.upgradeToEmail()        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      Firestore                              │
│  (Data storage, keyed by Firebase UID)                      │
│                                                             │
│  /annoyances/{doc} → uid field                              │
│  /users/{uid} → user profile                                │
│  /coaching/{doc} → uid field                                │
│                                                             │
│  NO MIGRATION NEEDED:                                       │
│  linkWithCredential() preserves UID, so all documents       │
│  remain accessible with the same uid query                  │
└─────────────────────────────────────────────────────────────┘
```

### Authentication Flows

#### New User Flow
```
1. Launch app → AuthState.initializing
2. No Firebase user → AuthState.needsOnboarding  
3. AuthGate shows OnboardingScreen
4. User completes → authStateManager.completeOnboarding()
5. Signs in anonymously → AuthState.anonymousActive
6. AuthGate shows HomeScreen (automatic!)
```

#### Auth Wall Flow (After 5 Annoyances)
```
1. User records 5th annoyance
2. HomeScreen calls authStateManager.triggerAuthWall()
3. State changes to AuthState.anonymousAtAuthWall
4. AuthGate automatically shows AuthWallScreen (no manual navigation!)
5. User signs up → authStateManager.upgradeToEmail()
6. Firebase links credential, UID preserved
7. State changes to AuthState.authenticatedActive
8. AuthGate automatically shows HomeScreen
```

#### Sign-In Flow (Returning User)
```
1. User has signed in before, app launches
2. Firebase has email user → AuthState.authenticatedActive
3. AuthGate shows HomeScreen immediately
```

#### Sign-Out Flow
```
1. User taps Sign Out in settings
2. authStateManager.signOut() called
3. Firebase signs out → authStateChanges fires
4. State changes to AuthState.anonymousActive
5. AuthGate automatically shows appropriate screen
```

### Firebase Native Account Linking

Uses `User.linkWithCredential()` — Firebase's built-in method:

```dart
// Step 1: Anonymous sign-in
await FirebaseAuth.instance.signInAnonymously();
// uid: "abc123xyz"

// Step 2: User records annoyances
// All stored with uid: "abc123xyz"

// Step 3: Link to email (at auth wall)
final credential = EmailAuthProvider.credential(email, password);
await currentUser.linkWithCredential(credential);
// uid: STILL "abc123xyz" (preserved automatically!)

// Step 4: All data remains accessible
// No migration needed - same UID queries work
```

**Why This Works:**
- ✅ Firebase preserves UID automatically during linking
- ✅ All Firestore documents keep the same `uid` field
- ✅ No custom migration code needed
- ✅ No risk of data loss

### Persistence Strategy (Minimal State)

**Only 2 SharedPreferences flags:**

```dart
{
  // Flag 1: Has user completed onboarding?
  // Cleared: Never (one-time setup)
  'onboarding_completed': true,
  
  // Flag 2: Has anonymous user hit the auth wall?
  // Cleared: When they upgrade OR sign out
  'auth_wall_hit': true,
}
```

**Everything else from Firebase Auth:**
- User ID → `FirebaseAuth.instance.currentUser?.uid`
- Is Anonymous → `FirebaseAuth.instance.currentUser?.isAnonymous`  
- Has Email → `FirebaseAuth.instance.currentUser?.email != null`
- Is Authenticated → `FirebaseAuth.instance.currentUser != null`

### Error Recovery

**Auto-Retry Logic:**
- Failed operations retry up to 3 times
- Exponential backoff: 2s, 4s, 6s
- 30-second timeout on all operations
- Clear error messages for users

**Error Screen:**
- Shows specific error (email-already-in-use, network timeout, etc.)
- "Try Again" button → retryLastOperation()
- "Cancel" button → returns to previous state

### Benefits

✨ **Predictable** — Finite states = finite behaviors  
✨ **Testable** — Each state transition can be unit tested  
✨ **Debuggable** — Single place to log all state changes  
✨ **No Race Conditions** — Single Firebase listener, single state computation  
✨ **Firebase Native** — Uses `linkWithCredential()`, no custom migration  
✨ **Maintainable** — Want to add a new auth flow? Just add a state!  
✨ **Declarative UI** — AuthGate automatically shows right screen for state  

### File Structure

```
lib/
├── models/
│   └── auth_state.dart              # AuthState enum + extensions
├── providers/
│   └── auth_state_manager.dart      # Single source of truth (500+ lines)
└── main.dart                         # AuthGate declarative router (70 lines)
```

**Removed:**
- ❌ `auth_provider.dart` — Replaced by AuthStateManager
- ❌ Manual navigation code in screens
- ❌ Auth state listeners in UI components
- ❌ Lifecycle observers checking auth state
- ❌ Multiple sources of truth fighting each other

---

## Cost Protection

### Overview
Comprehensive OpenAI API cost tracking and limits to prevent overages.

### Limits
- **Free users**: $0.10/month → Show paywall
- **Subscribed users**: $0.50/month → Hard stop until reset
- **Monthly reset**: Automatic on 1st of each month

### Protected Functions
1. **classifyAnnoyance** (~$0.0001 per call)
2. **generateSuggestion** (~$0.0002 per call) 
3. **generateCoaching** (~$0.002 per call) — Most expensive

### Cost Tracking
All API calls logged to `llm_cost` collection:
```javascript
{
  uid, ts, model, tokens_in, tokens_out, 
  cost_usd, duration_ms, function, cache_hit
}
```

### Estimated Usage
- **Free users ($0.10)**: ~50 annoyances OR ~10 coaching sessions
- **Subscribed users ($0.50)**: ~250 annoyances OR ~50 coaching sessions

---

## Firebase Functions

### `classifyAnnoyance`
Classifies annoyance transcripts into categories using GPT-4o-mini.

**Input:** `{ text: string }`  
**Output:** `{ category: string, trigger: string, safe: boolean }`

### `generateSuggestion`
Generates actionable suggestions based on category and trigger.

**Input:** `{ uid: string, category: string, trigger: string }`  
**Output:** `{ type: string, text: string, days: number }`

### `generateCoaching`
Analyzes annoyance patterns (last 7 days, max 15) and generates personalized coaching.

**Input:** `{ uid: string, timestamp: number }`  
**Output:** `{ recommendation: string, type: string, explanation: string }`

### `getUserCostStatus`
Returns user's current OpenAI usage and limits.

**Input:** `{ uid: string }`  
**Output:** `{ currentCost, limit, isSubscribed, canUseAI, percentUsed }`

### Local Development
```bash
# Get config
firebase functions:config:get > .runtimeconfig.json

# Run emulator
firebase emulators:start --only functions
```

---

## Testing

### Test Suite Overview

Comprehensive tests for the auth state machine covering all 10 states and transitions.

**Test Files:**
- `test/auth_state_manager_test.dart` — Unit tests (state transitions, SharedPreferences, error handling)
- `test/auth_gate_widget_test.dart` — Widget tests (declarative routing, screen rendering)
- `test/auth_flows_integration_test.dart` — Integration tests (complete user flows, edge cases)

**Total:** 50+ tests, ~80% coverage, <15s runtime

### Quick Start

**First time setup:**
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

**Run all auth tests:**
```bash
./test_runner.sh
```

**Run with coverage report:**
```bash
./test_runner.sh --coverage
```

**Pre-run checks (recommended before deploying):**
```bash
./pre_run_checks.sh
```

**Run specific test files:**
```bash
# Unit tests only
flutter test test/auth_state_manager_test.dart

# Widget tests only
flutter test test/auth_gate_widget_test.dart

# Integration tests only
flutter test test/auth_flows_integration_test.dart

# All tests
flutter test

# Watch mode (auto-rerun on changes)
flutter test --watch
```

### Test Coverage

| Component | Coverage | Tests | Speed |
|-----------|----------|-------|-------|
| AuthStateManager | ~85% | 25+ | Fast (2s) |
| AuthGate Routing | ~90% | 10+ | Fast (3s) |
| Auth Flows | ~75% | 15+ | Medium (8s) |
| **Overall** | **~80%** | **50+** | **<15s** |

**Coverage Goals:**
- AuthStateManager: >85% ✅
- AuthGate: >90% ✅
- Auth Flows: >75% ✅
- Overall: >80% ✅

**Generate coverage report:**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html  # macOS
```

### What's Tested

#### All 10 Auth States
- ✅ `initializing` — App startup
- ✅ `needsOnboarding` — New user
- ✅ `onboardingInProgress` — User going through onboarding
- ✅ `anonymousActive` — Anonymous user, normal usage
- ✅ `anonymousAtAuthWall` — Hit 5 annoyances, must sign up
- ✅ `authenticatedActive` — Email user, normal usage
- ✅ `upgradingAnonymous` — Linking anonymous to email
- ✅ `signingIn` — Signing in with email
- ✅ `signingOut` — Signing out
- ✅ `authError` — Error occurred, show retry/cancel

#### State Transitions Verified
```
✅ initializing → needsOnboarding
✅ needsOnboarding → onboardingInProgress
✅ onboardingInProgress → anonymousActive
✅ anonymousActive → anonymousAtAuthWall (5th annoyance)
✅ anonymousAtAuthWall → upgradingAnonymous (sign up)
✅ upgradingAnonymous → authenticatedActive (success)
✅ upgradingAnonymous → authError (failure)
✅ authenticatedActive → signingOut
✅ signingOut → anonymousActive
✅ authError → [previous state] (retry/cancel)
```

#### Comprehensive Coverage
- ✅ State transitions follow the state machine
- ✅ Only 2 SharedPreferences flags (minimal persistence)
- ✅ Firebase UID preservation during account linking
- ✅ Declarative routing (no manual navigation)
- ✅ Error recovery with auto-retry
- ✅ State persistence across app restarts
- ✅ Edge cases (missing data, corrupted data, rapid changes)
- ✅ State extensions (isActive, isLoading, isBlocking)
- ✅ Error message handling for Firebase errors

### Test File Details

#### 1. Unit Tests: `auth_state_manager_test.dart`
**Tests:** AuthStateManager state transitions, SharedPreferences flags, error handling

**What it covers:**
- All 10 state definitions
- State extensions (isActive, isLoading, isBlocking)
- SharedPreferences flag management (only 2 flags)
- State transition validation
- Error message handling

#### 2. Widget Tests: `auth_gate_widget_test.dart`
**Tests:** AuthGate declarative routing, screen rendering based on state

**What it covers:**
- Loading screen for transitional states
- Error screen for authError state
- Correct screen shown for each state
- No manual navigation (design principle)
- State-based rendering

#### 3. Integration Tests: `auth_flows_integration_test.dart`
**Tests:** Complete user flows through the app

**What it covers:**
- New user journey (onboarding → anonymous → home)
- Auth wall flow (5 annoyances → sign up)
- Sign out flow (authenticated → anonymous)
- Error recovery flow
- State persistence across restarts
- Edge cases (missing data, corrupted data, rapid changes)
- UID preservation during account linking

### CI/CD Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter pub run build_runner build
      - run: flutter test
```

### Git Hook (Optional)

Run tests automatically on commit:

```bash
# .git/hooks/pre-commit
#!/bin/bash
./test_runner.sh || exit 1
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

### VS Code Integration (Optional)

Add to `.vscode/tasks.json`:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Run Auth Tests",
      "type": "shell",
      "command": "./test_runner.sh",
      "problemMatcher": [],
      "group": {
        "kind": "test",
        "isDefault": true
      }
    }
  ]
}
```

Then: `Cmd+Shift+P` → "Run Test Task"

### Troubleshooting

**"Command not found: ./test_runner.sh"**
```bash
chmod +x test_runner.sh pre_run_checks.sh
```

**"Mock generation failed"**
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

**"Firebase not initialized"**
Integration tests need Firebase setup. For unit tests, we use mocks.

**"Tests hang"**
Check for missing `await` in async tests or infinite loops. Add `await tester.pumpAndSettle()` after state changes in widget tests.

### Best Practices

✅ **DO:**
- Test state transitions, not implementation details
- Use descriptive test names
- Test edge cases (null, empty, corrupted data)
- Mock external dependencies (Firebase, SharedPreferences)
- Keep tests fast (<5s for unit tests)
- Run tests before every commit
- Monitor coverage regularly

❌ **DON'T:**
- Test Firebase Auth directly (use mocks)
- Test UI appearance (test behavior)
- Share state between tests (use setUp/tearDown)
- Skip cleanup (always dispose managers)

### Writing New Tests

**For New States:**
1. Add state to `auth_state.dart`
2. Add test case in `auth_state_manager_test.dart`
3. Add routing case in `auth_gate_widget_test.dart`
4. Add flow test in `auth_flows_integration_test.dart`

**For New Transitions:**
1. Add transition logic in `auth_state_manager.dart`
2. Add test in `auth_state_manager_test.dart` under "State Transitions"
3. Add flow test showing the complete journey

**Example: Testing a New State**
```dart
test('new state has correct properties', () {
  expect(AuthState.newState.isActive, isFalse);
  expect(AuthState.newState.isLoading, isFalse);
  expect(AuthState.newState.isBlocking, isTrue);
});

test('new state transitions correctly', () async {
  // Setup
  final authManager = AuthStateManager();
  
  // Trigger transition
  await authManager.triggerNewState();
  
  // Verify
  expect(authManager.state, equals(AuthState.newState));
  
  authManager.dispose();
});
```

---

## Coaching Screens

### Overview

The coaching experience consists of 4 beautiful, swipeable screens designed to create an immersive, transformative journey.

### The 4-Screen Experience

#### Screen 1: Mindset Shift 🌅
- **Random inspirational lake scene background** from `assets/images/backgrounds/`
- Displays the coaching "recommendation" in a beautiful card
- Clean, minimal design with gradient overlay
- Swipe right to continue

**Technical:**
- Random selection from up to 20 images (`lake_1.jpg` - `lake_20.jpg`)
- Graceful fallback to teal gradient if images unavailable
- Responsive design for all screen sizes

#### Screen 2: Deep Dive 🎯
- **Action step content** with full text
- **Native text-to-speech** functionality (iOS AVFoundation, Android TextToSpeech)
- **Floating play button** (bottom-right) persists during scroll
- Orange/red gradient theme
- Swipe left to continue

**Technical:**
- Method channel: `com.annoyed.app/tts`
- Play/stop controls
- Native platform APIs for best quality
- Background color: Orange (#F59E0B) to Red (#EF4444) gradient

#### Screen 3: Annoyance Analysis 📊
- **Beautiful pie chart** showing category breakdown
- Stats cards (total annoyances, last 7 days)
- **Color-coded category legend** with percentages
- **Top 5 triggers** with progress bars
- Purple gradient theme (#667eea to #764ba2)
- Swipe left to continue

**Technical:**
- Uses `fl_chart` package for visualizations
- Real-time data from `AnnoyanceProvider`
- Color scheme matches category colors:
  - Boundaries: Pink (#E91E63)
  - Environment: Blue (#2196F3)
  - Life Systems: Green (#4CAF50)
  - Communication: Orange (#FF9800)
  - Energy: Purple (#9C27B0)

#### Screen 4: Wisdom & CTA ✨
- **Random inspirational lake background**
- **Wisdom quote** — Deep, spiritual, entrepreneurial (10 rotating quotes)
- **Coach profile image**
- **Call-to-action** for "Boxed-in Builders"
- **Calendly integration** for 15-minute 1:1 discovery call
- Targets entrepreneurs trapped by their own systems

**Technical:**
- Opens Calendly in external browser
- 10 carefully crafted wisdom quotes
- Dark overlay for text readability

### Architecture

```
CoachingFlowScreen (PageView container)
  ├─ Screen 1: MindsetShiftScreen
  ├─ Screen 2: DeepDiveScreen  
  ├─ Screen 3: AnnoyanceAnalysisScreen
  └─ Screen 4: WisdomCtaScreen
```

**Files:**
```
lib/screens/
├── coaching_flow_screen.dart          # Container with PageView
└── coaching_screens/
    ├── mindset_shift_screen.dart      # Screen 1
    ├── deep_dive_screen.dart          # Screen 2 (with TTS)
    ├── annoyance_analysis_screen.dart # Screen 3 (with charts)
    └── wisdom_cta_screen.dart         # Screen 4 (with CTA)
```

### Native Text-to-Speech Implementation

#### iOS (AppDelegate.swift)
```swift
import AVFoundation

private let synthesizer = AVSpeechSynthesizer()

// Method channel: "com.annoyed.app/tts"
// Commands: "speak", "stop"
// Rate: 0.5 (natural speaking pace)
```

#### Android (MainActivity.kt)
```kotlin
import android.speech.tts.TextToSpeech

private lateinit var textToSpeech: TextToSpeech

// Method channel: "com.annoyed.app/tts"
// Commands: "speak", "stop"
// Proper lifecycle management
```

### Wisdom Quotes

10 powerful quotes designed to resonate emotionally with entrepreneurs:

1. "The systems you built to free you have become your cage. It's time to remember who you were before the machine."
2. "You created the blueprint. Now the blueprint controls you. Freedom begins when you step outside the architecture."
3. "The entrepreneur's paradox: You built it all to gain time, but now time owns you. Reclaim your sovereignty."
4. "Every system you built was once a solution. Today, they're the problem. Evolution demands letting go."
5. "You are not your business. You are not your systems. You are the space between—the observer, the creator."
6. "The cage you live in is made of your own design. The key has always been in your hand."
7. "Mastery isn't building more. It's knowing when to tear down what no longer serves your highest self."
8. "You automated everything but your soul. Return to what matters."
9. "The patterns that built your empire are now your prison. Break the pattern, free the builder."
10. "True freedom is realizing the systems serve you—not the other way around."

### Setup Instructions

#### 1. Add Lake Scene Images

Place 20 inspirational lake scene images in `assets/images/backgrounds/`:

```bash
assets/images/backgrounds/
  ├── lake_1.jpg
  ├── lake_2.jpg
  ├── lake_3.jpg
  └── ... (up to lake_20.jpg)
```

**Requirements:**
- Format: JPG or JPEG
- Size: Larger than mobile screens (2000x3000+ recommended)
- Aspect Ratio: Portrait or square
- Content: Inspirational lake scenes, peaceful water, nature

#### 2. Update Calendly Link

In `lib/screens/coaching_screens/wisdom_cta_screen.dart`, line 38:

```dart
final uri = Uri.parse('https://calendly.com/YOUR-LINK/15min-discovery');
```

Update with your actual Calendly URL.

#### 3. Verify Coach Image

Ensure your photo exists at:
```
assets/images/coach_craig.jpg
```

### Dependencies

Added to `pubspec.yaml`:

```yaml
dependencies:
  fl_chart: ^1.0.0  # Beautiful charts and visualizations
```

### User Experience Flow

```
1. User taps "Get Coaching" button
   ↓
2. Commitment gate: "Can you commit to 5 minutes?"
   ↓
3. Loading state with rotating messages
   ↓
4. Coaching loads successfully
   ↓
5. CoachingFlowScreen appears with Screen 1 (Mindset Shift)
   ↓
6. User swipes right → Screen 2 (Deep Dive + TTS)
   ↓
7. User taps play button → Text reads aloud
   ↓
8. User swipes left → Screen 3 (Analysis + Charts)
   ↓
9. User swipes left → Screen 4 (Wisdom + CTA)
   ↓
10. User taps "Schedule Call" → Opens Calendly
```

### Visual Design

**Page Indicator:**
- White dots at bottom
- Active page: Elongated pill (32px wide)
- Inactive pages: Small circles (8px)
- Smooth animations

**Close Button:**
- Top-left corner
- White icon on all screens
- Accessible at all times

**Swipe Hints:**
- Visual prompts: "Swipe right to continue"
- Tap-to-advance alternative
- Clear directional cues

### Testing Checklist

- [ ] Test TTS play/stop functionality
- [ ] Swipe through all 4 screens smoothly
- [ ] Verify pie chart displays correctly
- [ ] Check category colors match app theme
- [ ] Verify Calendly opens in external browser
- [ ] Test background image fallback
- [ ] Test on different screen sizes (iPhone SE, Pro Max, iPad)
- [ ] Verify page indicators update correctly
- [ ] Test close button on all screens

### Color Themes

| Screen | Gradient | Purpose |
|--------|----------|---------|
| Mindset Shift | Teal (#0F766E) | Calming, inspirational |
| Deep Dive | Orange-Red (#F59E0B → #EF4444) | Energetic, actionable |
| Analysis | Purple (#667eea → #764ba2) | Analytical, insightful |
| Wisdom | Dark overlay on image | Reflective, profound |

### Integration

The coaching screens integrate seamlessly with the existing coaching system:

- **Entry Point:** `coaching_screen.dart` → `_buildCoachingFlowContent()`
- **Data Source:** Existing coaching generation (Firebase Cloud Function)
- **History:** Still accessible via history button
- **Regeneration:** Still works with refresh button
- **Analytics:** Existing coaching analytics continue to work

### Future Enhancements

Potential improvements:

- Add haptic feedback on swipes
- Animate chart elements on screen entry
- Add share functionality for insights
- Save favorite wisdom quotes
- Progress tracking across coaching sessions
- More visualization types (line charts, trends over time)
- Voice-activated navigation
- Accessibility improvements (VoiceOver support)

---

## Development

### Constants
All magic numbers are now centralized in `lib/utils/constants.dart`:
- Recording durations
- Coaching intervals
- Cost limits
- Animation durations

### State Management
Using Provider for state:
- `AuthStateManager` — Authentication state machine (single source of truth)
- `AnnoyanceProvider` — Annoyances and pattern analysis
- `SuggestionProvider` — Suggestions and feedback
- `PreferencesProvider` — User settings

### Analytics Events
- `install` — First app open
- `annoyance_saved` — Annoyance recorded
- `pattern_shown` — Pattern report displayed
- `coaching_viewed` — Coaching accessed
- `coaching_resonance_hell_yes` / `_meh` — Feedback given

---

## Deployment

### iOS

1. Update version in `pubspec.yaml`
2. Archive in Xcode:
   - Open `ios/Runner.xcworkspace`
   - Product → Archive
3. Submit to App Store Connect

### Android

1. Update version in `pubspec.yaml`
2. Build release bundle:
```bash
flutter build appbundle --release
```
3. Upload to Google Play Console

### Firebase

```bash
# Deploy everything
firebase deploy

# Deploy specific services
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

---

## App Store Submission

### Required Assets

#### App Icon
- **Size**: 1024x1024px (PNG, no transparency)
- **Design**: ⚡️ bolt icon + wave, teal background
- Generate with [appicon.co](https://appicon.co)

#### Screenshots (Minimum 6)
1. **Capture Mode** — "Capture annoyances in seconds"
2. **Auto-categorization** — "Auto-transcribed. Smartly labeled"
3. **Coach Prompt** — "We ask when you're ready"
4. **Suggestion Card** — "One precise behavior, not a lecture"
5. **Profile/Metrics** — "Watch patterns shift"
6. **Settings** — "You control when we nudge"

**Dimensions:**
- iPhone 15 Pro Max: 1290 x 2796px
- Android Phone: 1080 x 1920px minimum

### App Description

**Short (80 chars):**
```
Vent fast. Get your pattern after 3 entries. Then keep upgrading.
```

**Long Description:**
```
Two modes. One mission: upgrade what annoys you.

CAPTURE MODE
Something sets you off? Open Annoyed and tap to record. Your voice note is 
transcribed on-device—audio never leaves your phone—and categorized into one 
of five patterns: Boundaries, Environment, Systems Debt, Communication, or Energy.

No journaling tax. No long forms. Capture takes seconds.

COACH MODE
After every 5 annoyances, get personalized coaching tailored to your patterns.
One concise recommendation that creates an immediate shift or a specific daily 
behavior you can complete in under thirty minutes.

PRIVACY BY DEFAULT
• Audio transcribed on-device only
• Client-side PII redaction
• No audio upload. Ever.
• Delete all data anytime

WHY IT WORKS
• Frictionless capture preserves the truth of the moment
• Coaching deferred until you're ready
• One action only. No overwhelm.
• Pattern feedback reframes growth positively

Start free. Upgrade anytime.

Annoyed → Aligned.
```

### Keywords (iOS, 100 chars)
```
annoyed,frustration,habit,boundaries,focus,calm,journal,vent,self-coaching,patterns
```

### Submission Checklist

**Pre-Submission:**
- [ ] Test on physical devices (iOS + Android)
- [ ] Verify all features work
- [ ] Test paywall flow
- [ ] Test permissions (mic, notifications)
- [ ] Verify analytics

**iOS App Store:**
- [ ] App icon (1024x1024)
- [ ] 6 screenshots
- [ ] Description + keywords
- [ ] Privacy labels
- [ ] TestFlight tested
- [ ] Age rating (4+)
- [ ] Category: Productivity
- [ ] Pricing: Free with IAP

**Google Play:**
- [ ] Feature graphic (1024x500)
- [ ] App icon (512x512)
- [ ] 6 screenshots
- [ ] Data safety form
- [ ] Content rating
- [ ] Category: Productivity

---

## Legal & Compliance

### GDPR Compliance ✅
- **Consent**: Explicit checkbox for Terms acceptance
- **Data Minimization**: Only necessary data collected
- **Right to Access**: Users can view all their data
- **Right to be Forgotten**: Full account deletion (including llm_cost records)
- **Data Portability**: Users can export data
- **Privacy by Design**: Opt-in for marketing

### U.S. Compliance ✅
- **COPPA**: App not for children under 13
- **CCPA**: Users have right to delete data
- **Data Storage**: Firebase (SOC 2, ISO 27001 certified)
- **Password Security**: Bcrypt via Firebase Auth

### Password Requirements
- Minimum 8 characters
- Uppercase + lowercase letters
- At least one number
- At least one special character
- Real-time strength indicator

### Required Documents
- **Terms of Service**: `lib/screens/terms_screen.dart`
- **Privacy Policy**: `lib/screens/privacy_policy_screen.dart`
- **Last Updated**: October 18, 2025

---

## Troubleshooting

### Firebase Issues

**"Firebase not initialized"**
- Ensure `firebase_options.dart` exists
- Check config files in correct locations
- Run `flutterfire configure`

**"Cloud Function not found"**
```bash
firebase functions:list
firebase functions:log
firebase deploy --only functions --force
```

### Speech Recognition

**"Speech recognition not working"**
- iOS: Check `Info.plist` has `NSMicrophoneUsageDescription`
- Android: Check `AndroidManifest.xml` has microphone permission
- Grant permission on device in Settings

### Build Issues

**iOS deployment target error**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner → Build Settings
3. Change "iOS Deployment Target" to `13.0`

**Android Gradle errors**
- Update `android/build.gradle`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

### Cost Monitoring

**Check OpenAI costs**
1. Firebase Console → Firestore → `llm_cost` collection
2. Query for monthly totals
3. Set budget alert in Firebase Console

---

## Success Metrics

Track these key metrics:
1. **Activation**: % users who create 3 entries (see pattern report)
2. **Retention**: D1, D7, D30 retention
3. **Conversion**: % free users who upgrade
4. **Engagement**: Avg annoyances per week
5. **Quality**: HELL YES rate on coaching
6. **LTV**: Avg lifetime value per paying user

---

## Support

- **YouTube**: [Green Pyramid Channel](https://www.youtube.com/@GreenPyramid-mk5xp)
- **Retreats**: [Still Waters Retreats](https://www.stillwatersretreats.com)
- **Green Pyramid App**: 
  - iOS: [App Store](https://apps.apple.com/us/app/green-pyramid-your-best-life/id6450578276)
  - Android: [Google Play](https://play.google.com/store/apps/details?id=com.cglendenning.life_ops&hl=en_US)

---

## License

Proprietary — All rights reserved

---

## Credits

Built with Flutter 💙  
Powered by OpenAI GPT-4o-mini  
Coach Craig's Green Pyramid methodology

---

**Built in 3 days. Ready to ship. 🚀**
