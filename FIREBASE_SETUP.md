# Firebase Setup Guide for Annoyed

This guide will walk you through setting up Firebase for the Annoyed app.

## Prerequisites

- Google account
- Flutter SDK installed
- Firebase CLI installed (`npm install -g firebase-tools`)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `annoyed` (or your preferred name)
4. Disable Google Analytics (optional for MVP)
5. Click "Create project"

## Step 2: Register Your Apps

### iOS App

1. In Firebase Console, click the iOS icon
2. Enter iOS bundle ID: `com.cglendenning.annoyed`
3. Download `GoogleService-Info.plist`
4. Add it to `ios/Runner/` directory in Xcode
5. Follow the setup instructions in Firebase Console

### Android App

1. In Firebase Console, click the Android icon
2. Enter Android package name: `com.cglendenning.annoyed`
3. Download `google-services.json`
4. Place it in `android/app/` directory
5. Follow the setup instructions in Firebase Console

## Step 3: Enable Firebase Services

### Authentication

1. In Firebase Console → Authentication → Sign-in method
2. Enable "Anonymous" sign-in
3. (Optional) Enable Email/Password, Google, Apple for later

### Firestore Database

1. In Firebase Console → Firestore Database
2. Click "Create database"
3. Choose "Start in production mode" (we'll set up rules next)
4. Select your region (closest to your users)
5. Click "Enable"

### Firestore Security Rules

Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /annoyances/{annoyanceId} {
      allow read, write: if request.auth != null && 
                           request.auth.uid == resource.data.uid;
      allow create: if request.auth != null && 
                      request.auth.uid == request.resource.data.uid;
    }
    
    match /suggestions/{suggestionId} {
      allow read, write: if request.auth != null && 
                           request.auth.uid == resource.data.uid;
      allow create: if request.auth != null && 
                      request.auth.uid == request.resource.data.uid;
    }
    
    match /events/{eventId} {
      allow create: if request.auth != null && 
                      request.auth.uid == request.resource.data.uid;
    }
    
    match /llm_cost/{costId} {
      allow create: if request.auth != null;
    }
  }
}
```

### Cloud Functions

1. In Firebase Console → Functions
2. Click "Get started"
3. From your terminal:

```bash
cd functions
npm install
firebase login
firebase use --add  # Select your project
```

4. Set the OpenAI API key:

```bash
firebase functions:config:set openai.key="YOUR_OPENAI_API_KEY_HERE"
```

5. Deploy functions:

```bash
firebase deploy --only functions
```

### Cloud Messaging (Push Notifications)

1. In Firebase Console → Cloud Messaging
2. iOS: Upload your APNs authentication key
   - Get from Apple Developer Portal → Certificates, Identifiers & Profiles → Keys
   - Create a new key with APNs enabled
   - Download and upload to Firebase
3. Android: FCM is automatically configured

## Step 4: Generate Flutter Firebase Config

1. Install FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

2. Generate Firebase options:

```bash
flutterfire configure
```

This will create `lib/firebase_options.dart` automatically.

## Step 5: Update Secrets File

Update `lib/secrets.dart` with your Firebase config values:

```dart
// Get these from Firebase Console → Project Settings → General

const String firebaseWebApiKey = 'YOUR_WEB_API_KEY';
const String firebaseWebAppId = 'YOUR_WEB_APP_ID';
// ... etc
```

## Step 6: Test Your Setup

1. Run the app:

```bash
flutter run
```

2. Sign in (anonymous auth should work automatically)
3. Create a test annoyance entry
4. Check Firestore Console to see if data was saved
5. Check Functions logs to see if classification worked

## Troubleshooting

### Android Build Issues

If you see Gradle errors, update `android/build.gradle`:

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

And in `android/app/build.gradle`, ensure:

```gradle
apply plugin: 'com.google.gms.google-services'
```

### iOS Build Issues

1. Open `ios/Runner.xcworkspace` in Xcode
2. Ensure `GoogleService-Info.plist` is in the Runner target
3. Clean build folder (Product → Clean Build Folder)
4. Try again

### Functions Not Working

1. Check Firebase Console → Functions → Logs
2. Verify OpenAI API key is set:

```bash
firebase functions:config:get
```

3. Redeploy functions:

```bash
firebase deploy --only functions --force
```

## Cost Monitoring

- Check Firestore usage: Firebase Console → Firestore → Usage
- Check Functions usage: Firebase Console → Functions → Usage
- Check LLM costs: Query the `llm_cost` collection in Firestore

## Next Steps

- Set up Firebase App Check for security
- Configure Crashlytics for error reporting
- Set up Cloud Scheduler for daily coach reminders
- Add Firestore indexes as needed







