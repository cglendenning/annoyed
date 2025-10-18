# Quick Start Guide

Get Annoyed running in 5 minutes!

## 1. Install Dependencies

```bash
cd /Users/craig/development/annoyed
flutter pub get
cd functions && npm install && cd ..
```

## 2. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project: "annoyed"
3. Add iOS app: bundle ID `com.cglendenning.annoyed`
4. Add Android app: package `com.cglendenning.annoyed`
5. Download config files:
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`
   - Android: `google-services.json` → `android/app/`

## 3. Enable Firebase Services

### Authentication
- Enable Anonymous sign-in

### Firestore
- Create database (production mode)
- Copy rules from `FIREBASE_SETUP.md`

### Cloud Functions
```bash
cd functions
firebase login
firebase use --add  # Select your annoyed project
firebase functions:config:set openai.key="YOUR_OPENAI_KEY_FROM_life_ops"
firebase deploy --only functions
```

## 4. Generate Firebase Config

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=annoyed
```

This creates `lib/firebase_options.dart` automatically.

## 5. Update Secrets

Your `lib/secrets.dart` already has the OpenAI and RevenueCat keys from life_ops.

Just update the Firebase placeholders with values from Firebase Console → Project Settings:

```dart
const String firebaseWebApiKey = 'AIzaSy...';  // Web API key
const String firebaseWebAppId = '1:123...';    // Web App ID
// etc.
```

## 6. Run the App

```bash
flutter run
```

## Troubleshooting

### "Firebase not initialized"
- Make sure `firebase_options.dart` exists
- Check `GoogleService-Info.plist` and `google-services.json` are in correct locations

### "Cloud Function not found"
- Verify functions deployed: `firebase functions:list`
- Check logs: `firebase functions:log`
- Redeploy: `firebase deploy --only functions --force`

### "Speech recognition not working"
- Grant microphone permission on device
- iOS: Check Info.plist has `NSMicrophoneUsageDescription`
- Android: Check AndroidManifest.xml has microphone permission

### "RevenueCat configuration error"
- The keys are already set from life_ops
- For new offerings, log into [RevenueCat Dashboard](https://app.revenuecat.com/)
- Create products: "pro_monthly" and "pro_annual"
- Link to App Store Connect / Google Play Console

## What You Have

✅ **Day 1 — Capture Loop**
- Home screen with hold-to-record
- On-device transcription + redaction
- Firestore saves + Cloud Function classify
- History list + Entry Detail screens

✅ **Day 2 — Coach & Profile**
- Settings with Preferred Hours
- Profile with metrics
- First Pattern Report after 3 entries
- Coach prompt + Suggestion card UI
- Cloud Function for suggestion generation

✅ **Day 3 — Monetize & Ship**
- RevenueCat paywall before 3rd suggestion
- Privacy settings + Delete all data
- Firebase setup docs
- Store assets guide
- README with full docs

## Next Steps

1. **Test the full flow:**
   - Create 3 annoyances
   - See pattern report
   - Trigger coach prompt (or build a debug button)
   - Accept suggestion → verify paywall on 3rd

2. **Set up push notifications:**
   - iOS: Upload APNs certificate to Firebase
   - Test FCM from Firebase Console

3. **Create app icon:**
   - Use design from `STORE_ASSETS.md`
   - Generate with [appicon.co](https://appicon.co)

4. **Take screenshots:**
   - Use staging data (realistic examples)
   - Follow layout in `STORE_ASSETS.md`

5. **Submit to stores:**
   - Complete checklists in `STORE_ASSETS.md`

## Resources

- Full setup: `FIREBASE_SETUP.md`
- Complete docs: `README.md`
- Store submission: `STORE_ASSETS.md`

---

**You're ready to ship!** 🚀







