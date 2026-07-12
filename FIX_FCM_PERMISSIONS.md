# Fix FCM Permission Denied Error

You're getting this error because your service account doesn't have permission to send FCM messages:

```
Permission 'cloudmessaging.messages.create' denied
```

## Solution: Grant Permissions to Service Account

### Step 1: Find Your Service Account Email

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **SafeZone PH**
3. Go to **Project Settings** (gear icon) → **Service accounts** tab
4. Look at the service account email (it will be something like `firebase-adminsdk-xxxxx@safezone-ph.iam.gserviceaccount.com`)
5. **Copy this email** - you'll need it in the next step

### Step 2: Grant FCM Permissions in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Make sure you select the correct project: **SafeZone PH** (or `safezone-ph`)
3. Navigate to **IAM & Admin** → **IAM** (in the left sidebar)
4. Click **"Grant Access"** or find your service account in the list
5. If the service account is already listed:
   - Click the **pencil icon** (Edit) next to the service account
   - Click **"Add Another Role"**
   - Search for and select: **"Firebase Cloud Messaging API Admin"** (this is the exact role name)
   - If that doesn't appear, try: **"Firebase Cloud Messaging Admin"** or **"Firebase Admin SDK Administrator Service Agent"**
   - Click **"Save"**
6. If the service account is NOT listed:
   - Click **"Grant Access"**
   - Paste the service account email in the "New principals" field
   - Click **"Select a role"** dropdown
   - Search for and select: **"Firebase Cloud Messaging API Admin"**
   - Click **"Save"**

**Important:** The exact role name is **"Firebase Cloud Messaging API Admin"** - make sure you select this exact role.

### Step 3: Alternative - Enable FCM API

If the role doesn't appear, make sure the FCM API is enabled:

1. In Google Cloud Console, go to **APIs & Services** → **Library**
2. Search for **"Firebase Cloud Messaging API"**
3. Click on it and make sure it's **Enabled**
4. If it's not enabled, click **"Enable"**

### Step 4: Regenerate Service Account Key (IMPORTANT!)

After granting permissions, you may need to regenerate the service account key:

1. Go to Google Cloud Console → **IAM & Admin** → **Service Accounts**
2. Find your service account (the one you just granted permissions to)
3. Click on it to open details
4. Go to the **"Keys"** tab
5. Click **"Add Key"** → **"Create new key"**
6. Select **JSON** format
7. Click **"Create"** - a JSON file will download
8. **Update the secret in Supabase:**
   - Go to Supabase Dashboard → **Edge Functions** → **Secrets**
   - Find `FCM_SERVICE_ACCOUNT`
   - Click to edit it
   - Replace the value with the **entire contents** of the new JSON file
   - Click **"Save"**

### Step 5: Wait and Test

1. Wait **5-10 minutes** for permissions to propagate
2. Test again by creating a report
3. Check the Edge Function logs to see if the error is resolved

## Required Roles

The service account needs one of these roles (in order of preference):
1. **Firebase Cloud Messaging API Admin** (exact name - recommended)
2. **Firebase Cloud Messaging Admin**
3. **Firebase Admin SDK Administrator Service Agent**
4. Or a custom role with permission: `cloudmessaging.messages.create`

**Note:** After granting the role, you may need to regenerate the service account key for the changes to take effect.

## Verify Permissions

To check if permissions are set correctly:

1. Go to Google Cloud Console → **IAM & Admin** → **IAM**
2. Find your service account
3. Check that it has one of the FCM roles listed above

## Still Having Issues?

If you still get permission errors after granting the role:

1. **Regenerate the service account key** - This is often necessary after granting new permissions
2. **Wait 10-15 minutes** - IAM changes can take time to propagate
3. **Check the project ID** - Make sure the `project_id` in your service account JSON matches `safezone-ph`
4. **Verify service account** - Make sure the service account email in your `FCM_SERVICE_ACCOUNT` secret matches the one you granted permissions to
5. **Check API is enabled** - Verify "Firebase Cloud Messaging API" is enabled in APIs & Services
6. **Try Firebase Admin role** - As a last resort, grant "Firebase Admin" role (more permissive but will work)

## Verify Your Service Account

To check which service account you're using:

1. Go to Supabase Dashboard → Edge Functions → Secrets
2. View the `FCM_SERVICE_ACCOUNT` secret (it will show masked)
3. The `client_email` field in the JSON tells you which service account is being used
4. Make sure THIS service account has the FCM permissions in Google Cloud Console

