-- Create table to store user device tokens for push notifications
CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  barangay_id UUID REFERENCES barangays(id) ON DELETE SET NULL,
  platform TEXT, -- 'android', 'ios', 'web'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, device_token)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_barangay ON user_devices(barangay_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_id);

-- Enable RLS
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only manage their own device tokens
CREATE POLICY "Users can insert their own device tokens"
  ON user_devices FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own device tokens"
  ON user_devices FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own device tokens"
  ON user_devices FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own device tokens"
  ON user_devices FOR SELECT
  USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_user_devices_timestamp
  BEFORE UPDATE ON user_devices
  FOR EACH ROW
  EXECUTE FUNCTION update_user_devices_updated_at();

-- Function to get device tokens for a barangay (for use in Edge Functions)
-- This will be called by the Edge Function to get tokens
CREATE OR REPLACE FUNCTION get_barangay_device_tokens(p_barangay_id UUID)
RETURNS TABLE(device_token TEXT, user_id UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT ud.device_token, ud.user_id
  FROM user_devices ud
  WHERE ud.barangay_id = p_barangay_id
    AND ud.device_token IS NOT NULL
    AND ud.device_token != '';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_barangay_device_tokens(UUID) TO authenticated;

-- Note: The actual FCM notification sending should be done via a Supabase Edge Function
-- because FCM requires server-side API keys. The Edge Function will:
-- 1. Call get_barangay_device_tokens() to get all tokens for the barangay
-- 2. Use Firebase Admin SDK to send notifications to those tokens
-- 3. Handle errors and retries






