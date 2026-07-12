-- Step 1: Add the missing columns to store user name and email
ALTER TABLE barangay_official_passcodes 
ADD COLUMN IF NOT EXISTS used_by_name TEXT,
ADD COLUMN IF NOT EXISTS used_by_email TEXT;

-- Step 2: Make sure RLS is enabled
ALTER TABLE barangay_official_passcodes ENABLE ROW LEVEL SECURITY;

-- Step 3: Drop existing UPDATE policy if it exists
DROP POLICY IF EXISTS "Allow passcode verification updates" ON barangay_official_passcodes;

-- Step 4: Create a working UPDATE policy
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
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'barangay_official_passcodes' 
AND policyname = 'Allow passcode verification updates';







