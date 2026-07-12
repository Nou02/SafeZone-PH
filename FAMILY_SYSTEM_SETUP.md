# Family Notification System Setup

This guide will help you set up the family notification system.

## Step 1: Run Database Setup

1. Go to your Supabase Dashboard → SQL Editor
2. Run the contents of `setup_family_system.sql`
3. This creates:
   - `families` table
   - `family_members` table
   - `family_notifications` table
   - Required functions and RLS policies

## Step 2: Deploy Family Notifications Edge Function

1. Go to Supabase Dashboard → Edge Functions
2. Click "Create a new function" → Name it `notify-family-members`
3. Copy the code from `supabase/functions/notify-family-members/index.ts`
4. Paste it into the editor
5. Click "Deploy function"

**Note:** This function uses the same `FCM_SERVICE_ACCOUNT` secret as the barangay notifications function, so you don't need to set it again if you already have it.

## Step 3: Test the Feature

1. **Create a Family:**
   - Open the app
   - Go to the "Family" tab
   - Tap "Create Family"
   - Enter a family name
   - Note the join code

2. **Join a Family:**
   - On another device/account
   - Go to "Family" tab
   - Tap "Join Family"
   - Enter the join code

3. **Send Family Notification:**
   - Create a report
   - Select "Family Members" in the "Notify" dropdown
   - Submit the report
   - Family members should receive notifications

## Features

### Family Management
- **Create Family:** Users can create a family group
- **Join Family:** Users can join using a 6-character code
- **Manage Members:** Family owners can view and remove members
- **View Join Code:** Family owners can view/share the join code

### Family Notifications
- **Separate from Community Alerts:** Family notifications don't appear in community alerts
- **Notification History:** All family notifications are saved in `family_notifications` table
- **View Notifications:** Users can see all family notifications in the Family tab

### Report Creation
- When "Family Members" is selected, the report:
  - ✅ Sends notifications to all family members
  - ✅ Does NOT add to community alerts
  - ✅ Saves notification to family_notifications table

## Database Schema

### families
- `id` (UUID)
- `name` (TEXT)
- `join_code` (TEXT, unique)
- `created_by` (UUID, references auth.users)
- `created_at`, `updated_at`

### family_members
- `id` (UUID)
- `family_id` (UUID, references families)
- `user_id` (UUID, references auth.users)
- `role` (TEXT: 'owner' or 'member')
- `joined_at` (TIMESTAMPTZ)

### family_notifications
- `id` (UUID)
- `family_id` (UUID, references families)
- `sent_by` (UUID, references auth.users)
- `report_id` (UUID, references reports, nullable)
- `title` (TEXT)
- `message` (TEXT)
- `created_at` (TIMESTAMPTZ)

## Security

- RLS policies ensure users can only:
  - View families they belong to
  - Create families
  - Join families with valid codes
  - View notifications from their families
  - Owners can manage members

## Troubleshooting

### Can't create family
- Make sure you're logged in
- Check database setup completed successfully

### Can't join family
- Verify the join code is correct (case-insensitive)
- Make sure you're not already a member

### Notifications not received
- Check Edge Function is deployed
- Verify `FCM_SERVICE_ACCOUNT` secret is set
- Check device tokens are saved in `user_devices` table
- Verify both users are in the same family



