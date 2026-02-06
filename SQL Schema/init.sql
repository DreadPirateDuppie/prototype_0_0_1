-- ========================================================
-- CORE SCHEMA DEFINITIONS
-- ========================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ========================================================
-- CLEANUP LEGACY OBJECTS (Ghost Busting)
-- ========================================================
-- =========================
-- 1. CLEANUP LEGACY OBJECTS (Explicit Drops)
-- =========================
DROP INDEX IF EXISTS public.idx_conversation_participants_conversation_id;
DROP INDEX IF EXISTS public.follows_follower_following_idx;
DROP INDEX IF EXISTS public.idx_follows_follower_following;
DROP INDEX IF EXISTS public.map_posts_tags_idx;
DROP INDEX IF EXISTS public.notifications_user_id_idx;
DROP INDEX IF EXISTS public.saved_posts_user_id_idx;

DROP POLICY IF EXISTS "Battle tricks access" ON public.battle_tricks;
DROP POLICY IF EXISTS "User scores access" ON public.user_scores;
DROP POLICY IF EXISTS "Map posts access" ON public.map_posts;
DROP POLICY IF EXISTS "Follows access" ON public.follows;



-- ========================================================
-- SCHEMA RESILIENCE (Healing for existing DBs)
-- ========================================================

-- Resilience checks moved to initial CREATE TABLE blocks


-- 1. user_profiles
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    bio TEXT,
    avatar_url TEXT,
    email TEXT,
    is_admin BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    banned_at TIMESTAMP WITH TIME ZONE,
    can_post BOOLEAN DEFAULT TRUE,
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    points INTEGER DEFAULT 1000,
    is_premium BOOLEAN DEFAULT FALSE,
    location_sharing_mode TEXT DEFAULT 'off' CHECK (location_sharing_mode IN ('off', 'public', 'friends')),
    location_blacklist TEXT[] DEFAULT '{}',
    current_latitude DOUBLE PRECISION,
    current_longitude DOUBLE PRECISION,
    location_updated_at TIMESTAMP WITH TIME ZONE,
    is_private BOOLEAN DEFAULT FALSE,
    is_sponsorable BOOLEAN DEFAULT FALSE,
    age INTEGER CHECK (age > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_username ON public.user_profiles(username);
CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name ON public.user_profiles(display_name);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_admin ON public.user_profiles(is_admin);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_verified ON public.user_profiles(is_verified);
CREATE INDEX IF NOT EXISTS idx_user_profiles_location_sharing ON public.user_profiles(location_sharing_mode) WHERE location_sharing_mode != 'off';

-- 2. map_posts
CREATE TABLE IF NOT EXISTS public.map_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_email TEXT,
    user_name TEXT,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'Other',
    tags TEXT[] DEFAULT '{}',
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    photo_urls TEXT[] DEFAULT '{}',
    photo_url TEXT, -- Legacy support
    video_url TEXT,
    upvotes INTEGER DEFAULT 0,
    downvotes INTEGER DEFAULT 0,
    vote_score INTEGER DEFAULT 0,
    mvp_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    mvp_score INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    popularity_rating DOUBLE PRECISION DEFAULT 0.0,
    security_rating DOUBLE PRECISION DEFAULT 0.0,
    quality_rating DOUBLE PRECISION DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_map_posts_user_id ON public.map_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_map_posts_location ON public.map_posts(latitude, longitude);
-- Removed idx_map_posts_category as it was unused (idx_scan = 0)

CREATE INDEX IF NOT EXISTS idx_map_posts_is_verified ON public.map_posts(is_verified);
CREATE INDEX IF NOT EXISTS idx_map_posts_created_at_desc ON public.map_posts(created_at DESC);

-- 3. spot_videos
CREATE TABLE IF NOT EXISTS public.spot_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    thumbnail_url TEXT,
    platform TEXT, -- 'youtube', 'vimeo', 'instagram', 'direct'
    skater_name TEXT,
    trick_name TEXT,
    trick_name_ext TEXT,
    description TEXT,
    submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    is_own_clip BOOLEAN DEFAULT TRUE,
    stance TEXT DEFAULT 'regular',
    difficulty_multiplier DECIMAL DEFAULT 1.0,
    upvotes INTEGER DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_spot_videos_spot_id ON public.spot_videos(spot_id);
CREATE INDEX IF NOT EXISTS idx_spot_videos_submitted_by ON public.spot_videos(submitted_by);
CREATE INDEX IF NOT EXISTS idx_spot_videos_approved_by ON public.spot_videos(approved_by);
CREATE INDEX IF NOT EXISTS idx_spot_videos_status ON public.spot_videos(status);
CREATE INDEX IF NOT EXISTS idx_spot_videos_created_at ON public.spot_videos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_spot_videos_tags ON spot_videos USING GIN (tags);

-- 4. battles
CREATE TABLE IF NOT EXISTS public.battles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    player1_id UUID REFERENCES auth.users(id) NOT NULL,
    player2_id UUID REFERENCES auth.users(id) NOT NULL,
    game_mode TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'active', 'completed', 'cancelled'
    winner_id UUID REFERENCES auth.users(id),
    current_turn_player_id UUID REFERENCES auth.users(id),

    -- Trick Info
    trick_name TEXT,
    setter_id UUID REFERENCES auth.users(id),
    attempter_id UUID REFERENCES auth.users(id),
    setter_vote TEXT CHECK (setter_vote IN ('landed', 'missed')),
    attempter_vote TEXT CHECK (attempter_vote IN ('landed', 'missed')),

    -- Game State
    custom_letters TEXT,
    player1_letters TEXT DEFAULT '',
    player2_letters TEXT DEFAULT '',

    -- Media
    set_trick_video_url TEXT,
    attempt_video_url TEXT,

    -- RPS & Betting
    player1_rps_move TEXT CHECK (player1_rps_move IN ('rock', 'paper', 'scissors')),
    player2_rps_move TEXT CHECK (player2_rps_move IN ('rock', 'paper', 'scissors')),
    wager_amount INTEGER DEFAULT 0,
    bet_amount INTEGER DEFAULT 0,
    bet_accepted BOOLEAN DEFAULT FALSE,

    -- Metadata
    is_quickfire BOOLEAN DEFAULT FALSE,
    verification_status TEXT DEFAULT 'pending',
    turn_deadline TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_battles_player1_id ON battles(player1_id);
CREATE INDEX IF NOT EXISTS idx_battles_player2_id ON battles(player2_id);
CREATE INDEX IF NOT EXISTS idx_battles_current_turn_player_id ON battles(current_turn_player_id);
CREATE INDEX IF NOT EXISTS idx_battles_winner_id ON battles(winner_id);
CREATE INDEX IF NOT EXISTS idx_battles_status ON battles(status);
CREATE INDEX IF NOT EXISTS idx_battles_created_at ON battles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_battles_setter_id ON battles(setter_id);
CREATE INDEX IF NOT EXISTS idx_battles_attempter_id ON battles(attempter_id);


-- 5. user_scores
CREATE TABLE IF NOT EXISTS public.user_scores (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    map_score NUMERIC DEFAULT 0,
    player_score NUMERIC DEFAULT 0,
    ranking_score NUMERIC DEFAULT 500,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5b. user_wallets
CREATE TABLE IF NOT EXISTS public.user_wallets (
    user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
    balance NUMERIC DEFAULT 1000 NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5c. point_transactions
CREATE TABLE IF NOT EXISTS public.point_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    amount NUMERIC NOT NULL,
    transaction_type TEXT NOT NULL, -- e.g., 'bet_won', 'bet_placed', 'daily_login'
    reference_id TEXT, -- e.g., battle_id
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. matchmaking_queue
CREATE TABLE IF NOT EXISTS public.matchmaking_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_mode TEXT NOT NULL DEFAULT 'skate',
  is_quickfire BOOLEAN NOT NULL DEFAULT true,
  bet_amount INTEGER NOT NULL DEFAULT 0,
  ranking_score DOUBLE PRECISION NOT NULL DEFAULT 500,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'waiting', -- 'waiting', 'matched', 'cancelled'
  matched_with UUID REFERENCES auth.users(id),
  battle_id UUID REFERENCES public.battles(id),
  UNIQUE(user_id)
);

-- 7. skate_lobbies
CREATE TABLE IF NOT EXISTS public.skate_lobbies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    host_id UUID REFERENCES auth.users(id) NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'completed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. skate_lobby_players
CREATE TABLE IF NOT EXISTS public.skate_lobby_players (
    lobby_id UUID REFERENCES public.skate_lobbies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    letters TEXT DEFAULT '',
    is_host BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (lobby_id, user_id)
);

-- 9. skate_lobby_events
CREATE TABLE IF NOT EXISTS public.skate_lobby_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lobby_id UUID REFERENCES public.skate_lobbies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('set', 'miss', 'land', 'chat', 'join', 'leave')),
    data TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================================
-- MIGRATIONS
-- ========================================================



-- 12. ghost_lines
CREATE TABLE IF NOT EXISTS public.ghost_lines (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    spot_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    path_points JSONB NOT NULL,
    trick_markers JSONB DEFAULT '[]',
    duration_seconds INTEGER,
    distance_meters FLOAT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ghost_lines_creator_id ON public.ghost_lines(creator_id);
CREATE INDEX IF NOT EXISTS idx_ghost_lines_spot_id ON public.ghost_lines(spot_id);

-- 13. trick_definitions
CREATE TABLE IF NOT EXISTS public.trick_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  category TEXT NOT NULL,
  difficulty_multiplier DECIMAL DEFAULT 1.0,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trick_definitions_slug ON trick_definitions(slug);

-- 14. trick_aliases
CREATE TABLE IF NOT EXISTS public.trick_aliases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trick_id UUID REFERENCES public.trick_definitions(id) ON DELETE CASCADE,
  alias TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trick_aliases_trick_id ON trick_aliases(trick_id);

-- 15. battle_tricks
CREATE TABLE IF NOT EXISTS public.battle_tricks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    battle_id UUID REFERENCES public.battles(id) ON DELETE CASCADE NOT NULL,
    setter_id UUID REFERENCES auth.users(id) NOT NULL,
    attempter_id UUID REFERENCES auth.users(id) NOT NULL,
    trick_name TEXT NOT NULL,
    set_trick_video_url TEXT NOT NULL,
    attempt_video_url TEXT NOT NULL,
    outcome TEXT NOT NULL CHECK (outcome IN ('landed', 'missed')),
    letters_given TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_battle_tricks_battle_id ON public.battle_tricks(battle_id);
CREATE INDEX IF NOT EXISTS idx_battle_tricks_setter_id ON public.battle_tricks(setter_id);
CREATE INDEX IF NOT EXISTS idx_battle_tricks_attempter_id ON public.battle_tricks(attempter_id);

-- 16. trick_nodes
CREATE TABLE IF NOT EXISTS public.trick_nodes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    difficulty INTEGER DEFAULT 1,
    category TEXT NOT NULL,
    parent_ids UUID[] DEFAULT '{}',
    points_value INTEGER DEFAULT 100,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 17. user_trick_progress
CREATE TABLE IF NOT EXISTS public.user_trick_progress (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trick_id UUID NOT NULL REFERENCES public.trick_nodes(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'locked',
    video_proof_url TEXT,
    learned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, trick_id)
);

CREATE INDEX IF NOT EXISTS idx_user_trick_progress_user_id ON public.user_trick_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_trick_progress_trick_id ON public.user_trick_progress(trick_id);

-- 18. shops
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    website_url TEXT,
    location_lat FLOAT,
    location_lng FLOAT,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shops_owner_id ON public.shops(owner_id);

-- 19. sponsorship_offers
CREATE TABLE IF NOT EXISTS public.sponsorship_offers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    terms TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sponsorship_offers_user_id ON public.sponsorship_offers(user_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_offers_shop_id ON public.sponsorship_offers(shop_id);

-- 20. post_ratings
CREATE TABLE IF NOT EXISTS public.post_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  popularity_rating DOUBLE PRECISION NOT NULL,
  security_rating DOUBLE PRECISION NOT NULL,
  quality_rating DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);


CREATE INDEX IF NOT EXISTS idx_post_ratings_user_id ON public.post_ratings(user_id);

-- 21. app_settings
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 22. donations (Moved to top)
CREATE TABLE IF NOT EXISTS public.donations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    payment_id TEXT UNIQUE,
    order_id TEXT UNIQUE,
    status TEXT NOT NULL DEFAULT 'waiting',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 23. error_logs (Moved to top)
CREATE TABLE IF NOT EXISTS public.error_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    error_message TEXT NOT NULL,
    error_stack TEXT,
    severity TEXT DEFAULT 'error',
    context JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 24. user_feedback (Moved to top)
CREATE TABLE IF NOT EXISTS public.user_feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    feedback_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved'))
);

-- 25. follows (Moved to top)
CREATE TABLE IF NOT EXISTS public.follows (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(follower_id, following_id)
);



-- Redundant table definitions removed. Core definitions are at the top of the script.


-- 26. conversations
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type VARCHAR(20) NOT NULL CHECK (type IN ('direct', 'group')),
  name VARCHAR(255),
  description TEXT,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_archived BOOLEAN DEFAULT FALSE,
  avatar_url TEXT
);

