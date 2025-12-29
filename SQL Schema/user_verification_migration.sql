-- Add is_verified column to user_profiles table
-- This column indicates whether a user has been verified by an admin

DO $$
BEGIN
    -- Add is_verified column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' AND column_name = 'is_verified'
    ) THEN
        ALTER TABLE user_profiles
        ADD COLUMN is_verified BOOLEAN DEFAULT FALSE NOT NULL;
        
        RAISE NOTICE 'Added is_verified column to user_profiles table';
    ELSE
        RAISE NOTICE 'is_verified column already exists in user_profiles table';
    END IF;
END $$;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_verified ON user_profiles(is_verified);

-- Add comment for documentation
COMMENT ON COLUMN user_profiles.is_verified IS 'Whether the user has been verified by an administrator';
