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
- [Troubleshooting](#troubleshooting)

---

## Features

### Capture Mode
- **Tap-to-record** voice capture (30s, on-device transcription)
- **Auto-categorization** into 5 patterns: Boundaries, Environment, Systems Debt, Communication, Energy
- **PII redaction** before any network call
- **Text fallback** if mic is unavailable

### Coach Mode
- **Personalized coaching** based on your patterns (every 5 annoyances)
- **Coaching history** — all past coaching sessions saved permanently
- **Quick feedback** (HELL YES / Meh) trains future suggestions
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
├── models/              # Data models (Annoyance, Suggestion, UserPreferences)
├── providers/           # State management (Provider)
├── screens/             # UI screens (17 screens)
├── services/            # Business logic (Firebase, Speech, Analytics, Paywall)
├── utils/              # Utilities (Colors, Constants, Validators)
├── widgets/             # Reusable UI components
└── main.dart            # App entry point

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

## Authentication Flow

### Phase 1: Anonymous Start (0-4 annoyances)
1. First launch → Onboarding → Automatic anonymous sign-in
2. User records 1-4 annoyances freely
3. Full access to all features

### Phase 2: Auth Gate (5th annoyance)
1. After recording 5th annoyance, show sign-up prompt
2. Benefits:
   - ✅ Keep all recorded annoyances
   - ✅ AI-powered coaching insights
   - ✅ Sync across devices
   - ✅ Exclusive deals from Coach Craig

### Phase 3: Account Linking
1. User enters email + password
2. Firebase links anonymous account to email/password
3. **All data preserved** (same uid, no migration needed)

**Key Implementation:**
```dart
// Anonymous sign-in
await FirebaseAuth.instance.signInAnonymously();
// uid: "abc123xyz"

// Link to email/password
final credential = EmailAuthProvider.credential(email, password);
await user.linkWithCredential(credential);
// uid: STILL "abc123xyz" (permanent!)
```

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

## Development

### Constants
All magic numbers are now centralized in `lib/utils/constants.dart`:
- Recording durations
- Coaching intervals
- Cost limits
- Animation durations

### State Management
Using Provider for state:
- `AuthProvider` — Authentication state
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