-- 27. conversation_participants
CREATE TABLE IF NOT EXISTS public.conversation_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member')),
  last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_pinned BOOLEAN DEFAULT FALSE,
  is_muted BOOLEAN DEFAULT FALSE,
  UNIQUE(conversation_id, user_id)
);


CREATE INDEX IF NOT EXISTS idx_conversation_participants_conv_id ON public.conversation_participants(conversation_id);

-- 28. messages
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  content TEXT NOT NULL,
  message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'system')),
  media_url TEXT,
  media_name TEXT,
  media_size INTEGER,
  reply_to_id UUID REFERENCES public.messages(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_deleted BOOLEAN DEFAULT FALSE,
  is_edited BOOLEAN DEFAULT FALSE,
  read_by JSONB DEFAULT '[]'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);

-- 29. notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);



-- 30. daily_streaks
CREATE TABLE IF NOT EXISTS public.daily_streaks (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0 NOT NULL,
    last_login_date DATE,
    longest_streak INTEGER DEFAULT 0 NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 31. saved_posts
CREATE TABLE IF NOT EXISTS public.saved_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, post_id)
);
CREATE INDEX IF NOT EXISTS idx_saved_posts_user_id ON public.saved_posts(user_id);



-- 32. video_upvotes
CREATE TABLE IF NOT EXISTS public.video_upvotes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id UUID NOT NULL REFERENCES public.spot_videos(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type INTEGER NOT NULL CHECK (vote_type IN (1, -1)),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(video_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_video_upvotes_video_id ON public.video_upvotes(video_id);

-- 33. post_votes
CREATE TABLE IF NOT EXISTS public.post_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type INTEGER NOT NULL CHECK (vote_type IN (-1, 1)),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_votes_post_id ON public.post_votes(post_id);

-- 34. xp_history
CREATE TABLE IF NOT EXISTS public.xp_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    score_type TEXT NOT NULL CHECK (score_type IN ('map', 'player', 'ranking')),
    amount NUMERIC NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_xp_history_user_id ON public.xp_history(user_id);

-- 35. post_reports
CREATE TABLE IF NOT EXISTS public.post_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES public.map_posts(id) ON DELETE CASCADE NOT NULL,
    reporter_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'ignored')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_post_reports_post_id ON public.post_reports(post_id);
-- Migration: advanced_analytics
-- Description: Adds sophisticated analytics functions for Admin Dashboard (Retention, Health, Risk, TTV)

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- TTV, Health, etc.
CREATE OR REPLACE FUNCTION get_cohort_retention(months_back int DEFAULT 12)
RETURNS TABLE (cohort_month date, month_0 float, month_1 float, month_2 float, month_3 float, month_4 float, month_5 float, month_6 float, cohort_size bigint) AS $$
BEGIN
    RETURN QUERY
    WITH cohorts AS (
        SELECT date_trunc('month', created_at)::date as cohort_date, id as user_id
        FROM public.user_profiles
        WHERE created_at >= date_trunc('month', current_date - (months_back || ' months')::interval)
    ),
    cohort_sizes AS (SELECT cohort_date, count(*) as size FROM cohorts GROUP BY cohort_date),
    user_activities AS (
        SELECT c.user_id, c.cohort_date, floor(extract(epoch from (p.created_at - c.cohort_date::timestamp)) / 2592000)::int as month_diff
        FROM cohorts c
        JOIN public.map_posts p ON p.user_id = c.user_id
        WHERE p.created_at >= c.cohort_date::timestamp
    ),
    retention_counts AS (
        SELECT
            cohort_date,
            count(DISTINCT CASE WHEN month_diff = 0 THEN user_id END) as m0,
            count(DISTINCT CASE WHEN month_diff = 1 THEN user_id END) as m1,
            count(DISTINCT CASE WHEN month_diff = 2 THEN user_id END) as m2,
            count(DISTINCT CASE WHEN month_diff = 3 THEN user_id END) as m3,
            count(DISTINCT CASE WHEN month_diff = 4 THEN user_id END) as m4,
            count(DISTINCT CASE WHEN month_diff = 5 THEN user_id END) as m5,
            count(DISTINCT CASE WHEN month_diff = 6 THEN user_id END) as m6
        FROM user_activities
        GROUP BY cohort_date
    )
    SELECT cs.cohort_date, COALESCE(rc.m0::float / NULLIF(cs.size, 0), 0) * 100, COALESCE(rc.m1::float / NULLIF(cs.size, 0), 0) * 100, COALESCE(rc.m2::float / NULLIF(cs.size, 0), 0) * 100, COALESCE(rc.m3::float / NULLIF(cs.size, 0), 0) * 100, COALESCE(rc.m4::float / NULLIF(cs.size, 0), 0) * 100, COALESCE(rc.m5::float / NULLIF(cs.size, 0), 0) * 100, COALESCE(rc.m6::float / NULLIF(cs.size, 0), 0) * 100, cs.size
    FROM cohort_sizes cs
    LEFT JOIN retention_counts rc ON cs.cohort_date = rc.cohort_date
    ORDER BY cs.cohort_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;



CREATE OR REPLACE FUNCTION get_customer_health_scores(limit_cnt int DEFAULT 50)
RETURNS TABLE (user_id uuid, username text, avatar_url text, health_score float, last_active_days int) AS $$
BEGIN
    RETURN QUERY
    WITH metrics AS (
        SELECT u.id, u.username, u.avatar_url, COALESCE(extract(day from now() - max(p.created_at)), 60) as days_since_post, count(p.id) filter (where p.created_at > now() - interval '30 days') as posts_last_30d, COALESCE(sum(w.balance), 0) as wallet_balance
        FROM public.user_profiles u
        LEFT JOIN public.map_posts p ON p.user_id = u.id
        LEFT JOIN public.user_wallets w ON w.user_id = u.id
        GROUP BY u.id
    )
    SELECT id, metrics.username, metrics.avatar_url, (CASE WHEN days_since_post > 30 THEN 0 ELSE (30 - days_since_post) / 30.0 * 40 END) + LEAST(posts_last_30d * 2, 40) + LEAST(wallet_balance / 50.0, 20) as score, days_since_post::int
    FROM metrics ORDER BY score DESC LIMIT limit_cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


CREATE OR REPLACE FUNCTION get_at_risk_users(limit_cnt int DEFAULT 20)
RETURNS TABLE (user_id uuid, username text, activity_last_week bigint, activity_this_week bigint, drop_percentage float) AS $$
BEGIN
    RETURN QUERY
    WITH weekly_activity AS (
        SELECT u.id, u.username, count(p.id) filter (where p.created_at >= now() - interval '7 days') as this_week, count(p.id) filter (where p.created_at >= now() - interval '14 days' AND p.created_at < now() - interval '7 days') as last_week
        FROM public.user_profiles u JOIN public.map_posts p ON p.user_id = u.id
        WHERE p.created_at >= now() - interval '14 days' GROUP BY u.id
    )
    SELECT id, weekly_activity.username, last_week, this_week, CASE WHEN last_week > 0 THEN ((last_week - this_week)::float / last_week::float) * 100 ELSE 0 END as drop_pct
    FROM weekly_activity WHERE last_week > 2 AND this_week < (last_week * 0.5) ORDER BY drop_pct DESC LIMIT limit_cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


CREATE OR REPLACE FUNCTION get_time_to_value_stats() RETURNS float AS $$
DECLARE avg_hours float;
BEGIN
    SELECT AVG(extract(epoch FROM (first_post_time - user_created_time)) / 3600.0) INTO avg_hours
    FROM (SELECT u.created_at as user_created_time, min(p.created_at) as first_post_time FROM public.user_profiles u JOIN public.map_posts p ON p.user_id = u.id GROUP BY u.id) t;
    RETURN COALESCE(avg_hours, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, username, display_name, location_sharing_mode, location_updated_at)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)), COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1)), 'friends', NOW())
    ON CONFLICT (id) DO UPDATE SET username = EXCLUDED.username WHERE user_profiles.username IS NULL;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION award_points_atomic(p_user_id UUID, p_amount NUMERIC, p_transaction_type TEXT, p_reference_id TEXT DEFAULT NULL, p_description TEXT DEFAULT NULL) RETURNS NUMERIC AS $$
