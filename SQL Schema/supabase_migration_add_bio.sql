-- Migration: Add bio field to user_profiles table
-- Run this in your Supabase SQL Editor

-- Add bio column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS bio TEXT;

-- Optional: Set a default empty string for existing users
UPDATE user_profiles 
SET bio = '' 
WHERE bio IS NULL;

-- Optional: Add a comment to the column for documentation
COMMENT ON COLUMN user_profiles.bio IS 'User biography text (max ~500 characters recommended)';
