-- Fix infinite recursion in family_members RLS policies
-- The issue: policies check family_members within family_members policies
-- Solution: Use security definer functions to bypass RLS checks

-- First, drop all existing policies
DROP POLICY IF EXISTS "Users can view members of their families" ON family_members;
DROP POLICY IF EXISTS "Family owners can add members" ON family_members;
DROP POLICY IF EXISTS "Users can join families with valid code" ON family_members;
DROP POLICY IF EXISTS "Family owners can remove members" ON family_members;

-- Create helper functions that bypass RLS to check membership
CREATE OR REPLACE FUNCTION is_family_member(p_family_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id
    AND user_id = p_user_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION is_family_owner(p_family_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM families
    WHERE id = p_family_id
    AND created_by = p_user_id
  ) OR EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id
    AND user_id = p_user_id
    AND role = 'owner'
  );
END;
$$;

-- Now create policies using these functions (no recursion!)
CREATE POLICY "Users can view members of their families"
  ON family_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM families f
      WHERE f.id = family_members.family_id
      AND (
        f.created_by = auth.uid()
        OR is_family_member(f.id, auth.uid())
      )
    )
  );

CREATE POLICY "Family owners can add members"
  ON family_members FOR INSERT
  WITH CHECK (
    is_family_owner(family_members.family_id, auth.uid())
  );

CREATE POLICY "Users can join families with valid code"
  ON family_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM families f
      WHERE f.id = family_members.family_id
      AND f.join_code IS NOT NULL
    )
    AND user_id = auth.uid()
    AND NOT is_family_member(family_members.family_id, auth.uid())
  );

CREATE POLICY "Family owners can remove members"
  ON family_members FOR DELETE
  USING (
    is_family_owner(family_members.family_id, auth.uid())
  );