DECLARE v_new_balance NUMERIC;
BEGIN
    INSERT INTO public.user_wallets (user_id, balance, updated_at) VALUES (p_user_id, p_amount, NOW())
    ON CONFLICT (user_id) DO UPDATE SET balance = user_wallets.balance + p_amount, updated_at = NOW()
    RETURNING balance INTO v_new_balance;
    INSERT INTO public.point_transactions (user_id, amount, transaction_type, reference_id, description, created_at)
    VALUES (p_user_id, p_amount, p_transaction_type, p_reference_id, p_description, NOW());
    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION search_tricks(search_query TEXT) RETURNS SETOF trick_definitions AS $$
BEGIN
  RETURN QUERY SELECT DISTINCT td.* FROM trick_definitions td LEFT JOIN trick_aliases ta ON td.id = ta.trick_id
  WHERE td.display_name ILIKE '%' || search_query || '%' OR td.slug ILIKE '%' || search_query || '%' OR ta.alias ILIKE '%' || search_query || '%'
  ORDER BY td.difficulty_multiplier DESC LIMIT 10;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_battle_leaderboard(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (user_id UUID, username TEXT, display_name TEXT, avatar_url TEXT, player_score DOUBLE PRECISION, ranking_score DOUBLE PRECISION, wins INTEGER, losses INTEGER, total_battles INTEGER, win_percentage DOUBLE PRECISION) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT up.id as user_id, up.username, up.display_name, up.avatar_url, COALESCE(us.player_score, 0)::DOUBLE PRECISION as player_score, COALESCE(us.ranking_score, 0)::DOUBLE PRECISION as ranking_score, COALESCE((SELECT COUNT(*)::INTEGER FROM battles b WHERE b.winner_id = up.id AND b.status = 'completed'), 0) as wins, COALESCE((SELECT COUNT(*)::INTEGER FROM battles b WHERE (b.player1_id = up.id OR b.player2_id = up.id) AND b.winner_id != up.id AND b.status = 'completed'), 0) as losses
        FROM user_profiles up LEFT JOIN user_scores us ON up.id = us.user_id
    )
    SELECT s.*, (s.wins + s.losses) as total_battles, CASE WHEN (s.wins + s.losses) > 0 THEN (s.wins::DOUBLE PRECISION / (s.wins + s.losses) * 100) ELSE 0 END as win_percentage
    FROM stats s ORDER BY player_score DESC LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION calculate_spot_mvp() RETURNS TRIGGER AS $$
