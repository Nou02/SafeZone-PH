-- Complete fix for passcode update policy
-- This allows any authenticated user to mark an unused passcode as used

-- First, drop all existing UPDATE policies
DROP POLICY IF EXISTS "Allow passcode verification updates" ON barangay_official_passcodes;

-- Create a simple, permissive UPDATE policy
-- This allows authenticated users to update unused passcodes to mark them as used
CREATE POLICY "Allow passcode verification updates"
  ON barangay_official_passcodes
  FOR UPDATE
  USING (
    -- User must be authenticated
    auth.role() = 'authenticated'
    -- And the passcode must currently be unused
    AND used_by_user_id IS NULL
  )
  WITH CHECK (
    -- After update, user must still be authenticated
    auth.role() = 'authenticated'
    -- And they must set themselves as the user who used it
    AND used_by_user_id = auth.uid()
  );

-- Verify the policy was created
SELECT * FROM pg_policies WHERE tablename = 'barangay_official_passcodes' AND policyname = 'Allow passcode verification updates';







