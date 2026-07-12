-- Fix the passcode update policy to allow users to mark passcodes as used
-- Run this in Supabase SQL Editor

-- Drop the existing policy
DROP POLICY IF EXISTS "Allow passcode verification updates" ON barangay_official_passcodes;

-- Create a more permissive UPDATE policy
-- This allows any authenticated user to update an unused passcode to mark it as used by them
CREATE POLICY "Allow passcode verification updates"
  ON barangay_official_passcodes
  FOR UPDATE
  USING (
    -- Can only update if the passcode is currently unused
    auth.role() = 'authenticated'
    AND used_by_user_id IS NULL
  )
  WITH CHECK (
    -- After update, must be authenticated and must set themselves as the user
    auth.role() = 'authenticated'
    AND used_by_user_id = auth.uid()
  );