DECLARE target_spot_id UUID; new_mvp_id UUID; new_mvp_score INTEGER;
BEGIN
    IF (TG_OP = 'DELETE') THEN target_spot_id := OLD.spot_id; ELSE target_spot_id := NEW.spot_id; END IF;
    SELECT submitted_by, SUM((10 * COALESCE(difficulty_multiplier, 1.0)) * (CASE WHEN stance = 'switch' THEN 1.7 WHEN stance = 'nollie' THEN 1.4 WHEN stance = 'fakie' THEN 1.2 ELSE 1.0 END) * (upvotes + 1)) as total_weighted_score
    INTO new_mvp_id, new_mvp_score FROM spot_videos WHERE spot_id = target_spot_id AND status = 'approved' AND is_own_clip = TRUE GROUP BY submitted_by ORDER BY total_weighted_score DESC LIMIT 1;
    IF new_mvp_id IS NULL THEN new_mvp_score := 0; END IF;
    UPDATE map_posts SET mvp_user_id = new_mvp_id, mvp_score = COALESCE(new_mvp_score, 0) WHERE id = target_spot_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION update_post_ratings() RETURNS TRIGGER AS $$
DECLARE avg_pop DOUBLE PRECISION; avg_sec DOUBLE PRECISION; avg_qual DOUBLE PRECISION;
BEGIN
    SELECT COALESCE(AVG(popularity_rating), 0), COALESCE(AVG(security_rating), 0), COALESCE(AVG(quality_rating), 0)
    INTO avg_pop, avg_sec, avg_qual FROM post_ratings WHERE post_id = COALESCE(NEW.post_id, OLD.post_id);
    UPDATE map_posts SET popularity_rating = avg_pop, security_rating = avg_sec, quality_rating = avg_qual WHERE id = COALESCE(NEW.post_id, OLD.post_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION update_conversation_last_message() RETURNS TRIGGER AS $$
BEGIN UPDATE conversations SET last_message_at = NEW.created_at WHERE id = NEW.conversation_id; RETURN NEW; END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


CREATE OR REPLACE FUNCTION get_user_growth_stats(days_ago int DEFAULT 30)
RETURNS TABLE (day date, count bigint) AS $$
BEGIN
    RETURN QUERY SELECT date_series.day::date, COUNT(u.created_at)::bigint FROM generate_series(CURRENT_DATE - (days_ago - 1) * INTERVAL '1 day', CURRENT_DATE, '1 day') AS date_series(day)
    LEFT JOIN public.user_profiles u ON DATE(u.created_at) = date_series.day GROUP BY date_series.day ORDER BY date_series.day;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_daily_post_stats(days_ago int DEFAULT 30)
RETURNS TABLE (day date, count bigint) AS $$
BEGIN
    RETURN QUERY SELECT date_series.day::date, COUNT(p.created_at)::bigint FROM generate_series(CURRENT_DATE - (days_ago - 1) * INTERVAL '1 day', CURRENT_DATE, '1 day') AS date_series(day)
    LEFT JOIN public.map_posts p ON DATE(p.created_at) = date_series.day GROUP BY date_series.day ORDER BY date_series.day;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- Migration: analytics_xp_fix
-- Description: Automates XP (map_score) updates via triggers and broadens activity definitions for analytics.

-- 1. XP functions and triggers (Consolidated)
CREATE OR REPLACE FUNCTION update_user_map_xp()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_xp_change NUMERIC;
BEGIN
    IF (TG_TABLE_NAME = 'map_posts') THEN
        IF (TG_OP = 'INSERT') THEN
            v_user_id := NEW.user_id;
            v_xp_change := 100;
        ELSIF (TG_OP = 'DELETE') THEN
            v_user_id := OLD.user_id;
            v_xp_change := -100;
        END IF;
    ELSIF (TG_TABLE_NAME = 'post_votes') THEN
        SELECT user_id INTO v_user_id FROM public.map_posts WHERE id = COALESCE(NEW.post_id, OLD.post_id);
        IF (TG_OP = 'INSERT') THEN
            v_xp_change := NEW.vote_type;
        ELSIF (TG_OP = 'DELETE') THEN
            v_xp_change := -OLD.vote_type;
        ELSIF (TG_OP = 'UPDATE') THEN
            v_xp_change := NEW.vote_type - OLD.vote_type;
        END IF;
    END IF;

    IF v_user_id IS NOT NULL AND v_xp_change IS NOT NULL AND v_xp_change != 0 THEN
        INSERT INTO public.user_scores (user_id, map_score)
        VALUES (v_user_id, GREATEST(v_xp_change, 0))
        ON CONFLICT (user_id) DO UPDATE
        SET map_score = GREATEST(public.user_scores.map_score + v_xp_change, 0);

        INSERT INTO public.xp_history (user_id, score_type, amount, reason)
        VALUES (v_user_id, 'map', v_xp_change, 'Real-time update: ' || TG_TABLE_NAME || ' ' || TG_OP);
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- 2. Trigger to sync post_votes to map_posts summary columns
CREATE OR REPLACE FUNCTION sync_post_vote_totals()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.map_posts
        SET
            upvotes = upvotes + (CASE WHEN NEW.vote_type = 1 THEN 1 ELSE 0 END),
            downvotes = downvotes + (CASE WHEN NEW.vote_type = -1 THEN 1 ELSE 0 END),
            vote_score = vote_score + NEW.vote_type
        WHERE id = NEW.post_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.map_posts
        SET
            upvotes = upvotes - (CASE WHEN OLD.vote_type = 1 THEN 1 ELSE 0 END),
            downvotes = downvotes - (CASE WHEN OLD.vote_type = -1 THEN 1 ELSE 0 END),
            vote_score = vote_score - OLD.vote_type
        WHERE id = OLD.post_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE public.map_posts
        SET
            upvotes = upvotes - (CASE WHEN OLD.vote_type = 1 THEN 1 ELSE 0 END) + (CASE WHEN NEW.vote_type = 1 THEN 1 ELSE 0 END),
            downvotes = downvotes - (CASE WHEN OLD.vote_type = -1 THEN 1 ELSE 0 END) + (CASE WHEN NEW.vote_type = -1 THEN 1 ELSE 0 END),
            vote_score = vote_score - OLD.vote_type + NEW.vote_type
        WHERE id = NEW.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS tr_sync_post_vote_totals ON public.post_votes;


-- Update Stickiness Ratio to use true activity
CREATE OR REPLACE FUNCTION get_stickiness_ratio()
RETURNS TABLE (
    dau bigint,
    mau bigint,
    ratio float
) AS $$
DECLARE
    daily_active bigint;
    monthly_active bigint;
BEGIN
    -- DAU: Active in last 24h (posts, battles, votes, or login)
    SELECT count(DISTINCT user_id) INTO daily_active
    FROM (
        SELECT user_id FROM public.map_posts WHERE created_at >= (now() - interval '24 hours')
        UNION
        SELECT player1_id FROM public.battles WHERE created_at >= (now() - interval '24 hours')
        UNION
        SELECT player2_id FROM public.battles WHERE created_at >= (now() - interval '24 hours')
        UNION
        SELECT user_id FROM public.post_votes WHERE updated_at >= (now() - interval '24 hours')
        UNION
        SELECT id FROM public.user_profiles WHERE last_active_at >= (now() - interval '24 hours')
    ) activity;

    -- MAU: Active in last 30d
    SELECT count(DISTINCT user_id) INTO monthly_active
    FROM (
        SELECT user_id FROM public.map_posts WHERE created_at >= (now() - interval '30 days')
        UNION
        SELECT player1_id FROM public.battles WHERE created_at >= (now() - interval '30 days')
        UNION
        SELECT player2_id FROM public.battles WHERE created_at >= (now() - interval '30 days')
        UNION
        SELECT user_id FROM public.post_votes WHERE updated_at >= (now() - interval '30 days')
        UNION
        SELECT id FROM public.user_profiles WHERE last_active_at >= (now() - interval '30 days')
    ) activity;

    RETURN QUERY SELECT
        daily_active,
        monthly_active,
        CASE
            WHEN monthly_active > 0 THEN (daily_active::float / monthly_active::float) * 100
            ELSE 0.0
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Messaging Functions
CREATE OR REPLACE FUNCTION mark_all_messages_as_read(p_conversation_id UUID, p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE conversation_participants SET last_read_at = NOW()
    WHERE conversation_id = p_conversation_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_total_unread_count(p_user_id UUID)
RETURNS BIGINT AS $$
DECLARE total_unread BIGINT;
BEGIN
    SELECT COUNT(*) INTO total_unread
    FROM messages m
    JOIN conversation_participants cp ON m.conversation_id = cp.conversation_id
    WHERE cp.user_id = p_user_id AND m.created_at > cp.last_read_at AND m.sender_id != p_user_id;
    RETURN total_unread;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_or_create_direct_conversation(user1_id UUID, user2_id UUID)
RETURNS UUID AS $$
DECLARE
    conversation_id UUID;
    existing_conversation UUID;
BEGIN
    SELECT c.id INTO existing_conversation
    FROM conversations c
    JOIN conversation_participants p1 ON c.id = p1.conversation_id
    JOIN conversation_participants p2 ON c.id = p2.conversation_id
    WHERE c.type = 'direct' AND p1.user_id = user1_id AND p2.user_id = user2_id
    LIMIT 1;

    IF existing_conversation IS NOT NULL THEN RETURN existing_conversation; END IF;

    INSERT INTO conversations (type, created_by) VALUES ('direct', user1_id) RETURNING id INTO conversation_id;
    INSERT INTO conversation_participants (conversation_id, user_id, role) VALUES (conversation_id, user1_id, 'admin'), (conversation_id, user2_id, 'member');
    RETURN conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION get_user_conversations(user_uuid UUID)
RETURNS TABLE (
    id UUID, type VARCHAR(20), name VARCHAR(255), description TEXT, created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE, updated_at TIMESTAMP WITH TIME ZONE,
    last_message_at TIMESTAMP WITH TIME ZONE, is_archived BOOLEAN, avatar_url TEXT,
    participant_count BIGINT, last_message_preview TEXT, unread_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id, c.type, c.name, c.description, c.created_by, c.created_at, c.updated_at,
        c.last_message_at, c.is_archived, c.avatar_url,
        COUNT(DISTINCT cp2.user_id) as participant_count,
        (SELECT m.content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_preview,
        (SELECT COUNT(*) FROM messages m2 WHERE m2.conversation_id = c.id AND m2.created_at > cp.last_read_at AND m2.sender_id != user_uuid) as unread_count
    FROM conversations c
    JOIN conversation_participants cp ON c.id = cp.conversation_id
    JOIN conversation_participants cp2 ON c.id = cp2.conversation_id
    WHERE cp.user_id = user_uuid AND c.is_archived = FALSE
    GROUP BY c.id, cp.last_read_at
    ORDER BY c.last_message_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Update Functions
CREATE OR REPLACE FUNCTION public.handle_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE OR REPLACE FUNCTION update_video_upvotes() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE spot_videos SET upvotes = upvotes + NEW.vote_type WHERE id = NEW.video_id;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE spot_videos SET upvotes = upvotes + (NEW.vote_type - OLD.vote_type) WHERE id = NEW.video_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE spot_videos SET upvotes = upvotes - OLD.vote_type WHERE id = OLD.video_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Email Sync Functions
CREATE OR REPLACE FUNCTION public.handle_sync_user_email() RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.user_profiles SET email = NEW.email WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.handle_sync_user_email_on_insert() RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.user_profiles SET email = NEW.email WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Account Management
CREATE OR REPLACE FUNCTION delete_user_account() RETURNS void AS $$
BEGIN
    DELETE FROM auth.users WHERE id = (SELECT auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION delete_user_account TO authenticated;
-- =============================================================================
-- TRIGGERS

-- =============================================================================
-- TRIGGERS (Consolidated)
-- =============================================================================

-- Utility: Update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- 1. Updated at triggers
DROP TRIGGER IF EXISTS update_user_scores_updated_at ON public.user_scores;
CREATE TRIGGER update_user_scores_updated_at BEFORE UPDATE ON public.user_scores FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

DROP TRIGGER IF EXISTS update_conversations_updated_at ON conversations;
CREATE TRIGGER update_conversations_updated_at BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_messages_updated_at ON messages;
CREATE TRIGGER update_messages_updated_at BEFORE UPDATE ON messages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 2. Auth & Sync triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated AFTER UPDATE OF email ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_sync_user_email();

DROP TRIGGER IF EXISTS on_auth_user_created_sync_email ON auth.users;
CREATE TRIGGER on_auth_user_created_sync_email AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_sync_user_email_on_insert();

-- 3. Map & Content triggers
DROP TRIGGER IF EXISTS tr_sync_post_vote_totals ON public.post_votes;
CREATE TRIGGER tr_sync_post_vote_totals AFTER INSERT OR UPDATE OR DELETE ON public.post_votes FOR EACH ROW EXECUTE FUNCTION sync_post_vote_totals();

DROP TRIGGER IF EXISTS tr_update_xp_on_post ON public.map_posts;
CREATE TRIGGER tr_update_xp_on_post AFTER INSERT OR DELETE ON public.map_posts FOR EACH ROW EXECUTE FUNCTION update_user_map_xp();

DROP TRIGGER IF EXISTS tr_update_xp_on_vote ON public.post_votes;
CREATE TRIGGER tr_update_xp_on_vote AFTER INSERT OR UPDATE OR DELETE ON public.post_votes FOR EACH ROW EXECUTE FUNCTION update_user_map_xp();

DROP TRIGGER IF EXISTS trigger_update_spot_mvp ON public.spot_videos;
CREATE TRIGGER trigger_update_spot_mvp AFTER INSERT OR UPDATE OF upvotes, status OR DELETE ON public.spot_videos FOR EACH ROW EXECUTE FUNCTION calculate_spot_mvp();

DROP TRIGGER IF EXISTS update_post_ratings_trigger ON post_ratings;
CREATE TRIGGER update_post_ratings_trigger AFTER INSERT OR UPDATE OR DELETE ON post_ratings FOR EACH ROW EXECUTE FUNCTION update_post_ratings();

-- 4. Messaging triggers
DROP TRIGGER IF EXISTS update_conversation_last_message_trigger ON messages;
CREATE TRIGGER update_conversation_last_message_trigger AFTER INSERT ON messages FOR EACH ROW EXECUTE FUNCTION update_conversation_last_message();

-- 5. Video & Other triggers
DROP TRIGGER IF EXISTS video_upvotes_trigger ON video_upvotes;
CREATE TRIGGER video_upvotes_trigger AFTER INSERT OR UPDATE OR DELETE ON video_upvotes FOR EACH ROW EXECUTE FUNCTION update_video_upvotes();

DROP TRIGGER IF EXISTS on_donations_updated ON public.donations;
CREATE TRIGGER on_donations_updated BEFORE UPDATE ON public.donations FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- =============================================================================
-- =============================================================================
-- RLS POLICIES (Secure & Explicit)
-- =============================================================================

-- Ensure RLS is enabled for all tables
ALTER TABLE IF EXISTS public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.map_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.spot_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.battles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.battle_tricks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.daily_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.xp_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.post_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.post_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.video_upvotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.post_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.sponsorship_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.skate_lobbies ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.skate_lobby_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.skate_lobby_events ENABLE ROW LEVEL SECURITY;

-- 1. Lobbies Policies
DROP POLICY IF EXISTS "Lobby access" ON public.skate_lobbies;
DROP POLICY IF EXISTS "Lobby player access" ON public.skate_lobby_players;
DROP POLICY IF EXISTS "Lobby event access" ON public.skate_lobby_events;

DROP POLICY IF EXISTS "Skate lobbies select" ON public.skate_lobbies;
CREATE POLICY "Skate lobbies select" ON public.skate_lobbies FOR SELECT USING ((SELECT auth.uid()) IS NOT NULL);
DROP POLICY IF EXISTS "Skate lobbies insert" ON public.skate_lobbies;
CREATE POLICY "Skate lobbies insert" ON public.skate_lobbies FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND host_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Skate lobbies update" ON public.skate_lobbies;
CREATE POLICY "Skate lobbies update" ON public.skate_lobbies FOR UPDATE USING ((SELECT auth.uid()) = host_id) WITH CHECK ((SELECT auth.uid()) = host_id);
DROP POLICY IF EXISTS "Skate lobbies delete" ON public.skate_lobbies;
CREATE POLICY "Skate lobbies delete" ON public.skate_lobbies FOR DELETE USING ((SELECT auth.uid()) = host_id);

DROP POLICY IF EXISTS "Skate lobby players select" ON public.skate_lobby_players;
CREATE POLICY "Skate lobby players select" ON public.skate_lobby_players FOR SELECT USING ((SELECT auth.uid()) IS NOT NULL AND (lobby_id IS NOT NULL));
DROP POLICY IF EXISTS "Skate lobby players insert" ON public.skate_lobby_players;
CREATE POLICY "Skate lobby players insert" ON public.skate_lobby_players FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Skate lobby players update" ON public.skate_lobby_players;
CREATE POLICY "Skate lobby players update" ON public.skate_lobby_players FOR UPDATE USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Skate lobby players delete" ON public.skate_lobby_players;
CREATE POLICY "Skate lobby players delete" ON public.skate_lobby_players FOR DELETE USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Skate lobby events select" ON public.skate_lobby_events;
CREATE POLICY "Skate lobby events select" ON public.skate_lobby_events FOR SELECT USING ((SELECT auth.uid()) IS NOT NULL);
DROP POLICY IF EXISTS "Skate lobby events insert" ON public.skate_lobby_events;
CREATE POLICY "Skate lobby events insert" ON public.skate_lobby_events FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Skate lobby events update" ON public.skate_lobby_events;
CREATE POLICY "Skate lobby events update" ON public.skate_lobby_events FOR UPDATE USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Skate lobby events delete" ON public.skate_lobby_events;
CREATE POLICY "Skate lobby events delete" ON public.skate_lobby_events FOR DELETE USING (user_id = (SELECT auth.uid()));

-- 2. Post Votes Policies
DROP POLICY IF EXISTS "Anyone can view votes" ON public.post_votes;
DROP POLICY IF EXISTS "Users can manage own votes" ON public.post_votes;

DROP POLICY IF EXISTS "Post votes public select" ON public.post_votes;
CREATE POLICY "Post votes public select" ON public.post_votes FOR SELECT USING (true);
DROP POLICY IF EXISTS "Post votes insert by owner" ON public.post_votes;
CREATE POLICY "Post votes insert by owner" ON public.post_votes FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Post votes update by owner" ON public.post_votes;
CREATE POLICY "Post votes update by owner" ON public.post_votes FOR UPDATE USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Post votes delete by owner" ON public.post_votes;
CREATE POLICY "Post votes delete by owner" ON public.post_votes FOR DELETE USING (user_id = (SELECT auth.uid()));

-- 3. Video Upvotes Policies
DROP POLICY IF EXISTS "Anyone can view video upvotes" ON public.video_upvotes;
DROP POLICY IF EXISTS "Users can manage own video votes" ON public.video_upvotes;

DROP POLICY IF EXISTS "Video upvotes public select" ON public.video_upvotes;
CREATE POLICY "Video upvotes public select" ON public.video_upvotes FOR SELECT USING (true);
DROP POLICY IF EXISTS "Video upvotes insert by owner" ON public.video_upvotes;
CREATE POLICY "Video upvotes insert by owner" ON public.video_upvotes FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Video upvotes update by owner" ON public.video_upvotes;
CREATE POLICY "Video upvotes update by owner" ON public.video_upvotes FOR UPDATE USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Video upvotes delete by owner" ON public.video_upvotes;
CREATE POLICY "Video upvotes delete by owner" ON public.video_upvotes FOR DELETE USING (user_id = (SELECT auth.uid()));

-- 4. Post Ratings Policies
DROP POLICY IF EXISTS "Anyone can view ratings" ON public.post_ratings;
DROP POLICY IF EXISTS "Users can manage own ratings" ON public.post_ratings;

DROP POLICY IF EXISTS "Post ratings public select" ON public.post_ratings;
CREATE POLICY "Post ratings public select" ON public.post_ratings FOR SELECT USING (true);
DROP POLICY IF EXISTS "Post ratings insert by owner" ON public.post_ratings;
CREATE POLICY "Post ratings insert by owner" ON public.post_ratings FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Post ratings update by owner" ON public.post_ratings;
CREATE POLICY "Post ratings update by owner" ON public.post_ratings FOR UPDATE USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Post ratings delete by owner" ON public.post_ratings;
CREATE POLICY "Post ratings delete by owner" ON public.post_ratings FOR DELETE USING (user_id = (SELECT auth.uid()));

-- 5. Messaging Policies
DROP POLICY IF EXISTS "Users can view conversations they participate in" ON public.conversations;
DROP POLICY IF EXISTS "Users can create conversations" ON public.conversations;
DROP POLICY IF EXISTS "Messages select participants" ON public.messages;
CREATE POLICY "Messages select participants" ON public.messages FOR SELECT USING (EXISTS (SELECT 1 FROM public.conversation_participants cp WHERE cp.conversation_id = public.messages.conversation_id AND cp.user_id = (SELECT auth.uid())));

DROP POLICY IF EXISTS "Conversations select for participants" ON public.conversations;
CREATE POLICY "Conversations select for participants" ON public.conversations FOR SELECT USING (EXISTS (SELECT 1 FROM public.conversation_participants cp WHERE cp.conversation_id = public.conversations.id AND cp.user_id = (SELECT auth.uid())));
DROP POLICY IF EXISTS "Conversations insert by creator" ON public.conversations;
CREATE POLICY "Conversations insert by creator" ON public.conversations FOR INSERT WITH CHECK (created_by = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Messages modify own" ON public.messages;
CREATE POLICY "Messages modify own" ON public.messages FOR ALL USING (sender_id = (SELECT auth.uid()));

-- 6. Follows Policies
DROP POLICY IF EXISTS "Public follows access" ON public.follows;
DROP POLICY IF EXISTS "Users can manage own follows" ON public.follows;
DROP POLICY IF EXISTS "Users can create follows" ON public.follows;
DROP POLICY IF EXISTS "Users can delete own follows" ON public.follows;

DROP POLICY IF EXISTS "Follows public select" ON public.follows;
CREATE POLICY "Follows public select" ON public.follows FOR SELECT USING (true);
DROP POLICY IF EXISTS "Follows insert by follower" ON public.follows;
CREATE POLICY "Follows insert by follower" ON public.follows FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND follower_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS "Follows delete by follower" ON public.follows;
CREATE POLICY "Follows delete by follower" ON public.follows FOR DELETE USING (follower_id = (SELECT auth.uid()));

-- 7. User Profiles Policies
DROP POLICY IF EXISTS "Users can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "User profiles public select" ON public.user_profiles;
CREATE POLICY "User profiles public select" ON public.user_profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "User profiles update own" ON public.user_profiles;
CREATE POLICY "User profiles update own" ON public.user_profiles FOR UPDATE USING ((SELECT auth.uid()) = id) WITH CHECK ((SELECT auth.uid()) = id);
DROP POLICY IF EXISTS "User profiles insert own" ON public.user_profiles;
CREATE POLICY "User profiles insert own" ON public.user_profiles FOR INSERT WITH CHECK ((SELECT auth.uid()) = id);

-- 8. Map Posts Policies
DROP POLICY IF EXISTS "Map posts select public" ON public.map_posts;
CREATE POLICY "Map posts select public" ON public.map_posts FOR SELECT USING (true);
DROP POLICY IF EXISTS "Map posts modify own" ON public.map_posts;
CREATE POLICY "Map posts modify own" ON public.map_posts FOR ALL USING ((SELECT auth.uid()) = user_id);
-- Note: Replaced "Map posts insert by owner", "Map posts update by owner", "Map posts delete by owner" with a single "modify own" policy for performance.

-- 9. Battles & Battle Tricks Policies
DROP POLICY IF EXISTS "Battles select public" ON public.battles;
CREATE POLICY "Battles select public" ON public.battles FOR SELECT USING (true);
DROP POLICY IF EXISTS "Battles modify participant" ON public.battles;
CREATE POLICY "Battles modify participant" ON public.battles FOR ALL USING ((SELECT auth.uid()) IN (player1_id, player2_id));
-- Note: Simplified battles policies to one SELECT and one ALL for participants.

DROP POLICY IF EXISTS "Anyone can view battle tricks" ON public.battle_tricks;
DROP POLICY IF EXISTS "Authenticated users can add battle tricks" ON public.battle_tricks;

DROP POLICY IF EXISTS "Battle tricks public select" ON public.battle_tricks;
CREATE POLICY "Battle tricks public select" ON public.battle_tricks FOR SELECT USING (true);
DROP POLICY IF EXISTS "Battle tricks insert auth" ON public.battle_tricks;
CREATE POLICY "Battle tricks insert auth" ON public.battle_tricks FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND (setter_id = (SELECT auth.uid()) OR attempter_id = (SELECT auth.uid())));

-- 10. User Scores & Points Policies
DROP POLICY IF EXISTS "User scores access" ON public.user_scores;

DROP POLICY IF EXISTS "User scores select owner or admin" ON public.user_scores;
CREATE POLICY "User scores select owner or admin" ON public.user_scores FOR SELECT USING ((SELECT auth.uid()) = user_id OR EXISTS (SELECT 1 FROM public.user_profiles up WHERE up.id = (SELECT auth.uid()) AND up.is_admin = TRUE));
DROP POLICY IF EXISTS "User scores write owner" ON public.user_scores;
CREATE POLICY "User scores write owner" ON public.user_scores FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS "User scores update owner" ON public.user_scores;
CREATE POLICY "User scores update owner" ON public.user_scores FOR UPDATE USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can view own transactions" ON public.point_transactions;

DROP POLICY IF EXISTS "Point transactions select owner" ON public.point_transactions;
CREATE POLICY "Point transactions select owner" ON public.point_transactions FOR SELECT USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS "Point transactions insert owner" ON public.point_transactions;
CREATE POLICY "Point transactions insert owner" ON public.point_transactions FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

-- 11. App Settings & Logs Policies
DROP POLICY IF EXISTS "Admins can manage app_settings" ON public.app_settings;

DROP POLICY IF EXISTS "App settings admin all" ON public.app_settings;
CREATE POLICY "App settings admin all" ON public.app_settings FOR ALL USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true));

DROP POLICY IF EXISTS "Admins can view logs" ON public.error_logs;
DROP POLICY IF EXISTS "Authenticated users can log errors" ON public.error_logs;

DROP POLICY IF EXISTS "Error logs select admin" ON public.error_logs;
CREATE POLICY "Error logs select admin" ON public.error_logs FOR SELECT USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true));
DROP POLICY IF EXISTS "Error logs insert auth" ON public.error_logs;
CREATE POLICY "Error logs insert auth" ON public.error_logs FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Admins can view feedback" ON public.user_feedback;
DROP POLICY IF EXISTS "Users can insert feedback" ON public.user_feedback;

DROP POLICY IF EXISTS "User feedback select admin" ON public.user_feedback;
CREATE POLICY "User feedback select admin" ON public.user_feedback FOR SELECT USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true));
DROP POLICY IF EXISTS "User feedback insert auth" ON public.user_feedback;
CREATE POLICY "User feedback insert auth" ON public.user_feedback FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

