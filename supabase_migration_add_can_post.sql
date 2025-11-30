-- Add can_post column to user_profiles table
-- This column controls whether a user is allowed to create new posts

DO $$
BEGIN
    -- Add can_post column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' AND column_name = 'can_post'
    ) THEN
        ALTER TABLE user_profiles
        ADD COLUMN can_post BOOLEAN DEFAULT TRUE NOT NULL;
        
        RAISE NOTICE 'Added can_post column to user_profiles table';
    ELSE
        RAISE NOTICE 'can_post column already exists in user_profiles table';
    END IF;
END $$;

-- Create index for filtering users who can/cannot post
CREATE INDEX IF NOT EXISTS idx_user_profiles_can_post ON user_profiles(can_post);

-- Add comment for documentation
COMMENT ON COLUMN user_profiles.can_post IS 'Whether the user is allowed to create new posts (admin restriction)';
