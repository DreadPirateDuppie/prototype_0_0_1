-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create new policies without recursion
CREATE POLICY "Users can view own profile"
ON user_profiles
FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
ON user_profiles
FOR SELECT
USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Users can insert own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid() = id);

CREATE POLICY "Admins can update all profiles"
ON user_profiles
FOR UPDATE
USING (auth.jwt() ->> 'role' = 'admin');