-- 11b. Donations Policies
DROP POLICY IF EXISTS "Donations select own" ON public.donations;
CREATE POLICY "Donations select own" ON public.donations FOR SELECT USING ((SELECT auth.uid()) = user_id);
DROP POLICY IF EXISTS "Donations select admin" ON public.donations;
CREATE POLICY "Donations select admin" ON public.donations FOR SELECT USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true));

-- 12. Shops & Sponsorship Policies
DROP POLICY IF EXISTS "Public read access for shops" ON public.shops;
DROP POLICY IF EXISTS "Shop owners can update shops" ON public.shops;

DROP POLICY IF EXISTS "Shops public select" ON public.shops;
CREATE POLICY "Shops public select" ON public.shops FOR SELECT USING (true);
DROP POLICY IF EXISTS "Shops update owner" ON public.shops;
CREATE POLICY "Shops update owner" ON public.shops FOR UPDATE USING ((SELECT auth.uid()) = owner_id) WITH CHECK ((SELECT auth.uid()) = owner_id);

DROP POLICY IF EXISTS "Sponsorship access" ON public.sponsorship_offers;

DROP POLICY IF EXISTS "Sponsorship offers select/modify" ON public.sponsorship_offers;
CREATE POLICY "Sponsorship offers select/modify" ON public.sponsorship_offers FOR ALL USING ((SELECT auth.uid()) = user_id OR EXISTS (SELECT 1 FROM public.shops s WHERE s.id = public.sponsorship_offers.shop_id AND s.owner_id = (SELECT auth.uid())));


