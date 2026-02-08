-- COMPLETE SCALABILITY MIGRATION: 1M+ USERS (V2 - IDEMPOTENT)
-- This script handles Phase 1 (Functional) and Phase 2 (Partitioning).
-- It is designed to be run multiple times safely.

BEGIN;

-- ==========================================
-- PHASE 1: FUNCTIONAL ENHANCEMENTS
-- ==========================================

-- 1. Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Add activity tracking columns
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='conversation_participants' AND column_name='last_activity_at') THEN
    ALTER TABLE public.conversation_participants ADD COLUMN last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='map_posts' AND column_name='mvp_last_updated_at') THEN
    ALTER TABLE public.map_posts ADD COLUMN mvp_last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT '-infinity';
  END IF;
END $$;

-- 3. Full-Text Search Indexing
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_profiles' AND column_name='fts_name') THEN
    ALTER TABLE public.user_profiles ADD COLUMN fts_name tsvector GENERATED ALWAYS AS (
      to_tsvector('english', coalesce(username, '') || ' ' || coalesce(display_name, ''))
    ) STORED;
    CREATE INDEX IF NOT EXISTS idx_user_profiles_fts ON public.user_profiles USING GIN (fts_name);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='trick_definitions' AND column_name='fts_name') THEN
    ALTER TABLE public.trick_definitions ADD COLUMN fts_name tsvector GENERATED ALWAYS AS (
      to_tsvector('english', display_name)
    ) STORED;
    CREATE INDEX IF NOT EXISTS idx_trick_definitions_fts ON public.trick_definitions USING GIN (fts_name);
  END IF;
END $$;

-- 4. High-Performance Functions
DROP FUNCTION IF EXISTS get_nearby_users(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);
CREATE OR REPLACE FUNCTION get_nearby_users(p_lat DOUBLE PRECISION, p_lng DOUBLE PRECISION, p_radius DOUBLE PRECISION)
RETURNS TABLE (id UUID, username TEXT, display_name TEXT, avatar_url TEXT, current_latitude DOUBLE PRECISION, current_longitude DOUBLE PRECISION, location_sharing_mode TEXT, location_blacklist TEXT[], is_verified BOOLEAN, distance_meters DOUBLE PRECISION) AS $$
BEGIN
  RETURN QUERY SELECT up.id, up.username, up.display_name, up.avatar_url, up.current_latitude, up.current_longitude, up.location_sharing_mode, up.location_blacklist, up.is_verified,
    ST_Distance(ST_MakePoint(up.current_longitude, up.current_latitude)::geography, ST_MakePoint(p_lng, p_lat)::geography) AS distance_meters
  FROM public.user_profiles up WHERE up.location_sharing_mode != 'off' AND up.current_latitude IS NOT NULL AND up.current_longitude IS NOT NULL
  AND ST_DWithin(ST_MakePoint(up.current_longitude, up.current_latitude)::geography, ST_MakePoint(p_lng, p_lat)::geography, p_radius)
  ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION search_profiles(search_query TEXT, limit_cnt INT DEFAULT 20) 
RETURNS TABLE (id UUID, username TEXT, display_name TEXT, avatar_url TEXT) AS $$
BEGIN
  RETURN QUERY SELECT up.id, up.username, up.display_name, up.avatar_url FROM user_profiles up
  WHERE up.fts_name @@ websearch_to_tsquery('english', search_query) OR up.username ILIKE '%' || search_query || '%'
  ORDER BY ts_rank(up.fts_name, websearch_to_tsquery('english', search_query)) DESC LIMIT limit_cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Optimized Triggers
