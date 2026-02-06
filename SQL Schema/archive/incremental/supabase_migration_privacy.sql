-- Add privacy flag to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;

-- Update RLS policies to respect privacy settings
-- For this prototype, the application-level logic will handle visibility primarily.

COMMENT ON COLUMN user_profiles.is_private IS 'If true, user content is only visible to followers';