-- =============================================================================
-- FINAL PASS: ENSURE PERMISSIONS & REALTIME
-- =============================================================================

-- Ensure authenticated users have general access (standard minimal grants)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM authenticated;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;

GRANT USAGE ON SCHEMA public TO authenticated;

-- Messaging: authenticated needs select/insert on messages & conversations
GRANT SELECT, INSERT ON public.messages, public.conversations, public.conversation_participants TO authenticated;
-- Map posts: allow public SELECT, authenticated INSERT/UPDATE/DELETE controlled by RLS but grant needed object rights:
GRANT SELECT ON public.map_posts TO PUBLIC;
GRANT INSERT, UPDATE, DELETE ON public.map_posts TO authenticated;

-- Grant broad access for now (until stricter role model implemented) to avoid breakage
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Force Realtime for core messaging tables (if publication exists)
DO $$
DECLARE
  pub_oid oid;
  rel regclass;
  tbl regclass;
  tbls text[] := ARRAY[
    'public.messages', 'public.conversations', 'public.conversation_participants',
    'public.skate_lobbies', 'public.skate_lobby_players', 'public.skate_lobby_events'
  ];
  t text;
BEGIN
  SELECT oid INTO pub_oid FROM pg_publication WHERE pubname = 'supabase_realtime';
  IF pub_oid IS NULL THEN
    RAISE NOTICE 'Publication supabase_realtime not found; skipping publication changes';
    RETURN;
  END IF;

  FOREACH t IN ARRAY tbls LOOP
    BEGIN
      tbl := t::regclass;
      IF NOT EXISTS (SELECT 1 FROM pg_publication_rel WHERE prpubid = pub_oid AND prrelid = tbl) THEN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %s', t);
        RAISE NOTICE 'Added % to publication', t;
      ELSE
        RAISE NOTICE '% already in publication', t;
      END IF;
    EXCEPTION WHEN undefined_table THEN
      RAISE NOTICE 'Table % does not exist; skipping', t;
    END;
  END LOOP;