CREATE OR REPLACE FUNCTION update_conversation_last_message() RETURNS TRIGGER AS $$
BEGIN 
    UPDATE conversations SET last_message_at = NEW.created_at WHERE id = NEW.conversation_id;
    UPDATE conversation_participants SET last_activity_at = NEW.created_at WHERE conversation_id = NEW.conversation_id;
    RETURN NEW; 
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_spot_mvp() RETURNS TRIGGER AS $$
DECLARE target_spot_id UUID; new_mvp_id UUID; new_mvp_score INTEGER; v_last_update TIMESTAMP WITH TIME ZONE;
BEGIN
    IF (TG_OP = 'DELETE') THEN target_spot_id := OLD.spot_id; ELSE target_spot_id := NEW.spot_id; END IF;
    SELECT mvp_last_updated_at INTO v_last_update FROM map_posts WHERE id = target_spot_id;
    IF (v_last_update > NOW() - INTERVAL '1 hour') THEN RETURN NULL; END IF;
    SELECT submitted_by, SUM((10 * COALESCE(difficulty_multiplier, 1.0)) * (CASE WHEN stance = 'switch' THEN 1.7 WHEN stance = 'nollie' THEN 1.4 WHEN stance = 'fakie' THEN 1.2 ELSE 1.0 END) * (upvotes + 1)) as total_weighted_score
    INTO new_mvp_id, new_mvp_score FROM spot_videos WHERE spot_id = target_spot_id AND status = 'approved' AND is_own_clip = TRUE GROUP BY submitted_by ORDER BY total_weighted_score DESC LIMIT 1;
    IF new_mvp_id IS NULL THEN new_mvp_score := 0; END IF;
    UPDATE map_posts SET mvp_user_id = new_mvp_id, mvp_score = COALESCE(new_mvp_score, 0), mvp_last_updated_at = NOW() WHERE id = target_spot_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- ==========================================
-- PHASE 2: STRUCTURAL CHANGES (PARTITIONING)
-- ==========================================

-- A. MESSAGES (RANGE)
DO $$ BEGIN
  -- Check if table is already partitioned
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'messages') 
     AND NOT EXISTS (SELECT 1 FROM pg_partitioned_table WHERE partrelid = 'public.messages'::regclass) THEN
    
    ALTER TABLE public.messages RENAME TO messages_old;
    
    CREATE TABLE public.messages (
      id UUID NOT NULL DEFAULT gen_random_uuid(),
      conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
      sender_id UUID NOT NULL REFERENCES auth.users(id),
      content TEXT NOT NULL,
      message_type VARCHAR(20) DEFAULT 'text',
      media_url TEXT, media_name TEXT, media_size INTEGER,
      reply_to_id UUID,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      is_deleted BOOLEAN DEFAULT FALSE,
      is_edited BOOLEAN DEFAULT FALSE,
      read_by JSONB DEFAULT '[]'::jsonb,
      PRIMARY KEY (id, created_at)
    ) PARTITION BY RANGE (created_at);

    INSERT INTO public.messages SELECT * FROM public.messages_old;
    DROP TABLE public.messages_old;

    -- RESTORE RLS
    ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Messages select participants" ON public.messages;
    CREATE POLICY "Messages select participants" ON public.messages FOR SELECT USING (EXISTS (SELECT 1 FROM public.conversation_participants cp WHERE cp.conversation_id = public.messages.conversation_id AND cp.user_id = (SELECT auth.uid())));
    DROP POLICY IF EXISTS "Messages modify own" ON public.messages;
    CREATE POLICY "Messages modify own" ON public.messages FOR ALL USING (sender_id = (SELECT auth.uid()));
  END IF;
  
  -- Ensure partitions exist
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'messages_y2026m01') THEN
    CREATE TABLE public.messages_y2026m01 PARTITION OF public.messages FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'messages_y2026m02') THEN
    CREATE TABLE public.messages_y2026m02 PARTITION OF public.messages FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'messages_default') THEN
    CREATE TABLE public.messages_default PARTITION OF public.messages DEFAULT;
  END IF;
END $$;

-- B. NOTIFICATIONS (RANGE)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'notifications') 
     AND NOT EXISTS (SELECT 1 FROM pg_partitioned_table WHERE partrelid = 'public.notifications'::regclass) THEN
    
    ALTER TABLE public.notifications RENAME TO notifications_old;
    
    CREATE TABLE public.notifications (
        id UUID DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        type TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, data JSONB DEFAULT '{}'::jsonb, is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
        PRIMARY KEY (id, created_at)
    ) PARTITION BY RANGE (created_at);

    INSERT INTO public.notifications SELECT * FROM public.notifications_old;
    DROP TABLE public.notifications_old;

    -- RESTORE RLS
    ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Notifications select own" ON public.notifications;
    CREATE POLICY "Notifications select own" ON public.notifications FOR SELECT USING (user_id = (SELECT auth.uid()));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'notifications_y2026m01') THEN
    CREATE TABLE public.notifications_y2026m01 PARTITION OF public.notifications FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'notifications_default') THEN
    CREATE TABLE public.notifications_default PARTITION OF public.notifications DEFAULT;
  END IF;
END $$;

