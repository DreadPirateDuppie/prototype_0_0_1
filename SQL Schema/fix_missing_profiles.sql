-- Re-runnable migration to fix missing user profiles

-- 1. Redefine the function to be robust (idempotent)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, username, display_name, location_sharing_mode, location_updated_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1)),
        'friends', -- Default to friends for better privacy
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        -- Optional: ensure username is set if missing
        username = EXCLUDED.username WHERE user_profiles.username IS NULL;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Ensure the trigger is active
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 3. Backfill missing profiles for EXISTING users
-- This catches any users who signed up when the trigger was missing or broken
INSERT INTO public.user_profiles (id, username, display_name, location_sharing_mode, location_updated_at, current_latitude, current_longitude)
SELECT 
    au.id,
    COALESCE(au.raw_user_meta_data->>'username', SPLIT_PART(au.email, '@', 1)),
    COALESCE(au.raw_user_meta_data->>'display_name', SPLIT_PART(au.email, '@', 1)),
    'friends', -- Default to friends
    NOW(),
    -- Optional: set a default location (e.g., London) or leave null
    51.4214, 
    -0.0700
FROM auth.users au
LEFT JOIN public.user_profiles up ON au.id = up.id
WHERE up.id IS NULL;
