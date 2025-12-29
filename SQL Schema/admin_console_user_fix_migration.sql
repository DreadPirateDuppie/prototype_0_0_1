-- Admin Console User Info Fix Migration
-- Adds missing columns to user_profiles and backfills emails

DO $$
BEGIN
    -- 1. Add email column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'email') THEN
        ALTER TABLE public.user_profiles ADD COLUMN email TEXT;
        RAISE NOTICE 'Added email column to user_profiles';
    END IF;

    -- 2. Add is_banned column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'is_banned') THEN
        ALTER TABLE public.user_profiles ADD COLUMN is_banned BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_banned column to user_profiles';
    END IF;

    -- 3. Add ban_reason column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'ban_reason') THEN
        ALTER TABLE public.user_profiles ADD COLUMN ban_reason TEXT;
        RAISE NOTICE 'Added ban_reason column to user_profiles';
    END IF;

    -- 4. Add banned_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'banned_at') THEN
        ALTER TABLE public.user_profiles ADD COLUMN banned_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added banned_at column to user_profiles';
    END IF;

    -- 5. Add is_verified column if it doesn't exist (Safety check)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'is_verified') THEN
        ALTER TABLE public.user_profiles ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_verified column to user_profiles';
    END IF;

    -- 6. Add can_post column if it doesn't exist (Safety check)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'can_post') THEN
        ALTER TABLE public.user_profiles ADD COLUMN can_post BOOLEAN DEFAULT TRUE;
        RAISE NOTICE 'Added can_post column to user_profiles';
    END IF;
    RAISE NOTICE 'Admin Console user info fix migration completed';
END $$;

-- 7. Backfill emails from auth.users
UPDATE public.user_profiles up
SET email = u.email
FROM auth.users u
WHERE up.id = u.id AND (up.email IS NULL OR up.email = '');

-- 8. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_banned ON public.user_profiles(is_banned);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_verified ON public.user_profiles(is_verified);
