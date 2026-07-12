-- Family System Setup
-- This creates tables for family groups, members, and notifications

-- Create families table
CREATE TABLE IF NOT EXISTS families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  join_code TEXT UNIQUE NOT NULL,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create family_members table
CREATE TABLE IF NOT EXISTS family_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member', -- 'owner' or 'member'
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(family_id, user_id)
);

-- Create family_notifications table (for storing family notification history)
CREATE TABLE IF NOT EXISTS family_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  sent_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  report_id UUID REFERENCES reports(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_family_members_family ON family_members(family_id);
CREATE INDEX IF NOT EXISTS idx_family_members_user ON family_members(user_id);
CREATE INDEX IF NOT EXISTS idx_family_notifications_family ON family_notifications(family_id);
CREATE INDEX IF NOT EXISTS idx_families_join_code ON families(join_code);

-- Enable RLS
ALTER TABLE families ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for families
CREATE POLICY "Users can view families they belong to"
  ON families FOR SELECT
  USING (
    id IN (
      SELECT family_id FROM family_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create families"
  ON families FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Family owners can update their family"
  ON families FOR UPDATE
  USING (
    created_by = auth.uid() OR
    id IN (
      SELECT family_id FROM family_members 
      WHERE user_id = auth.uid() AND role = 'owner'
    )
  );

-- RLS Policies for family_members (fixed to avoid infinite recursion)
-- Users can view members of families they belong to (check via families table)
CREATE POLICY "Users can view members of their families"
  ON family_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM families f
      WHERE f.id = family_members.family_id
      AND (
        f.created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM family_members fm
          WHERE fm.family_id = f.id
          AND fm.user_id = auth.uid()
        )
      )
    )
  );

-- Family owners can add members (check via families table to avoid recursion)
CREATE POLICY "Family owners can add members"
  ON family_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM families f
      WHERE f.id = family_members.family_id
      AND (
        f.created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM family_members fm
          WHERE fm.family_id = f.id
          AND fm.user_id = auth.uid()
          AND fm.role = 'owner'
        )
      )
    )
  );

-- Users can join families with valid code (simplified)
CREATE POLICY "Users can join families with valid code"
  ON family_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM families f
      WHERE f.id = family_members.family_id
      AND f.join_code IS NOT NULL
    )
    AND user_id = auth.uid()
    AND NOT EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.family_id = family_members.family_id
      AND fm.user_id = auth.uid()
    )
  );

-- Family owners can remove members (check via families table)
CREATE POLICY "Family owners can remove members"
  ON family_members FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM families f
      WHERE f.id = family_members.family_id
      AND (
        f.created_by = auth.uid()
        OR EXISTS (
          SELECT 1 FROM family_members fm
          WHERE fm.family_id = f.id
          AND fm.user_id = auth.uid()
          AND fm.role = 'owner'
        )
      )
    )
  );

-- RLS Policies for family_notifications
CREATE POLICY "Users can view notifications from their families"
  ON family_notifications FOR SELECT
  USING (
    family_id IN (
      SELECT family_id FROM family_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Family members can create notifications"
  ON family_notifications FOR INSERT
  WITH CHECK (
    family_id IN (
      SELECT family_id FROM family_members WHERE user_id = auth.uid()
    ) AND sent_by = auth.uid()
  );

-- Function to generate unique join code
CREATE OR REPLACE FUNCTION generate_family_join_code()
RETURNS TEXT AS $$
DECLARE
  code TEXT;
  exists_check BOOLEAN;
BEGIN
  LOOP
    -- Generate a 6-character alphanumeric code
    code := upper(
      substr(
        encode(gen_random_bytes(4), 'base64'),
        1, 6
      )
    );
    -- Replace special characters with numbers
    code := replace(replace(replace(code, '/', '7'), '+', '8'), '=', '9');
    
    -- Check if code already exists
    SELECT EXISTS(SELECT 1 FROM families WHERE join_code = code) INTO exists_check;
    
    EXIT WHEN NOT exists_check;
  END LOOP;
  
  RETURN code;
END;
$$ LANGUAGE plpgsql;

-- Function to get device tokens for a family
CREATE OR REPLACE FUNCTION get_family_device_tokens(p_family_id UUID)
RETURNS TABLE(device_token TEXT, user_id UUID) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT ud.device_token, ud.user_id
  FROM user_devices ud
  INNER JOIN family_members fm ON fm.user_id = ud.user_id
  WHERE fm.family_id = p_family_id
    AND ud.device_token IS NOT NULL
    AND ud.device_token != '';
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_family_device_tokens(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_family_device_tokens(UUID) TO service_role;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_families_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_families_timestamp
  BEFORE UPDATE ON families
  FOR EACH ROW
  EXECUTE FUNCTION update_families_updated_at();

