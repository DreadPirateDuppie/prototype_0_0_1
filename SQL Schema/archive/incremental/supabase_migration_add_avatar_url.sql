-- Add avatar_url column to user_profiles table
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add comment to describe the column
COMMENT ON COLUMN user_profiles.avatar_url IS 'URL to the user''s profile picture stored in Supabase Storage';
