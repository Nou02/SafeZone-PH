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

    // Get OAuth access token
    const accessToken = await getAccessToken(serviceAccount)

    // Prepare notification message
    const title = `New ${report_type} Report`
    const body = description && description.length > 0
      ? (description.length > 100 ? `${description.substring(0, 100)}...` : description)
      : `A new ${report_type.toLowerCase()} report has been submitted in your barangay`

    console.log(`Sending notifications to ${tokens.length} devices for barangay ${barangay_id}`)

    // Send notifications to all devices using FCM v1 API
    const invalidTokens: string[] = []
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
          try {
            const errorData = JSON.parse(errorText)
            
            // Check if token is unregistered/invalid
            if (errorData.error?.code === 404 || 
                errorData.error?.details?.[0]?.errorCode === 'UNREGISTERED' ||
                errorData.error?.details?.[0]?.errorCode === 'INVALID_ARGUMENT') {
              console.log(`Removing invalid token: ${token.device_token.substring(0, 20)}...`)
              invalidTokens.push(token.device_token)
            } else {
              console.error(`FCM error for token ${token.device_token.substring(0, 20)}...:`, errorText)
            }
          } catch (parseErr) {
            // If error response isn't JSON, just log it
            console.error(`FCM error for token ${token.device_token.substring(0, 20)}...:`, errorText)
          }
        }

        return { success: response.ok, token: token.device_token.substring(0, 20) }
      } catch (err) {
        console.error(`Error sending to token ${token.device_token.substring(0, 20)}...:`, err)
        return { success: false, error: err.message }
      }
    })

    const results = await Promise.all(fcmPromises)
    const successCount = results.filter(r => r.success).length

    // Remove invalid tokens from database
    if (invalidTokens.length > 0) {
      try {
        await supabase
          .from('user_devices')
          .delete()
          .in('device_token', invalidTokens)
        console.log(`Removed ${invalidTokens.length} invalid device tokens from database`)
      } catch (e) {
        console.error('Error removing invalid tokens:', e)
      }
    }

    return new Response(
      JSON.stringify({ 
        message: `Notifications sent to ${successCount} of ${tokens.length} devices`,
        success: true,
        total: tokens.length,
        successful: successCount,
        invalidTokensRemoved: invalidTokens.length,
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
