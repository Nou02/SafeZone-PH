-- Fix RLS policy to allow unauthenticated users to read barangays (for signup dropdown)
-- Drop existing policy
DROP POLICY IF EXISTS "Anyone can read barangays" ON barangays;

-- Allow anyone (including unauthenticated users) to read barangays
-- This is needed for the signup screen dropdown
CREATE POLICY "Anyone can read barangays"
  ON barangays
  FOR SELECT
  USING (true); -- Allow all SELECT operations







