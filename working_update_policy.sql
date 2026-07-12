-- Working UPDATE policy for passcode verification
-- This allows authenticated users to mark unused passcodes as used

-- First, make sure RLS is enabled
ALTER TABLE barangay_official_passcodes ENABLE ROW LEVEL SECURITY;

-- Drop any existing UPDATE policy
DROP POLICY IF EXISTS "Allow passcode verification updates" ON barangay_official_passcodes;

-- Create the working UPDATE policy
-- The key is that WITH CHECK must allow the updated row to exist
CREATE POLICY "Allow passcode verification updates"
  ON barangay_official_passcodes
  FOR UPDATE
  USING (
    -- User can only update if they're authenticated and the passcode is unused
    auth.role() = 'authenticated'
    AND used_by_user_id IS NULL
  )
  WITH CHECK (
    -- After update, the row must still be accessible
    -- We allow it if the user is authenticated and setting themselves as the user
    auth.role() = 'authenticated'
    AND used_by_user_id = auth.uid()
  );

-- Verify it was created
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'barangay_official_passcodes' 
AND policyname = 'Allow passcode verification updates';







