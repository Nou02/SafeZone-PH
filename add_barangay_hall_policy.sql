-- Add policy to allow Head Barangay Officials to update barangay hall location
-- Run this after adding the columns

-- Add the policy
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







