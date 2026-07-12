-- Add columns to store user name and email when passcode is used
ALTER TABLE barangay_official_passcodes 
ADD COLUMN IF NOT EXISTS used_by_name TEXT,
ADD COLUMN IF NOT EXISTS used_by_email TEXT;







