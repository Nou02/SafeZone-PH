-- Function to get user names for family members
-- This function can access auth.users which the client cannot
CREATE OR REPLACE FUNCTION get_user_names_for_family(p_family_id UUID)
RETURNS TABLE(user_id UUID, full_name TEXT, email TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fm.user_id,
    COALESCE(
      (au.raw_user_meta_data->>'full_name')::TEXT,
      (au.raw_user_meta_data->>'email')::TEXT,
      'User ' || SUBSTRING(fm.user_id::TEXT, 1, 8)
    ) as full_name,
    COALESCE(
      au.email::TEXT,
      'Unknown'
    ) as email
  FROM family_members fm
  JOIN auth.users au ON au.id = fm.user_id
  WHERE fm.family_id = p_family_id
  ORDER BY fm.joined_at ASC;
END;
$$;



