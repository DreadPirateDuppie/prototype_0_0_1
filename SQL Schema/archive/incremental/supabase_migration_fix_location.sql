-- FIX: Enable Location Updates
-- This script explicitly fixes RLS policies to allow users to update their own location

-- 1. Ensure RLS is enabled (just in case)
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- 2. Drop the existing update policy to avoid conflicts
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;

-- 3. Re-create the policy with explicit permissions
-- We use USING for the "row to be updated" check
-- We use WITH CHECK for the "new row state" check
CREATE POLICY "Users can update own profile"
    ON public.user_profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 4. Grant explicit update permissions on location columns
GRANT UPDATE (current_latitude, current_longitude, location_updated_at) 
ON public.user_profiles 
TO authenticated;

-- 5. Verify the columns exist and are the correct type
ALTER TABLE public.user_profiles 
ALTER COLUMN current_latitude TYPE DOUBLE PRECISION,
ALTER COLUMN current_longitude TYPE DOUBLE PRECISION;

-- 6. Force a refresh of the schema cache (sometimes needed)
NOTIFY pgrst, 'reload config';
