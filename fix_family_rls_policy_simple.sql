-- Fix infinite recursion in families and family_members RLS policies
-- Solution: Use SECURITY DEFINER functions to bypass RLS when checking membership

-- Drop existing policies on both tables
DROP POLICY IF EXISTS "Users can view families they belong to" ON families;
DROP POLICY IF EXISTS "Users can create families" ON families;
DROP POLICY IF EXISTS "Family owners can update their family" ON families;

DROP POLICY IF EXISTS "Users can view members of their families" ON family_members;
DROP POLICY IF EXISTS "Family owners can add members" ON family_members;
DROP POLICY IF EXISTS "Users can join families with valid code" ON family_members;
DROP POLICY IF EXISTS "Family owners can remove members" ON family_members;

-- Create helper function that bypasses RLS to check if user is a member
-- SECURITY DEFINER allows this function to bypass RLS on family_members
CREATE OR REPLACE FUNCTION user_is_family_member(p_family_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id
    AND user_id = auth.uid()
  );
END;
$$;

-- Create helper function to check if user is family owner
CREATE OR REPLACE FUNCTION user_is_family_owner(p_family_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  -- Check if user created the family
  IF EXISTS (
    SELECT 1 FROM families
    WHERE id = p_family_id
    AND created_by = auth.uid()
  ) THEN
    RETURN TRUE;
  END IF;
  
  -- Check if user is an owner member
  RETURN EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id
    AND user_id = auth.uid()
    AND role = 'owner'
  );
END;
$$;

-- Create helper function to check if family has a valid join code (bypasses RLS)
CREATE OR REPLACE FUNCTION family_has_join_code(p_family_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM families
    WHERE id = p_family_id
    AND join_code IS NOT NULL
  );
END;
$$;

-- Create function to validate join code (bypasses RLS)
-- Returns JSON object with family data or null if not found
CREATE OR REPLACE FUNCTION validate_family_join_code(p_join_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_family JSON;
BEGIN
  SELECT row_to_json(f.*) INTO v_family
  FROM families f
  WHERE f.join_code = UPPER(p_join_code)
  LIMIT 1;
  
  RETURN v_family;
END;
$$;

-- Recreate families table policies using helper functions (no recursion!)
CREATE POLICY "Users can view families they belong to"
  ON families FOR SELECT
  USING (
    created_by = auth.uid()
    OR user_is_family_member(id)
  );

CREATE POLICY "Users can create families"
  ON families FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Family owners can update their family"
  ON families FOR UPDATE
  USING (
    user_is_family_owner(id)
  );

-- Recreate family_members table policies using helper functions (no recursion!)
CREATE POLICY "Users can view members of their families"
  ON family_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM families f
      WHERE f.id = family_members.family_id
      AND (
        f.created_by = auth.uid()
        OR user_is_family_member(f.id)
      )
    )
  );

CREATE POLICY "Family owners can add members"
  ON family_members FOR INSERT
  WITH CHECK (
    user_is_family_owner(family_members.family_id)
  );

CREATE POLICY "Users can join families with valid code"
  ON family_members FOR INSERT
  WITH CHECK (
    -- Family must exist and have a join code (use function to bypass RLS)
    family_has_join_code(family_members.family_id)
    -- User must be inserting their own record
    AND user_id = auth.uid()
    -- User must not already be a member (check using function to avoid recursion)
    AND NOT user_is_family_member(family_members.family_id)
    -- Role must be 'member' (not 'owner' - owners are added differently)
    AND (role = 'member' OR role IS NULL)
  );

CREATE POLICY "Family owners can remove members"
  ON family_members FOR DELETE
  USING (
    user_is_family_owner(family_members.family_id)
  );

