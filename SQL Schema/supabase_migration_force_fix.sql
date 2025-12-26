-- FORCE FIX: Reset all permissions for user_profiles
-- This script drops ALL policies and re-creates them to ensure no conflicts exist.

-- 1. Ensure RLS is enabled
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- 2. Drop ALL existing policies (including any duplicates or old ones)
DROP POLICY IF EXISTS "Users can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile." ON public.user_profiles; -- Handle potential typo versions

-- 3. Re-create simple, permissive policies
CREATE POLICY "Users can view all profiles"
    ON public.user_profiles FOR SELECT
    USING (true);

-- Allow users to update their own row (no column restrictions in RLS)
CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- 4. Grant FULL permissions to authenticated users
-- This ensures no column-level grants are missing
GRANT ALL ON public.user_profiles TO authenticated;

-- 5. Force schema cache reload
NOTIFY pgrst, 'reload config';
