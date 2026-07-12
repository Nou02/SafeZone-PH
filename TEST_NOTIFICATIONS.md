# Testing Push Notifications with One Phone

Since you only have one phone, here are several ways to test push notifications:

## Method 1: Send Test Notification from Firebase Console (Easiest)

This is the quickest way to test if notifications are working.

### Steps:

1. **Get your device's FCM token:**
   - Run the app on your phone
   - Check the console/logs for the FCM token (it should print when the app starts)
   - Or add a temporary button in the app to display the token

2. **Send test notification from Firebase Console:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project: **SafeZone PH**
   - Go to **Cloud Messaging** (in the left sidebar)
   - Click **"Send your first message"** or **"New notification"**
   - Enter:
     - **Notification title**: "Test Notification"
     - **Notification text**: "This is a test from Firebase Console"
   - Click **Next**
   - Under **Target**, select **"Single device"**
   - Paste your FCM token
   - Click **Test** or **Review** then **Publish**

3. **Check your phone:**
   - You should receive the notification immediately
   - If the app is in foreground, you'll see a local notification
   - If the app is in background, you'll see a system notification

## Method 2: Use In-App Test Features (Easiest - Already Added!)

I've added test features directly in the Profile screen.

### Steps:

1. **Open the app and go to Profile:**
   - Tap the profile icon in the top right
   - Scroll down to "Notification Testing" section

2. **Test Notification:**
   - Tap "Test Notification"
   - You should immediately see a notification appear
   - This tests if the local notification system is working

3. **Get Your FCM Token:**
   - Tap "Show FCM Token"
   - Copy the token that appears
   - Use this token in Firebase Console (Method 1) to send test notifications

4. **Test Full Flow:**
   - Use the token with Firebase Console to test push notifications
   - Or use it with the Supabase Edge Function once it's set up

## Method 3: Use Firebase Cloud Messaging API (Advanced)

Use a tool like Postman or curl to send notifications directly.

### Steps:

1. **Get your FCM Server Key:**
   - Firebase Console → Project Settings → Cloud Messaging
   - Copy the **Server key**

2. **Get your device token:**
   - From the app logs or Firebase Console

3. **Send notification using curl:**
   ```bash
   curl -X POST https://fcm.googleapis.com/fcm/send \
     -H "Authorization: key=YOUR_SERVER_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "to": "YOUR_DEVICE_TOKEN",
       "notification": {
         "title": "Test Notification",
         "body": "Testing from command line"
       }
     }'
   ```

## Method 4: Test with Report Creation (Full Flow)

If you have the Supabase Edge Function set up, create a test report.

### Steps:

1. **Create a test user account in a test barangay**
2. **Log in with that account on your phone**
3. **Create a report**
4. **The Edge Function should send a notification to all users in that barangay**
5. **Since you're the only user, you'll receive the notification**

## Method 5: Use Android Emulator (If Available)

If you have Android Studio installed:

1. **Create an Android emulator**
2. **Run the app on both your phone and emulator**
3. **Create a report from one device**
4. **Check if the other device receives the notification**

## Quick Test: Add Token Display Button

Let me create a simple way to get your token and test notifications directly from the app.

