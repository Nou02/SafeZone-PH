-- Complete setup for Barangay Hall Location feature
-- Run this entire script in Supabase SQL Editor

-- Step 1: Add columns to store barangay hall location
ALTER TABLE barangays 
ADD COLUMN IF NOT EXISTS barangay_hall_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS barangay_hall_lng DOUBLE PRECISION;

-- Step 2: Drop existing policy if it exists (to allow re-running)
DROP POLICY IF EXISTS "Head officials can update barangay hall location" ON barangays;

-- Step 3: Add policy to allow Head Barangay Officials to update their barangay's hall location
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

-- Verify the columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'barangays' 
AND column_name IN ('barangay_hall_lat', 'barangay_hall_lng');







