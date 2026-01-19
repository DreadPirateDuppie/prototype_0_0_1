-- COMPLETE DATABASE SETUP FOR PUSHINN APP
-- Run this script in your Supabase SQL Editor to set up all tables and columns
-- 
-- Instructions:
-- 1. Go to your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your project
-- 3. Click "SQL Editor" in the left sidebar
-- 4. Click "New Query"
-- 5. Copy and paste this ENTIRE file
-- 6. Click "Run" at the bottom right

-- ============================================
-- STEP 1: Create/Update user_profiles table
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add missing columns if they don't exist
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_username ON public.user_profiles(username);
CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name ON public.user_profiles(display_name);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_admin ON public.user_profiles(is_admin);

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop and recreate policies
DROP POLICY IF EXISTS "Users can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;

CREATE POLICY "Users can view all profiles"
    ON public.user_profiles FOR SELECT USING (true);

CREATE POLICY "Users can update own profile"
    ON public.user_profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.user_profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================
-- STEP 2: Create/Update map_posts table
-- ============================================
CREATE TABLE IF NOT EXISTS map_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add missing columns if they don't exist
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS likes INTEGER DEFAULT 0;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS photo_urls TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS video_url TEXT;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS popularity_rating DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS security_rating DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS quality_rating DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS upvotes INTEGER DEFAULT 0;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS downvotes INTEGER DEFAULT 0;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS vote_score INTEGER DEFAULT 0;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Other';
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS user_name TEXT;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS user_email TEXT;
ALTER TABLE map_posts ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Enable RLS
ALTER TABLE map_posts ENABLE ROW LEVEL SECURITY;

-- Drop and recreate policies
DROP POLICY IF EXISTS "Users can view all posts" ON map_posts;
DROP POLICY IF EXISTS "Users can insert own posts" ON map_posts;
DROP POLICY IF EXISTS "Users can update own posts" ON map_posts;
DROP POLICY IF EXISTS "Users can delete own posts" ON map_posts;

CREATE POLICY "Users can view all posts"
    ON map_posts FOR SELECT USING (true);

CREATE POLICY "Users can insert own posts"
    ON map_posts FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own posts"
    ON map_posts FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own posts"
    ON map_posts FOR DELETE USING (auth.uid() = user_id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_map_posts_user_id ON map_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_map_posts_created_at ON map_posts(created_at);
CREATE INDEX IF NOT EXISTS idx_map_posts_location ON map_posts(latitude, longitude);

-- ============================================
-- STEP 3: Create/Update battles table
-- ============================================
CREATE TABLE IF NOT EXISTS battles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add ALL columns if they don't exist (including the base ones)
ALTER TABLE battles ADD COLUMN IF NOT EXISTS challenger_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE battles ADD COLUMN IF NOT EXISTS opponent_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS wager INTEGER DEFAULT 0;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE battles ADD COLUMN IF NOT EXISTS winner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS challenger_letters TEXT DEFAULT '';
ALTER TABLE battles ADD COLUMN IF NOT EXISTS opponent_letters TEXT DEFAULT '';
ALTER TABLE battles ADD COLUMN IF NOT EXISTS current_setter_id UUID REFERENCES auth.users(id);
ALTER TABLE battles ADD COLUMN IF NOT EXISTS current_trick_name TEXT;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS challenger_voted BOOLEAN DEFAULT FALSE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS opponent_voted BOOLEAN DEFAULT FALSE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS challenger_vote_landed BOOLEAN;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS opponent_vote_landed BOOLEAN;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS bet_accepted BOOLEAN DEFAULT FALSE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;

-- Enable RLS
ALTER TABLE battles ENABLE ROW LEVEL SECURITY;

-- Drop and recreate policies
DROP POLICY IF EXISTS "Users can view all battles" ON battles;
DROP POLICY IF EXISTS "Users can insert battles" ON battles;
DROP POLICY IF EXISTS "Users can update battles they participate in" ON battles;

CREATE POLICY "Users can view all battles"
    ON battles FOR SELECT USING (true);

CREATE POLICY "Users can insert battles"
    ON battles FOR INSERT WITH CHECK (auth.uid() = challenger_id);

CREATE POLICY "Users can update battles they participate in"
    ON battles FOR UPDATE USING (auth.uid() = challenger_id OR auth.uid() = opponent_id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_battles_challenger ON battles(challenger_id);
CREATE INDEX IF NOT EXISTS idx_battles_opponent ON battles(opponent_id);
CREATE INDEX IF NOT EXISTS idx_battles_status ON battles(status);

-- ============================================
-- STEP 4: Handle new user signup
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, username, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STEP 5: Grant permissions
-- ============================================
GRANT SELECT ON public.user_profiles TO authenticated;
GRANT INSERT, UPDATE ON public.user_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON map_posts TO authenticated;
GRANT SELECT, INSERT, UPDATE ON battles TO authenticated;

-- ============================================
-- DONE! Your database is now set up.
-- ============================================
