# Quick Guide: Deploy Notifications Edge Function

Your app is trying to send notifications but the Supabase Edge Function isn't deployed yet. Follow these steps:

## Method 1: Deploy via Supabase Dashboard (Easiest - No CLI needed!)

### Step 1: Get Your FCM Service Account JSON

Since the Legacy API is disabled, we'll use the newer FCM v1 API with a Service Account:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **SafeZone PH**
3. Go to **Project Settings** (gear icon) → **Service accounts** tab
4. Click **"Generate new private key"** button
5. Click **"Generate key"** in the confirmation dialog
6. A JSON file will download - **keep this file secure!** It contains your service account credentials
7. Open the JSON file and copy its entire contents (you'll need to paste it as a secret in Supabase)

### Step 2: Create the Edge Function in Supabase Dashboard

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Edge Functions** in the left sidebar
4. Click **"Create a new function"** or **"Deploy a new function"**
5. Name it: `notify-barangay-users`
6. Choose **"Via Editor"** to write the code directly

### Step 3: Paste the Function Code

Copy and paste this code into the editor:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Get service account JSON from environment variable
const SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT') || ''

interface ServiceAccount {
  project_id: string
  private_key: string
  client_email: string
}

// Get OAuth 2.0 access token for FCM v1 API
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  // Fix private key format - replace escaped newlines with actual newlines
  const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n')
  
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  // Convert PEM to binary format for Web Crypto API
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pemContents = privateKey
    .replace(pemHeader, '')
    .replace(pemFooter, '')
    .replace(/\s/g, '')
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  // Import the key using Web Crypto API
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )

  // Use djwt to create the JWT with the imported key
  const { create } = await import('https://deno.land/x/djwt@v2.8/mod.ts')
  const header = { alg: 'RS256', typ: 'JWT' }
  const token = await create(header, payload, cryptoKey)

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: token,
    }),
  })

  const data = await response.json()
  return data.access_token
}

