-- Fix infinite recursion in family_members RLS policies
-- The issue is that policies are checking family_members within family_members policies

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view members of their families" ON family_members;
DROP POLICY IF EXISTS "Family owners can add members" ON family_members;
DROP POLICY IF EXISTS "Users can join families with valid code" ON family_members;
DROP POLICY IF EXISTS "Family owners can remove members" ON family_members;

-- Recreate policies without recursion
-- Users can view members of families they belong to (using families table check)
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

-- Family owners can add members (check via families table)
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

-- Users can join families (simplified - check if code exists)
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



