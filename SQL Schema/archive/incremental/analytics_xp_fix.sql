-- Migration: analytics_xp_fix
-- Description: Automates XP (map_score) updates via triggers and broadens activity definitions for analytics.

-- 1. Ensure columns exist on map_posts for vote tracking
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='map_posts' AND column_name='upvotes') THEN
        ALTER TABLE public.map_posts ADD COLUMN upvotes INTEGER DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='map_posts' AND column_name='downvotes') THEN
        ALTER TABLE public.map_posts ADD COLUMN downvotes INTEGER DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='map_posts' AND column_name='vote_score') THEN
        ALTER TABLE public.map_posts ADD COLUMN vote_score INTEGER DEFAULT 0;
    END IF;
END $$;

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_sync_post_vote_totals ON public.post_votes;
CREATE TRIGGER tr_sync_post_vote_totals
AFTER INSERT OR UPDATE OR DELETE ON public.post_votes
FOR EACH ROW EXECUTE FUNCTION sync_post_vote_totals();

-- 3. Trigger to update user_scores incrementally
CREATE OR REPLACE FUNCTION update_user_map_xp()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_xp_change NUMERIC;
BEGIN
    -- Get XP values from app_settings or defaults
    -- Defaulting here to avoid extra lookups in a high-frequency trigger
    -- post_xp = 100, vote_xp = 1
    
    IF (TG_TABLE_NAME = 'map_posts') THEN
        IF (TG_OP = 'INSERT') THEN
            v_user_id := NEW.user_id;
            v_xp_change := 100; -- Base post XP
        ELSIF (TG_OP = 'DELETE') THEN
            v_user_id := OLD.user_id;
            v_xp_change := -100;
        END IF;
    ELSIF (TG_TABLE_NAME = 'post_votes') THEN
        -- When a vote changes, only the POST OWNER gains/loses XP
        SELECT user_id INTO v_user_id FROM public.map_posts WHERE id = COALESCE(NEW.post_id, OLD.post_id);
        
        IF (TG_OP = 'INSERT') THEN
            v_xp_change := NEW.vote_type; -- Gain 1 for up, lose 1 for down
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
        
        -- Log to XP history
        INSERT INTO public.xp_history (user_id, score_type, amount, reason)
        VALUES (v_user_id, 'map', v_xp_change, 'Real-time update: ' || TG_TABLE_NAME || ' ' || TG_OP);
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for map_posts
DROP TRIGGER IF EXISTS tr_update_xp_on_post ON public.map_posts;
CREATE TRIGGER tr_update_xp_on_post
AFTER INSERT OR DELETE ON public.map_posts
FOR EACH ROW EXECUTE FUNCTION update_user_map_xp();

-- Trigger for post_votes
DROP TRIGGER IF EXISTS tr_update_xp_on_vote ON public.post_votes;
CREATE TRIGGER tr_update_xp_on_vote
AFTER INSERT OR UPDATE OR DELETE ON public.post_votes
FOR EACH ROW EXECUTE FUNCTION update_user_map_xp();

-- 4. Broaden Activity Tracking for Analytics
-- Add last_active_at to user_profiles
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='last_active_at') THEN
        ALTER TABLE public.user_profiles ADD COLUMN last_active_at TIMESTAMP WITH TIME ZONE DEFAULT now();
    END IF;
END $$;

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
$$ LANGUAGE plpgsql SECURITY DEFINER;
