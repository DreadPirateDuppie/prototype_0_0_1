-- Add is_admin column to user_profiles table if it doesn't exist
DO $$
BEGIN
    -- Check if the column already exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'user_profiles' AND column_name = 'is_admin') THEN
        -- Add the column with a default of false
        ALTER TABLE user_profiles 
        ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE;
        
        -- Create an index for faster admin lookups
        CREATE INDEX idx_user_profiles_is_admin ON user_profiles(is_admin);
        
        -- Grant necessary permissions
        GRANT SELECT, UPDATE (is_admin) ON user_profiles TO authenticated;
        
        -- Create a policy to allow admins to update admin status
        CREATE POLICY "Admins can update admin status"
        ON user_profiles
        FOR UPDATE
        USING (auth.uid() = id OR EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() AND is_admin = TRUE
        ));
        
        RAISE NOTICE 'Added is_admin column to user_profiles table';
    END IF;
END $$;
