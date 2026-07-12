# Fix: Real Phone Token Not Being Saved

If your real phone's device token is not appearing in the `user_devices` table, follow these steps:

## Quick Fix Steps

### Step 1: Check if User Has Barangay Selected

**The device token is ONLY saved if the user has a barangay selected in their profile.**

1. **On your real phone:**
   - Open the app
   - Go to Profile (top right icon)
   - Tap "Settings"
   - Check if a barangay is selected in the dropdown
   - If not, select one and tap "Save changes"

2. **After saving:**
   - The app will automatically re-initialize notifications
   - Check the app logs for: `✅ Device token saved to database successfully`

### Step 2: Check App Logs

Connect your phone via USB and check the logs:

```bash
adb logcat | grep -E "FCM Token|Device token|barangay_id"
```

**What to look for:**
- `FCM Token: [token]` - Token was generated
- `💾 Saving device token...` - Attempting to save
- `✅ Device token saved to database successfully` - Success!
- `⚠️ User has no barangay_id, skipping token save` - **This is the problem!**

### Step 3: Verify in Database

1. Go to Supabase Dashboard → Table Editor → `user_devices`
2. Check if there's a row with your phone's token
3. Verify:
   - `user_id` matches your account
   - `barangay_id` matches the barangay you selected
   - `updated_at` is recent

### Step 4: Manual Token Refresh

If the token still isn't saved:

1. **On your real phone:**
   - Go to Profile → Settings
   - Make sure a barangay is selected
   - Tap "Save changes" (even if nothing changed)
   - This will trigger notification re-initialization

2. **Or log out and log back in:**
   - This will also trigger token save

## Common Issues

### Issue 1: No Barangay Selected
**Symptom:** Logs show `⚠️ User has no barangay_id, skipping token save`

**Solution:**
- Go to Profile → Settings
- Select a barangay
- Save changes
- Token should be saved automatically

### Issue 2: Different User Accounts
**Symptom:** Only one device in table, but you have two phones

**Check:**
- Are both phones logged in with the same account?
- Or are they using different accounts?
- Each account needs its own device token entry

### Issue 3: Notification Permission Denied
**Symptom:** No FCM token generated

**Solution:**
- Go to phone Settings → Apps → SafeZone PH → Notifications
- Make sure notifications are enabled
- Restart the app

### Issue 4: Firebase Not Initialized
**Symptom:** Logs show `Firebase initialization error`

**Solution:**
- Check that `google-services.json` is in `android/app/`
- Verify Firebase is properly configured
- See `FIREBASE_SETUP.md` for setup instructions

## Verify Both Devices Are Set Up

Run this SQL query in Supabase to see all device tokens:

```sql
SELECT 
  ud.id,
  ud.user_id,
  LEFT(ud.device_token, 30) as token_preview,
  ud.barangay_id,
  ud.updated_at,
  u.email
FROM user_devices ud
LEFT JOIN auth.users u ON u.id = ud.user_id
ORDER BY ud.updated_at DESC;
```

**Expected result:**
- Two rows (one for emulator, one for real phone)
- Both have the same `barangay_id` (if same barangay)
- Both have recent `updated_at` timestamps

## Quick Test

1. **On real phone:** Profile → Settings → Select barangay → Save
2. **Check logs:** Should see `✅ Device token saved to database`
3. **Check database:** Should see new/updated row in `user_devices`
4. **Test notification:** Create a report from emulator
5. **Real phone should receive notification**

## Still Not Working?

1. **Check both accounts have barangay:**
   - Emulator account: Profile → Settings → Check barangay
   - Real phone account: Profile → Settings → Check barangay
   - Both must have the SAME barangay selected

2. **Check logs on real phone:**
   ```bash
   adb logcat | grep -i "notification\|token\|barangay"
   ```

3. **Try manual refresh:**
   - Log out on real phone
   - Log back in
   - Check if token appears in database

4. **Verify Firebase setup:**
   - Make sure `google-services.json` is correct
   - Check Firebase Console for your app



