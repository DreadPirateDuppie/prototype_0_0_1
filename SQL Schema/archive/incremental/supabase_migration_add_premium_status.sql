-- Add is_premium column to user_profiles table
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_premium ON public.user_profiles(is_premium);

-- Update RLS policies if necessary (usually select is already true, but good to check)
-- Users can already view all profiles, so no change needed for SELECT.