-- C. POST_VOTES (HASH)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'post_votes') 
     AND NOT EXISTS (SELECT 1 FROM pg_partitioned_table WHERE partrelid = 'public.post_votes'::regclass) THEN
    
    ALTER TABLE IF EXISTS public.post_votes RENAME TO post_votes_old;
    
    CREATE TABLE public.post_votes (
      id UUID NOT NULL DEFAULT gen_random_uuid(),
      post_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      vote_type INTEGER NOT NULL, created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(), updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      PRIMARY KEY (post_id, user_id)
    ) PARTITION BY HASH (post_id);

    CREATE TABLE public.post_votes_p1 PARTITION OF public.post_votes FOR VALUES WITH (MODULUS 4, REMAINDER 0);
    CREATE TABLE public.post_votes_p2 PARTITION OF public.post_votes FOR VALUES WITH (MODULUS 4, REMAINDER 1);
    CREATE TABLE public.post_votes_p3 PARTITION OF public.post_votes FOR VALUES WITH (MODULUS 4, REMAINDER 2);
    CREATE TABLE public.post_votes_p4 PARTITION OF public.post_votes FOR VALUES WITH (MODULUS 4, REMAINDER 3);

    INSERT INTO public.post_votes SELECT * FROM public.post_votes_old;
    DROP TABLE public.post_votes_old;

    -- RESTORE RLS
    ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Post votes public select" ON public.post_votes;
    CREATE POLICY "Post votes public select" ON public.post_votes FOR SELECT USING (true);
    DROP POLICY IF EXISTS "Post votes insert by owner" ON public.post_votes;
    CREATE POLICY "Post votes insert by owner" ON public.post_votes FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));
    DROP POLICY IF EXISTS "Post votes update by owner" ON public.post_votes;
    CREATE POLICY "Post votes update by owner" ON public.post_votes FOR UPDATE USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
    DROP POLICY IF EXISTS "Post votes delete by owner" ON public.post_votes;
    CREATE POLICY "Post votes delete by owner" ON public.post_votes FOR DELETE USING (user_id = (SELECT auth.uid()));
  END IF;
END $$;

-- D. VIDEO_UPVOTES (HASH)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'video_upvotes') 
     AND NOT EXISTS (SELECT 1 FROM pg_partitioned_table WHERE partrelid = 'public.video_upvotes'::regclass) THEN
    
    ALTER TABLE IF EXISTS public.video_upvotes RENAME TO video_upvotes_old;
    
    CREATE TABLE public.video_upvotes (
      id UUID NOT NULL DEFAULT gen_random_uuid(),
      video_id UUID NOT NULL REFERENCES public.spot_videos(id) ON DELETE CASCADE,
      user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
      vote_type INTEGER NOT NULL CHECK (vote_type IN (1, -1)),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      PRIMARY KEY (video_id, user_id)
    ) PARTITION BY HASH (video_id);

    CREATE TABLE public.video_upvotes_p1 PARTITION OF public.video_upvotes FOR VALUES WITH (MODULUS 4, REMAINDER 0);
    CREATE TABLE public.video_upvotes_p2 PARTITION OF public.video_upvotes FOR VALUES WITH (MODULUS 4, REMAINDER 1);
    CREATE TABLE public.video_upvotes_p3 PARTITION OF public.video_upvotes FOR VALUES WITH (MODULUS 4, REMAINDER 2);
    CREATE TABLE public.video_upvotes_p4 PARTITION OF public.video_upvotes FOR VALUES WITH (MODULUS 4, REMAINDER 3);

    INSERT INTO public.video_upvotes SELECT * FROM public.video_upvotes_old;
    DROP TABLE public.video_upvotes_old;

    -- RESTORE RLS
    ALTER TABLE public.video_upvotes ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Video upvotes public select" ON public.video_upvotes;
    CREATE POLICY "Video upvotes public select" ON public.video_upvotes FOR SELECT USING (true);
    DROP POLICY IF EXISTS "Video upvotes insert by owner" ON public.video_upvotes;
    CREATE POLICY "Video upvotes insert by owner" ON public.video_upvotes FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));
    DROP POLICY IF EXISTS "Video upvotes update by owner" ON public.video_upvotes;
    CREATE POLICY "Video upvotes update by owner" ON public.video_upvotes FOR UPDATE USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
    DROP POLICY IF EXISTS "Video upvotes delete by owner" ON public.video_upvotes;
    CREATE POLICY "Video upvotes delete by owner" ON public.video_upvotes FOR DELETE USING (user_id = (SELECT auth.uid()));
  END IF;
END $$;

COMMIT;
