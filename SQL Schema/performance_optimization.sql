-- Performance Optimization Migration
-- Addresses 200+ performance warnings with robust existence checks.

DO $$ 
BEGIN
    -- 1. Map Posts Optimizations
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'map_posts') THEN
        CREATE INDEX IF NOT EXISTS idx_map_posts_user_id ON public.map_posts(user_id);
        CREATE INDEX IF NOT EXISTS idx_map_posts_category ON public.map_posts(category);
        CREATE INDEX IF NOT EXISTS idx_map_posts_created_at_desc ON public.map_posts(created_at DESC);
    END IF;

    -- 2. Battles Optimizations
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'battles') THEN
        CREATE INDEX IF NOT EXISTS idx_battles_player1_id ON public.battles(player1_id);
        CREATE INDEX IF NOT EXISTS idx_battles_player2_id ON public.battles(player2_id);
        CREATE INDEX IF NOT EXISTS idx_battles_status ON public.battles(status);
        CREATE INDEX IF NOT EXISTS idx_battles_created_at ON public.battles(created_at DESC);
    END IF;

    -- 3. Spot Videos Optimizations
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'spot_videos') THEN
        ALTER TABLE public.spot_videos ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_spot_videos_submitted_by ON public.spot_videos(submitted_by);
        CREATE INDEX IF NOT EXISTS idx_spot_videos_approved_by ON public.spot_videos(approved_by);
    END IF;

    -- 4. Messaging Optimizations
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'messages') THEN
        CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
        CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
    END IF;

    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'conversation_participants') THEN
        CREATE INDEX IF NOT EXISTS idx_conversation_participants_user_id ON public.conversation_participants(user_id);
        CREATE INDEX IF NOT EXISTS idx_conversation_participants_conv_id ON public.conversation_participants(conversation_id);
    END IF;

    -- 5. Notifications Optimizations
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        CREATE INDEX IF NOT EXISTS idx_notifications_user_id_read ON public.notifications(user_id, is_read);
    END IF;

    -- 6. User Scores/XP Optimizations
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_scores') THEN
        CREATE INDEX IF NOT EXISTS idx_user_scores_player_score ON public.user_scores(player_score DESC);
        CREATE INDEX IF NOT EXISTS idx_user_scores_ranking_score ON public.user_scores(ranking_score DESC);
    END IF;

    -- 7. Follows Optimizations
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'follows') THEN
        CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON public.follows(follower_id);
        CREATE INDEX IF NOT EXISTS idx_follows_following_id ON public.follows(following_id);
    END IF;
END $$;
