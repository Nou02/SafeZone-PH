# Firebase Setup Guide for SafeZone PH

This guide will walk you through setting up Firebase Cloud Messaging (FCM) for push notifications.

## Prerequisites

- A Google account
- Flutter installed and working
- Android Studio (for Android setup)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or select an existing project
3. Enter project name: **SafeZone PH** (or any name you prefer)
4. Click **Continue**
5. **Disable Google Analytics** (optional, you can enable later if needed)
6. Click **Create project**
7. Wait for project creation to complete, then click **Continue**

## Step 2: Add Android App to Firebase

1. In Firebase Console, click the **Android icon** (or "Add app" → Android)
2. Enter Android package name: `com.safezoneph.safezone_ph`
   - This must match exactly with your `android/app/build.gradle.kts` file
3. Enter App nickname (optional): **SafeZone PH Android**
4. Enter Debug signing certificate SHA-1 (optional, for now you can skip)
5. Click **Register app**

## Step 3: Download google-services.json

1. After registering, Firebase will show a **"Download google-services.json"** button
2. Click to download the file
3. **IMPORTANT**: Place this file in: `android/app/google-services.json`
   - The file should be at: `android/app/google-services.json` (not in a subfolder)

## Step 4: Configure Android Build Files

### 4.1 Update settings.gradle.kts

Open `android/settings.gradle.kts` and add Google Services plugin to the plugins block:

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Add this line:
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

### 4.2 Update App-Level build.gradle.kts

Open `android/app/build.gradle.kts` and add the Google Services plugin:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Add this line:
    id("com.google.gms.google-services")
}
```

## Step 5: Install FlutterFire CLI

The FlutterFire CLI will automatically generate the `firebase_options.dart` file:

```bash
dart pub global activate flutterfire_cli
```

**Note**: Make sure `dart` is in your PATH. If you get an error, you may need to add Flutter's bin directory to your PATH.

## Step 6: Configure FlutterFire

1. Make sure you're logged into Firebase:
   ```bash
   firebase login
   ```
   (If you don't have Firebase CLI, you can skip this and use the web interface)

2. Run FlutterFire configuration:
   ```bash
   flutterfire configure
   ```

3. The CLI will:
   - Ask you to select your Firebase project
   - Ask which platforms to configure (select Android, and iOS if needed)
   - Automatically generate `lib/firebase_options.dart`

4. If the CLI asks for your Firebase project, select the one you created in Step 1

## Step 7: Update main.dart to Use firebase_options

After `flutterfire configure` creates `lib/firebase_options.dart`, update `lib/main.dart`:

```dart
import 'firebase_options.dart';  // Add this import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with the generated options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  
  // ... rest of your code
}
```

## Step 8: Test the Setup

1. Run the app:
   ```bash
   flutter run
   ```

2. Check the console logs - you should see:
   - "Firebase initialized successfully"
   - No Firebase-related errors

3. If you see errors, check:
   - `google-services.json` is in `android/app/` directory
   - `firebase_options.dart` exists in `lib/` directory
   - Build files are updated correctly

## Step 9: Get FCM Server Key (for Supabase Edge Function)

For push notifications to work, you'll also need the FCM Server Key:

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Click on **Cloud Messaging** tab
3. Under **Cloud Messaging API (Legacy)**, you'll see **Server key**
4. Copy this key - you'll need it for the Supabase Edge Function (see `NOTIFICATION_SETUP.md`)

## Troubleshooting

### Error: "google-services.json not found"
- Make sure the file is at `android/app/google-services.json` (not in a subfolder)
- Check the file name is exactly `google-services.json` (case-sensitive)

### Error: "DefaultFirebaseOptions not found"
- Run `flutterfire configure` again
- Make sure `lib/firebase_options.dart` exists
- Check that you imported it: `import 'firebase_options.dart';`

### Error: "Plugin with id 'com.google.gms.google-services' not found"
- Make sure you added the classpath in `android/build.gradle.kts`
- Make sure you added the plugin in `android/app/build.gradle.kts`
- Run `flutter clean` and try again

### App still crashes
- Make sure you're using the updated `main.dart` that handles Firebase errors gracefully
- Check that `google-services.json` has the correct package name
- Try `flutter clean` and rebuild

## Next Steps

After Firebase is set up:
1. Run the database setup: `setup_notifications.sql` in Supabase
2. Deploy the Supabase Edge Function (see `NOTIFICATION_SETUP.md`)
3. Test notifications by creating a report

## Quick Checklist

- [ ] Firebase project created
- [ ] Android app added to Firebase
- [ ] `google-services.json` downloaded and placed in `android/app/`
- [ ] `android/build.gradle.kts` updated with Google Services classpath
- [ ] `android/app/build.gradle.kts` updated with Google Services plugin
- [ ] FlutterFire CLI installed (`dart pub global activate flutterfire_cli`)
- [ ] `flutterfire configure` run successfully
- [ ] `lib/firebase_options.dart` exists
- [ ] `main.dart` updated to use `DefaultFirebaseOptions`
- [ ] App runs without Firebase errors
- [ ] FCM Server Key copied for Edge Function

Once all items are checked, your Firebase setup is complete! 🎉