serve(async (req) => {
  try {
    const { barangay_id, report_type, report_id, description } = await req.json()

    if (!barangay_id) {
      return new Response(
        JSON.stringify({ error: 'barangay_id is required' }),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    if (!SERVICE_ACCOUNT_JSON) {
      console.error('FCM_SERVICE_ACCOUNT is not set')
      return new Response(
        JSON.stringify({ error: 'FCM_SERVICE_ACCOUNT not configured' }),
        { 
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Parse service account JSON
    let serviceAccount: ServiceAccount
    try {
      serviceAccount = JSON.parse(SERVICE_ACCOUNT_JSON)
    } catch (e) {
      return new Response(
        JSON.stringify({ error: 'Invalid FCM_SERVICE_ACCOUNT JSON' }),
        { 
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Get Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get all device tokens for this barangay
    const { data: tokens, error } = await supabase.rpc(
      'get_barangay_device_tokens',
      { p_barangay_id: barangay_id }
    )

    if (error) {
      console.error('Error getting device tokens:', error)
      throw error
    }
    
    if (!tokens || tokens.length === 0) {
      console.log(`No devices found for barangay ${barangay_id}`)
      return new Response(
        JSON.stringify({ message: 'No devices found', count: 0 }),
        {
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Prepare notification message
    const title = `New ${report_type} Report`
    const body = description && description.length > 0
      ? (description.length > 100 ? `${description.substring(0, 100)}...` : description)
      : `A new ${report_type.toLowerCase()} report has been submitted in your barangay`

    // Get OAuth access token
    const accessToken = await getAccessToken(serviceAccount)

    console.log(`Sending notifications to ${tokens.length} devices for barangay ${barangay_id}`)

    // Send notifications to all devices using FCM v1 API
    const fcmPromises = tokens.map(async (token: { device_token: string; user_id: string }) => {
      try {
        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`
        
        const response = await fetch(fcmUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: token.device_token,
              notification: {
                title: title,
                body: body,
              },
              data: {
                report_id: report_id || '',
                report_type: report_type || '',
                barangay_id: barangay_id,
              },
              android: {
                priority: 'high',
              },
              apns: {
                headers: {
                  'apns-priority': '10',
                },
              },
            },
          }),
        })

        if (!response.ok) {
          const errorText = await response.text()
          console.error(`FCM error for token ${token.device_token.substring(0, 20)}...:`, errorText)
        }

        return { success: response.ok, token: token.device_token.substring(0, 20) }
      } catch (err) {
        console.error(`Error sending to token ${token.device_token.substring(0, 20)}...:`, err)
        return { success: false, error: err.message }
      }
    })

    const results = await Promise.all(fcmPromises)
    const successCount = results.filter(r => r.success).length

    return new Response(
      JSON.stringify({ 
        message: `Notifications sent to ${successCount} of ${tokens.length} devices`,
        success: true,
        total: tokens.length,
        successful: successCount,
      }),
      {
        headers: { 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})
```

### Step 4: Set the FCM Service Account Secret

1. **Open your Supabase Dashboard:**
   - Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
   - Select your project

2. **Navigate to Edge Functions Secrets:**
   - In the left sidebar, click **"Edge Functions"**
   - Click on the **"Secrets"** tab (at the top of the page, next to "Functions" and "Logs")

3. **Add the Secret:**
   - Click the **"Add new secret"** button (or **"New secret"** button)
   - In the **"Name"** field, enter: `FCM_SERVICE_ACCOUNT`
   - In the **"Value"** field, paste the **entire contents** of the JSON file:
     - Open the downloaded JSON file in a text editor (Notepad, VS Code, etc.)
     - Select all the text (Ctrl+A)
     - Copy it (Ctrl+C)
     - Paste it into the Value field (Ctrl+V)
   - Click **"Save"** or **"Add secret"**

4. **Verify the Secret:**
   - You should see `FCM_SERVICE_ACCOUNT` listed in your secrets
   - The value will be hidden (shown as dots/asterisks) for security

**Important Notes:**
- Paste the **entire JSON object** - from the opening `{` to the closing `}`
- Don't add extra quotes around it
- Make sure all the content is on one line or properly formatted
- The JSON should look like this (but with your actual values):
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "...",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  ...
}
```

### Step 5: Deploy the Function

1. Click **"Deploy function"** or **"Save"** button
2. Wait for deployment to complete (you'll see a success message)

### Step 6: Test It

1. Create a test report in your app
2. Check the Edge Function logs in Supabase Dashboard to see if it ran
3. Check if notifications are received

---

## Method 2: Deploy via CLI (Alternative)

If you prefer using CLI, install Supabase CLI first:

### Install Supabase CLI on Windows

**Option A: Using Scoop (Recommended)**
```powershell
# Install Scoop first (if not installed)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Then install Supabase
scoop install supabase
```

**Option B: Download Binary**
1. Go to https://github.com/supabase/cli/releases
2. Download the Windows binary (`supabase_windows_amd64.zip`)
3. Extract and add to PATH

### Deploy with CLI

```bash
# Login
supabase login

# Link project
supabase link --project-ref mtizgqcjaxscaegizvru

# Set secret (paste the entire JSON content)
supabase secrets set FCM_SERVICE_ACCOUNT='{"type":"service_account",...}'

# Deploy
supabase functions deploy notify-barangay-users
```

---

## Troubleshooting

### Function not found (404)
- Make sure you've deployed the function via Dashboard or CLI
- Check that the function name is exactly `notify-barangay-users`

### FCM_SERVICE_ACCOUNT not configured
- Make sure you set the secret `FCM_SERVICE_ACCOUNT` in Supabase Dashboard → Edge Functions → Secrets
- The value must be the complete JSON object from the service account file
- Make sure the JSON is valid (no extra quotes, proper formatting)

### No devices found
- Check that users have logged in and their device tokens are saved
- Query the `user_devices` table in Supabase SQL Editor:
  ```sql
  SELECT * FROM user_devices WHERE barangay_id = 'your-barangay-id';
  ```
- Make sure users have the same `barangay_id` as the report creator

### Notifications not received
- Check Edge Function logs in Supabase Dashboard → Edge Functions → Logs
- Verify FCM token is valid (test with Firebase Console → Cloud Messaging → Send test message)
- Ensure notification permissions are granted on the device
- Check app logs for error messages

### Check Function Logs
1. Go to Supabase Dashboard → Edge Functions
2. Click on `notify-barangay-users`
3. Click on **"Logs"** tab
4. Look for errors or success messages

## Testing

After deployment, test by:
1. Having two users logged in with the same barangay
2. One user creates a report
3. Check Edge Function logs to see if it was called
4. The other user should receive a notification

## Verify Everything is Set Up

1. ✅ `user_devices` table exists (run `setup_notifications.sql` if not)
2. ✅ `get_barangay_device_tokens` function exists (run `create_notification_function.sql` if you get function not found error)
3. ✅ Edge Function `notify-barangay-users` is deployed
4. ✅ Secret `FCM_SERVICE_ACCOUNT` is set (not FCM_SERVER_KEY)
5. ✅ Users have device tokens saved in `user_devices` table
6. ✅ Users have the same `barangay_id` in their metadata

## Fix: Function Not Found Error

If you get this error:
```
Could not find the function public.get_barangay_device_tokens(p_barangay_id) in the schema cache
```

**Solution:**
1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Open the file `create_notification_function.sql` from your project
4. Copy and paste the entire SQL script into the SQL Editor
5. Click **"Run"** or press Ctrl+Enter
6. You should see "Success. No rows returned" or similar success message

This will create the `get_barangay_device_tokens` function that the Edge Function needs.
