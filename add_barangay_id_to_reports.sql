-- Add barangay_id column to reports table
-- This allows officials to filter reports by their barangay

ALTER TABLE reports
ADD COLUMN IF NOT EXISTS barangay_id UUID REFERENCES barangays(id);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_reports_barangay_id ON reports(barangay_id);

-- Add comment
COMMENT ON COLUMN reports.barangay_id IS 'The barangay where the report was made, based on the user''s barangay selection';







