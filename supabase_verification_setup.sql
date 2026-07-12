-- Create verification_settings table for storing the passcode
CREATE TABLE IF NOT EXISTS verification_settings (
  id TEXT PRIMARY KEY DEFAULT 'main',
  verification_passcode TEXT NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE verification_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to allow re-running this script)
DROP POLICY IF EXISTS "Anyone can read verification passcode" ON verification_settings;
DROP POLICY IF EXISTS "Admins can manage verification settings" ON verification_settings;

-- Policy: All authenticated users can read the passcode (for verification)
CREATE POLICY "Anyone can read verification passcode"
  ON verification_settings
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Policy: Only admins can insert/update/delete verification settings
CREATE POLICY "Admins can manage verification settings"
  ON verification_settings
  FOR ALL
  USING (
    auth.jwt() ->> 'email' = 'illinoispss@gmail.com'
  )
  WITH CHECK (
    auth.jwt() ->> 'email' = 'illinoispss@gmail.com'
  );

-- Insert default passcode (admin can change this later)
INSERT INTO verification_settings (id, verification_passcode)
VALUES ('main', 'BARANGAY2024')
ON CONFLICT (id) DO NOTHING;

