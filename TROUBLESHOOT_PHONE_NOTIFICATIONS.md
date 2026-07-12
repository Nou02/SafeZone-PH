# Troubleshooting: Notifications Work on Emulator But Not Real Phone

If notifications work on the Android Studio emulator but not on your real phone, follow these steps:

## Step 1: Verify Your Phone is Logged In

1. **Open the app on your real phone**
2. **Make sure you're logged in** with the same account that's on the emulator
3. **Check that you have a barangay selected:**
   - Go to Profile → Settings
   - Make sure a barangay is selected
   - This is required for the device token to be saved

## Step 2: Check Device Token is Saved

The app saves your device token when you log in. To verify:

1. **Check the app logs on your phone:**
   - Connect your phone via USB
   - Run: `adb logcat | grep "FCM Token"`
   - You should see: `FCM Token: [your-token-here]`
   - You should also see: `Device token saved to database`

2. **Or check in Supabase:**
   - Go to Supabase Dashboard → Table Editor
   - Open the `user_devices` table
   - Check if there's a row with your phone's token
   - Make sure the `barangay_id` matches the one you're testing with

## Step 3: Verify Same Barangay

Both devices (emulator and phone) must be in the **same barangay** to receive notifications:

1. **Check emulator's barangay:**
   - On emulator: Profile → Settings → Check which barangay is selected
   - Note the barangay name/ID

2. **Check phone's barangay:**
   - On phone: Profile → Settings → Make sure the SAME barangay is selected
   - If different, update it to match

3. **Verify in database:**
   - Both devices should have the same `barangay_id` in the `user_devices` table

## Step 4: Check Notification Permissions

1. **On your phone:**
   - Go to Settings → Apps → SafeZone PH → Notifications
   - Make sure notifications are **enabled**
   - Make sure all notification categories are enabled

2. **In the app:**
   - When you first open the app, it should ask for notification permission
   - Make sure you clicked "Allow"

## Step 5: Force Token Refresh

Sometimes the token needs to be refreshed. Try this:

1. **Log out and log back in on your phone:**
   - This will trigger the token to be saved again
   - Check logs to confirm: `Device token saved to database`

2. **Or restart the app:**
   - Close the app completely
   - Reopen it
   - The token should be refreshed automatically

## Step 6: Check Database Directly

Run this SQL query in Supabase SQL Editor to see all device tokens:

```sql
SELECT 
  ud.user_id,
  ud.device_token,
  ud.barangay_id,
  ud.updated_at,
  u.email
FROM user_devices ud
LEFT JOIN auth.users u ON u.id = ud.user_id
ORDER BY ud.updated_at DESC;
```

**What to check:**
- Is your phone's token in the list?
- Does it have the correct `barangay_id`?
- Is the `updated_at` recent?

## Step 7: Test with Same Account

Make sure both devices are using the **same user account**:

1. **Check user ID:**
   - Both devices should have the same `user_id` in the `user_devices` table
   - If different, log in with the same account on both

2. **Check barangay:**
   - Both must have the same `barangay_id`

## Step 8: Check Edge Function Logs

When you create a report, check the Edge Function logs:

1. Go to Supabase Dashboard → Edge Functions → `notify-barangay-users` → Logs
2. Look for: `Sending notifications to X devices for barangay [id]`
3. Check if your phone's token is in the list of tokens being sent to

## Step 9: Verify FCM Token is Valid

1. **Get your phone's FCM token:**
   - Check the app logs: `adb logcat | grep "FCM Token"`
   - Or add a debug button to show the token (temporarily)

2. **Test directly with Firebase Console:**
   - Go to Firebase Console → Cloud Messaging
   - Click "Send test message"
   - Enter your phone's FCM token
   - Send a test notification
   - If this works, the token is valid and the issue is elsewhere

## Common Issues

### Issue 1: Token Not Saved
**Symptom:** No token in `user_devices` table for your phone

**Solution:**
- Make sure you're logged in on the phone
- Make sure you have a barangay selected in Profile → Settings
- Check app logs for errors: `Error saving device token`

### Issue 2: Different Barangay
**Symptom:** Tokens exist but different `barangay_id`

**Solution:**
- Update Profile → Settings on your phone to match the emulator's barangay
- Log out and log back in to refresh the token

### Issue 3: Token Not Refreshed
**Symptom:** Old token in database

**Solution:**
- Log out and log back in
- Or restart the app completely

### Issue 4: Notifications Disabled
**Symptom:** Token exists but no notifications received

**Solution:**
- Check phone Settings → Apps → SafeZone PH → Notifications
- Make sure all notification types are enabled

## Quick Test

1. **On emulator:** Create a report
2. **Check Edge Function logs:** Should show "Sending notifications to X devices"
3. **Check phone:** Should receive notification within a few seconds

If the Edge Function shows it's sending to multiple devices but your phone doesn't receive it, the issue is likely:
- Notification permissions on phone
- Phone's FCM token is invalid/expired
- Phone is in a different barangay

## Still Not Working?

1. **Check both devices have the same:**
   - User account (same email)
   - Barangay ID
   - Recent token save (check `updated_at`)

2. **Verify in database:**
   ```sql
   -- Check tokens for your barangay
   SELECT * FROM user_devices 
   WHERE barangay_id = 'your-barangay-id-here';
   ```

3. **Test FCM token directly:**
   - Use Firebase Console to send a test message to your phone's token
   - If this fails, the token might be invalid



