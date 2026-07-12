-- Create barangays table for City Admin to manage
CREATE TABLE IF NOT EXISTS barangays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  head_official_passcode TEXT NOT NULL UNIQUE, -- Unique passcode for Head Barangay Official
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create barangay_official_passcodes table for Head Barangay Officials to generate codes
CREATE TABLE IF NOT EXISTS barangay_official_passcodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barangay_id UUID NOT NULL REFERENCES barangays(id) ON DELETE CASCADE,
  generated_by_user_id UUID NOT NULL, -- Head Barangay Official who generated it
  passcode TEXT NOT NULL UNIQUE,
  used_by_user_id UUID, -- User who used this passcode (null if unused)
  used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE, -- Optional expiration
  CONSTRAINT fk_barangay FOREIGN KEY (barangay_id) REFERENCES barangays(id)
);

-- Enable RLS
ALTER TABLE barangays ENABLE ROW LEVEL SECURITY;
ALTER TABLE barangay_official_passcodes ENABLE ROW LEVEL SECURITY;

-- Barangays policies
-- Drop existing policies if they exist (to allow re-running this script)
DROP POLICY IF EXISTS "Anyone can read barangays" ON barangays;
DROP POLICY IF EXISTS "City admin can manage barangays" ON barangays;

-- Anyone (including unauthenticated users) can read barangays
-- This is needed for the signup screen dropdown
CREATE POLICY "Anyone can read barangays"
  ON barangays
  FOR SELECT
  USING (true); -- Allow all SELECT operations

-- Only city admin can manage barangays (create, delete, update name/passcode)
CREATE POLICY "City admin can manage barangays"
  ON barangays
  FOR ALL
  USING (
    auth.jwt() ->> 'email' = 'illinoispss@gmail.com'
  )
  WITH CHECK (
    auth.jwt() ->> 'email' = 'illinoispss@gmail.com'
  );

-- Head Barangay Officials can update their barangay's hall location
CREATE POLICY "Head officials can update barangay hall location"
  ON barangays
  FOR UPDATE
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'head_barangay_official'
    AND id::text = (auth.jwt() -> 'user_metadata' ->> 'barangay_id')
  )
  WITH CHECK (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'head_barangay_official'
    AND id::text = (auth.jwt() -> 'user_metadata' ->> 'barangay_id')
  );

-- Barangay official passcodes policies
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Head officials can read their barangay passcodes" ON barangay_official_passcodes;
DROP POLICY IF EXISTS "Head officials can create passcodes" ON barangay_official_passcodes;
DROP POLICY IF EXISTS "Anyone can read unused passcodes for verification" ON barangay_official_passcodes;
DROP POLICY IF EXISTS "Allow passcode verification updates" ON barangay_official_passcodes;

-- Head Barangay Officials can read passcodes for their barangay
CREATE POLICY "Head officials can read their barangay passcodes"
  ON barangay_official_passcodes
  FOR SELECT
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'head_barangay_official'
    AND (
      barangay_id::text = (auth.jwt() -> 'user_metadata' ->> 'barangay_id')
      OR generated_by_user_id = auth.uid()
    )
  );

-- Head Barangay Officials can create passcodes for their barangay
-- Note: User must sign out and sign back in after verification to refresh JWT token
CREATE POLICY "Head officials can create passcodes"
  ON barangay_official_passcodes
  FOR INSERT
  WITH CHECK (
    -- Must be generating for themselves
    generated_by_user_id = auth.uid()
    -- Must have head_barangay_official role
    AND (auth.jwt() -> 'user_metadata' ->> 'role') = 'head_barangay_official'
    -- barangay_id must match (or be null if JWT hasn't refreshed yet - less secure but allows operation)
    AND (
      barangay_id::text = (auth.jwt() -> 'user_metadata' ->> 'barangay_id')
      OR (auth.jwt() -> 'user_metadata' ->> 'barangay_id') IS NULL
    )
  );

-- Anyone authenticated can read unused passcodes (to verify)
CREATE POLICY "Anyone can read unused passcodes for verification"
  ON barangay_official_passcodes
  FOR SELECT
  USING (
    auth.role() = 'authenticated' 
    AND used_by_user_id IS NULL
    AND (expires_at IS NULL OR expires_at > NOW())
  );

-- Allow users to update passcodes when they verify (mark as used)
-- This policy allows any authenticated user to mark an unused passcode as used by them
-- We check both USING (can they see the row) and WITH CHECK (is the update valid)
CREATE POLICY "Allow passcode verification updates"
  ON barangay_official_passcodes
  FOR UPDATE
  USING (
    auth.role() = 'authenticated'
    AND used_by_user_id IS NULL
  )
  WITH CHECK (
    auth.role() = 'authenticated'
    AND used_by_user_id = auth.uid()
    AND used_at IS NOT NULL
  );

-- Function to generate random passcode
CREATE OR REPLACE FUNCTION generate_passcode(length INTEGER DEFAULT 8)
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Excluding confusing chars
  result TEXT := '';
  i INTEGER;
BEGIN
  FOR i IN 1..length LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

