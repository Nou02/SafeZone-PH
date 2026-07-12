-- Create the function to get device tokens for a barangay
-- This is needed for the Edge Function to send notifications

CREATE OR REPLACE FUNCTION public.get_barangay_device_tokens(p_barangay_id UUID)
RETURNS TABLE(device_token TEXT, user_id UUID) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT ud.device_token, ud.user_id
  FROM public.user_devices ud
  WHERE ud.barangay_id = p_barangay_id
    AND ud.device_token IS NOT NULL
    AND ud.device_token != '';
END;
$$;

-- Grant execute permission to authenticated users and service role
GRANT EXECUTE ON FUNCTION public.get_barangay_device_tokens(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_barangay_device_tokens(UUID) TO service_role;

-- Also make sure the user_devices table exists
CREATE TABLE IF NOT EXISTS public.user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  barangay_id UUID REFERENCES public.barangays(id) ON DELETE SET NULL,
  platform TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, device_token)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_barangay ON public.user_devices(barangay_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_user ON public.user_devices(user_id);

-- Enable RLS
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- Policies (if they don't exist)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'user_devices' 
    AND policyname = 'Users can insert their own device tokens'
  ) THEN
    CREATE POLICY "Users can insert their own device tokens"
      ON public.user_devices FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'user_devices' 
    AND policyname = 'Users can update their own device tokens'
  ) THEN
    CREATE POLICY "Users can update their own device tokens"
      ON public.user_devices FOR UPDATE
      USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'user_devices' 
    AND policyname = 'Users can delete their own device tokens'
  ) THEN
    CREATE POLICY "Users can delete their own device tokens"
      ON public.user_devices FOR DELETE
      USING (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'user_devices' 
    AND policyname = 'Users can view their own device tokens'
  ) THEN
    CREATE POLICY "Users can view their own device tokens"
      ON public.user_devices FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END $$;



