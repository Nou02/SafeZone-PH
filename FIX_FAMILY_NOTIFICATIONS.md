# Fix Family Notifications Not Appearing

## Issues Found

1. **Edge Function may not be deployed** - The `notify-family-members` Edge Function needs to be deployed to Supabase
2. **Database function may be missing** - The `get_family_device_tokens` function needs to exist
3. **RLS policies may block Edge Function** - The Edge Function uses service_role, so RLS should allow it

## Steps to Fix

### 1. Ensure Database Function Exists

Run this SQL in Supabase SQL Editor:
```sql
-- See create_family_device_tokens_function.sql
```

### 2. Deploy the Edge Function

The Edge Function code is in `supabase/functions/notify-family-members/index.ts`

**To deploy via Supabase Dashboard:**
1. Go to Supabase Dashboard → Edge Functions
2. Click "Create a new function"
3. Name it `notify-family-members`
4. Copy the contents of `supabase/functions/notify-family-members/index.ts`
5. Paste it into the function editor
6. Set the secret `FCM_SERVICE_ACCOUNT` (same as used for `notify-barangay-users`)
7. Deploy the function

### 3. Verify RLS Policies

The `family_notifications` table should allow inserts from the service_role (Edge Functions). The current policy only allows authenticated users. We may need to add a policy or ensure service_role can bypass RLS.

### 4. Check Logs

After deploying, check:
- Supabase Edge Function logs for errors
- Flutter debug console for "Family notification response" messages
- Database to see if notifications are being inserted

### 5. Test

1. Create a report with "Family Members" as notify target
2. Check the Edge Function logs
3. Check if notification appears in `family_notifications` table
4. Check if push notification is received

## Debugging

The updated code now includes better logging:
- `debugPrint('Family notification response: ${response.data}')` - Shows Edge Function response
- `debugPrint('Failed to send family notifications: $e')` - Shows any errors

Check the Flutter debug console when creating a report to see these messages.