END $$;



-- Create indexes
CREATE INDEX IF NOT EXISTS idx_shops_owner_id ON shops(owner_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_offers_user_id ON sponsorship_offers(user_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_offers_shop_id ON sponsorship_offers(shop_id);
CREATE INDEX IF NOT EXISTS idx_error_logs_user_id ON public.error_logs(user_id); -- Added missing index


-- Enable RLS

-- Consolidated section continues...



-- Redundant definitions removed.




-- Redundant profile and content migrations removed.

-- Create error_logs table for admin error monitoring
-- 1. Seed data for trick_nodes
DO $$
DECLARE
    ollie_id UUID;
    pop_shuvit_id UUID;
    fs_180_id UUID;
    bs_180_id UUID;
    kickflip_id UUID;
    heelflip_id UUID;
    varial_flip_id UUID;
BEGIN
    -- Only seed if trick_nodes is empty
    IF NOT EXISTS (SELECT 1 FROM trick_nodes LIMIT 1) THEN
        -- Level 0: Ollie (Root)
        INSERT INTO trick_nodes (name, description, difficulty, category, points_value)
        VALUES ('Ollie', 'The foundation of street skating.', 1, 'flat', 50)
        RETURNING id INTO ollie_id;

        -- Level 1 Tricks (Require Ollie)
        INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
        VALUES ('Pop Shuvit', 'Spin the board 180 degrees without flipping.', 2, 'flat', ARRAY[ollie_id], 100)
        RETURNING id INTO pop_shuvit_id;

        INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
        VALUES ('Frontside 180', 'Rotate your body and board 180 degrees frontside.', 2, 'flat', ARRAY[ollie_id], 100)
        RETURNING id INTO fs_180_id;

        INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
        VALUES ('Backside 180', 'Rotate your body and board 180 degrees backside.', 2, 'flat', ARRAY[ollie_id], 100)
        RETURNING id INTO bs_180_id;

        INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
        VALUES ('Kickflip', 'Flip the board with your toe.', 3, 'flat', ARRAY[ollie_id], 150)
        RETURNING id INTO kickflip_id;

        INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
        VALUES ('Heelflip', 'Flip the board with your heel.', 3, 'flat', ARRAY[ollie_id], 150)
        RETURNING id INTO heelflip_id;

        -- Level 2 Tricks (Combinations)
        INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
        VALUES ('Varial Kickflip', 'Combine a Pop Shuvit and a Kickflip.', 4, 'flat', ARRAY[pop_shuvit_id, kickflip_id], 200)
        RETURNING id INTO varial_flip_id;

        INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
        VALUES ('Tre Flip', '360 Pop Shuvit + Kickflip.', 5, 'flat', ARRAY[varial_flip_id], 300);

        RAISE NOTICE 'Seeded trick nodes successfully.';
    END IF;
END $$;

-- 2. Insert default app settings
INSERT INTO public.app_settings (key, value)
VALUES (
    'points_config',
    '{
        "base_daily_points": 3.5,
        "streak_bonus_multiplier": 0.5,
        "first_login_bonus": 10.0,
        "post_xp": 100.0,
        "vote_xp": 1.0
    }'::jsonb
) ON CONFLICT (key) DO NOTHING;

-- 3. Initial Profile Data Fixes
UPDATE user_profiles SET bio = '' WHERE bio IS NULL;
UPDATE public.user_profiles SET points = 1000 WHERE points IS NULL;

-- Fix null coordinates for dreadpirateduppie
UPDATE user_profiles
SET
  current_latitude = 51.5074,
  current_longitude = -0.1278,
  location_updated_at = NOW()
WHERE username = 'dreadpirateduppie' AND current_latitude IS NULL;

-- 4. Backfill existing emails from auth.users
UPDATE public.user_profiles up
SET email = u.email
FROM auth.users u
WHERE up.id = u.id AND up.email IS NULL;

-- 5. Enable Realtime (Optional/Idempotent example)
-- ALTER PUBLICATION supabase_realtime ADD TABLE messages;
-- ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
-- ALTER PUBLICATION supabase_realtime ADD TABLE conversation_participants;

-- =============================================================================
-- MONITORING & HEALTH CHECKS
-- =============================================================================

CREATE OR REPLACE FUNCTION get_db_health() 
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'status', 'healthy',
        'timestamp', now(),
        'message_count_5m', (SELECT count(*) FROM public.messages WHERE created_at > now() - interval '5 minutes'),
        'error_count_1h', (SELECT count(*) FROM public.error_logs WHERE created_at > now() - interval '1 hour'),
        'stickiness', (SELECT ratio FROM get_stickiness_ratio())
    ) INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION get_db_health TO authenticated;
