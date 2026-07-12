-- Function to get device tokens for a family
-- This function is used by the notify-family-members Edge Function
CREATE OR REPLACE FUNCTION get_family_device_tokens(p_family_id UUID)
RETURNS TABLE(device_token TEXT, user_id UUID) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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



