-- Location Privacy Settings Migration
-- Adds location sharing preferences to user_profiles

-- Add location sharing mode column
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS location_sharing_mode TEXT DEFAULT 'off' 
CHECK (location_sharing_mode IN ('off', 'public', 'friends'));

-- Add location blacklist column (array of user IDs to hide from)
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS location_blacklist TEXT[] DEFAULT '{}';

-- Add current location columns if they don't exist
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS current_latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS current_longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMP WITH TIME ZONE;

-- Create index for efficient location queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_location_sharing 
ON user_profiles(location_sharing_mode) 
WHERE location_sharing_mode != 'off';

-- Create index for location timestamps
CREATE INDEX IF NOT EXISTS idx_user_profiles_location_updated 
ON user_profiles(location_updated_at) 
WHERE location_updated_at IS NOT NULL;
