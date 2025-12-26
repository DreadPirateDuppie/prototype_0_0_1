-- Add age column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS age INTEGER;

-- Optional: Add a check constraint for age (e.g., must be positive)
ALTER TABLE user_profiles 
ADD CONSTRAINT age_check CHECK (age > 0);
