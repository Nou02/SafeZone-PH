-- Add columns to store barangay hall location
ALTER TABLE barangays 
ADD COLUMN IF NOT EXISTS barangay_hall_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS barangay_hall_lng DOUBLE PRECISION;







