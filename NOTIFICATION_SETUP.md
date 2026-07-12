# Push Notifications Setup Guide

This guide will help you set up push notifications for SafeZone PH so users receive notifications when reports are submitted in their barangay.

## Overview

The notification system works as follows:
1. Users register their device tokens when they log in
2. When a report is created, the app calls a Supabase Edge Function
3. The Edge Function sends FCM notifications to all users in the same barangay

## Step 1: Set Up Firebase Cloud Messaging (FCM)

### 1.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Follow the setup wizard

### 1.2 Add Android App to Firebase

1. In Firebase Console, click "Add app" → Android
2. Enter package name: `com.safezoneph.safezone_ph`
3. Download `google-services.json`
4. Place it in `android/app/` directory

### 1.3 Add iOS App to Firebase (if needed)

1. In Firebase Console, click "Add app" → iOS
2. Enter bundle ID: `com.safezoneph.safezonePh` (check your iOS project)
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/` directory

### 1.4 Configure Firebase in Flutter

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Configure Firebase:
   ```bash
   flutterfire configure
   ```
   This will create `lib/firebase_options.dart` automatically.

3. Update `lib/main.dart` to use the generated options:
   ```dart
   import 'firebase_options.dart';
   
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

### 1.5 Update Android Build Files

1. Update `android/build.gradle.kts` (project level):
   ```kotlin
   buildscript {
       dependencies {
           classpath("com.google.gms:google-services:4.4.0")
       }
   }
   ```

2. Update `android/app/build.gradle.kts`:
   ```kotlin
   plugins {
       // ... existing plugins
       id("com.google.gms.google-services")
   }
   ```

## Step 2: Set Up Supabase Database

Run the SQL script to create the necessary tables:

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Run the contents of `setup_notifications.sql`

This creates:
- `user_devices` table to store device tokens
- RLS policies for security
- Helper function to get device tokens by barangay

## Step 3: Create Supabase Edge Function

The Edge Function will handle sending FCM notifications server-side.

### 3.1 Install Supabase CLI

```bash
npm install -g supabase
```

### 3.2 Create Edge Function

```bash
supabase functions new notify-barangay-users
```

### 3.3 Implement the Function

Create `supabase/functions/notify-barangay-users/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as jwt from "https://deno.land/x/djwt@v2.8/mod.ts"

const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY') || ''

serve(async (req) => {
  try {
    const { barangay_id, report_type, report_id, description } = await req.json()

    // Get Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get all device tokens for this barangay
    const { data: tokens, error } = await supabase.rpc(
      'get_barangay_device_tokens',
      { p_barangay_id: barangay_id }
    )

    if (error) throw error
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No devices found' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Prepare notification message
    const title = `New ${report_type} Report`
    const body = description || `A new ${report_type.toLowerCase()} report has been submitted in your barangay`

    // Send notifications to all devices
    const fcmPromises = tokens.map((token: { device_token: string }) => {
      return fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${FCM_SERVER_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: token.device_token,
          notification: {
            title: title,
            body: body,
            sound: 'default',
          },
          data: {
            report_id: report_id,
            report_type: report_type,
            barangay_id: barangay_id,
          },
        }),
      })
    })

    await Promise.all(fcmPromises)

    return new Response(
      JSON.stringify({ 
        message: `Notifications sent to ${tokens.length} devices`,
        success: true 
      }),
      {
        headers: { 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})
```

### 3.4 Deploy Edge Function

1. Get your FCM Server Key:
   - Go to Firebase Console → Project Settings → Cloud Messaging
   - Copy the "Server key"

2. Set environment variable:
   ```bash
   supabase secrets set FCM_SERVER_KEY=your_server_key_here
   ```

3. Deploy the function:
   ```bash
   supabase functions deploy notify-barangay-users
   ```

## Step 4: Test Notifications

1. Build and run the app on a device
2. Log in with a user account
3. Create a test report
4. Check if other users in the same barangay receive notifications

## Troubleshooting

### Notifications not working?

1. **Check Firebase setup:**
   - Verify `google-services.json` is in `android/app/`
   - Check that Firebase is initialized in `main.dart`
   - Ensure FCM token is being generated (check logs)

2. **Check Supabase:**
   - Verify `user_devices` table exists
   - Check that device tokens are being saved (query the table)
   - Ensure Edge Function is deployed and has FCM_SERVER_KEY set

3. **Check permissions:**
   - Android: Ensure notification permission is granted
   - iOS: Ensure notification permission is granted

4. **Check logs:**
   - Flutter: `flutter run` and check console
   - Supabase: Check Edge Function logs in dashboard

## Security Notes

- FCM Server Key should be kept secret (use Supabase secrets)
- Device tokens are stored securely with RLS policies
- Only users can manage their own device tokens
- Edge Function uses service role key (server-side only)

## Next Steps

- Add notification channels for different report types
- Implement notification preferences (opt-in/opt-out)
- Add notification history/logs
- Support for notification actions (e.g., "View Report")






