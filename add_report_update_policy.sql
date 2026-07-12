-- Add RLS policy to allow officials to update report status
-- Head Barangay Officials and Barangay Officials should be able to update status

-- First, check if RLS is enabled
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Officials can update report status" ON reports;

-- Create policy to allow officials to update status
-- Officials are identified by having 'head_barangay_official' or 'barangay_official' role
-- and their barangay_id matches the report's barangay_id
CREATE POLICY "Officials can update report status"
  ON reports
  FOR UPDATE
  USING (
    -- Allow if user is a head barangay official or barangay official
    -- and the report's barangay_id matches their barangay_id
    (
      (auth.jwt() -> 'user_metadata' ->> 'role') = 'head_barangay_official'
      OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'barangay_official'
    )
    AND (
      barangay_id::text = (auth.jwt() -> 'user_metadata' ->> 'barangay_id')
      OR barangay_id::text = (auth.jwt() -> 'user_metadata' ->> 'user_barangay_id')
    )
  )
  WITH CHECK (
    -- Same conditions for the updated row
    (
      (auth.jwt() -> 'user_metadata' ->> 'role') = 'head_barangay_official'
      OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'barangay_official'
    )
    AND (
      barangay_id::text = (auth.jwt() -> 'user_metadata' ->> 'barangay_id')
      OR barangay_id::text = (auth.jwt() -> 'user_metadata' ->> 'user_barangay_id')
    )
  );







