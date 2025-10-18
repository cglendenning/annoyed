# Annoyed — Personal Friction Coach

**Annoyed → Aligned.**

A focused personal coach that meets you in two moments of your day: when something irritates you (Capture Mode) and when you're ready for a suggestion (Coach Mode).

## Features

### Capture Mode
- **Hold-to-record** voice capture (30s, on-device transcription)
- **Auto-categorization** into 5 patterns: Boundaries, Environment, Systems Debt, Communication, Energy
- **PII redaction** before any network call
- **Text fallback** if mic is unavailable

### Coach Mode
- **Daily suggestions** at random times within your preferred hours
- **Personalized coaching** based on your patterns
- **Quick feedback** (HELL YES / Meh) trains future suggestions
- **One action only** — no overwhelm

### Privacy First
- Audio **never leaves your phone** (on-device transcription only)
- Client-side PII redaction
- User-controlled data deletion

## Tech Stack

- **Frontend:** Flutter (iOS + Android)
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, FCM)
- **AI:** OpenAI GPT-4o-mini for classification and suggestion generation
- **Payments:** RevenueCat for cross-platform subscriptions
- **Speech:** Platform native speech recognition (iOS Speech Framework, Android SpeechRecognizer)

## Getting Started

### Prerequisites

- Flutter SDK (3.x)
- Firebase account
- OpenAI API key
- RevenueCat account
- Xcode (for iOS)
- Android Studio (for Android)

### Installation

1. **Clone the repository**

```bash
git clone <repo-url>
cd annoyed
```

2. **Install dependencies**

```bash
flutter pub get
cd functions && npm install && cd ..
```

3. **Set up secrets**

Create `lib/secrets.dart` (use `.env.example` as reference):

```dart
const String openAIApiKey = 'your-openai-key';
const String revenuecatAndroidKey = 'your-revenuecat-android-key';
const String revenuecatIOSKey = 'your-revenuecat-ios-key';
// Add Firebase configs...
```

4. **Set up Firebase**

Follow the complete guide in [FIREBASE_SETUP.md](./FIREBASE_SETUP.md)

5. **Run the app**

```bash
flutter run
```

## Project Structure

```
lib/
├── models/           # Data models (Annoyance, Suggestion, UserPreferences)
├── providers/        # State management (Provider)
├── screens/          # UI screens
├── services/         # Business logic (Firebase, Speech, Analytics)
├── widgets/          # Reusable UI components
├── main.dart         # App entry point
└── secrets.dart      # API keys (gitignored)

functions/
├── index.js          # Cloud Functions (classify, suggest, schedule)
└── package.json      # Node dependencies
```

## Firebase Cloud Functions

### `classifyAnnoyance`
- Input: `{ text: string }`
- Output: `{ category, trigger, safe }`
- Uses GPT-4o-mini to categorize and extract trigger

### `generateSuggestion`
- Input: `{ uid, category, trigger }`
- Output: `{ type, text, days }`
- Uses recent context to generate personalized suggestion

### `scheduleDailyCoach`
- Runs nightly at 2 AM
- Sets random coach check-in time for each user within their preferred hours

## Monetization

- **Free:** First Pattern Report + 2 daily suggestions
- **Pro ($24.99/yr or $3.99/mo):**
  - 90-second recordings
  - Deeper insights
  - Custom preferred hours
  - Higher suggestion frequency
  - Priority support

## Development Roadmap

### Day 1 ✅
- [x] Capture Mode UI with hold-to-record
- [x] On-device transcription + PII redaction
- [x] Firestore writes + classify Cloud Function
- [x] History and Entry Detail screens

### Day 2 ✅
- [x] Settings with Preferred Hours
- [x] Profile with metrics
- [x] First Pattern Report after 3 entries
- [x] Suggestion generation and UI

### Day 3 ⏳
- [x] RevenueCat paywall before 3rd suggestion
- [x] Privacy settings + Delete all data
- [ ] Push notification setup (FCM)
- [ ] App icon and splash screen
- [ ] Store screenshots and copy

### Post-MVP
- [ ] Cloud Scheduler for automated coach notifications
- [ ] Weekly insights email
- [ ] Category drift visualization
- [ ] Export data feature
- [ ] Web dashboard

## Testing

### Manual Test Flow

1. **Onboarding**
   - Complete welcome flow
   - Grant mic permission
   - Set preferred hours

2. **Capture Mode**
   - Hold to record an annoyance
   - Verify categorization
   - Check Firestore for saved entry

3. **Pattern Report**
   - Create 3 entries
   - Verify pattern report appears

4. **Coach Mode**
   - Trigger coach prompt (via debug button or notification)
   - Accept suggestion
   - Verify paywall after 2nd suggestion
   - Test HELL YES / Meh feedback
   - Mark as "Did it"

5. **Profile**
   - Check metrics update
   - Verify category distribution

6. **Settings**
   - Edit preferred hours
   - Delete all data
   - Verify data removed from Firestore

## Deployment

### iOS

1. Update version in `pubspec.yaml`
2. Update build number
3. Archive in Xcode
4. Submit to App Store Connect

### Android

1. Update version in `pubspec.yaml`
2. Build release APK/AAB:

```bash
flutter build appbundle --release
```

3. Upload to Google Play Console

## Contributing

This is a 3-day MVP build. Contributions welcome post-launch!

## License

Proprietary - All rights reserved

## Support

For questions or issues, contact: [your-email]

---

**Built with Flutter 💙**
