-- Add status column to reports table
-- Status can be: 'pending', 'responding', 'resolved'
-- Default is 'pending'

ALTER TABLE reports
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';

-- Add check constraint to ensure valid status values
ALTER TABLE reports
DROP CONSTRAINT IF EXISTS reports_status_check;

ALTER TABLE reports
ADD CONSTRAINT reports_status_check 
CHECK (status IN ('pending', 'responding', 'resolved'));

-- Create index for faster status queries
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);

-- Add comment
COMMENT ON COLUMN reports.status IS 'Status of the report: pending (default), responding, or resolved';







