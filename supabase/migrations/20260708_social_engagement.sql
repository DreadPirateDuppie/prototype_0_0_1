-- ============================================================================
-- Social engagement: real per-user likes, comments, and notification wiring
-- ============================================================================
-- ⚠️  NOT YET APPLIED TO A LIVE DATABASE (Supabase project status unconfirmed
--     as of 08-07-26). Apply together with the other 20260708_* migrations
--     once the DB is reachable.
--
-- Fixes three confirmed Explore-audit gaps:
--   1. Likes were a bare integer on map_posts incremented on tap — spammable,
--      no per-user tracking, no unlike. Replaced by a real post_likes join
--      table; map_posts.likes is now a trigger-maintained denormalized count.
--   2. Comments did not exist at all (no table/service/UI despite the
--      notifications screen already rendering a 'comment' icon branch).
--   3. Notifications were a dead pipe: the notifications table had RLS
--      enabled with ONLY a SELECT policy, so even UserService.createNotification
--      and markNotificationRead would have been silently blocked. Likes,
--      comments and follows now generate notifications via SECURITY DEFINER
--      triggers (spam-resistant, no client write needed); battle events are
--      inserted by the client under the new INSERT policy.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. post_likes: one row per (post, user). Unique constraint = no double-like.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes(user_id);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "post_likes select" ON public.post_likes;
CREATE POLICY "post_likes select" ON public.post_likes
    FOR SELECT USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "post_likes insert own" ON public.post_likes;
CREATE POLICY "post_likes insert own" ON public.post_likes
    FOR INSERT WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "post_likes delete own" ON public.post_likes;
CREATE POLICY "post_likes delete own" ON public.post_likes
    FOR DELETE USING (user_id = (SELECT auth.uid()));

-- ----------------------------------------------------------------------------
-- 2. post_comments + denormalized comment_count on map_posts.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_post_comments_post_created
    ON public.post_comments(post_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_comments_user_id ON public.post_comments(user_id);

ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "post_comments select" ON public.post_comments;
CREATE POLICY "post_comments select" ON public.post_comments
    FOR SELECT USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "post_comments insert own" ON public.post_comments;
CREATE POLICY "post_comments insert own" ON public.post_comments
    FOR INSERT WITH CHECK (user_id = (SELECT auth.uid()));

-- Commenter may delete their own comment; the post owner may moderate
-- comments on their own post.
DROP POLICY IF EXISTS "post_comments delete own or moderate" ON public.post_comments;
CREATE POLICY "post_comments delete own or moderate" ON public.post_comments
    FOR DELETE USING (
        user_id = (SELECT auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.map_posts mp
            WHERE mp.id = post_comments.post_id
              AND mp.user_id = (SELECT auth.uid())
        )
    );

ALTER TABLE public.map_posts ADD COLUMN IF NOT EXISTS likes INTEGER DEFAULT 0;
ALTER TABLE public.map_posts ADD COLUMN IF NOT EXISTS comment_count INTEGER DEFAULT 0;

-- ----------------------------------------------------------------------------
-- 3. Count-sync triggers: map_posts.likes / comment_count are derived state,
--    never written by clients.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_post_like_count() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.map_posts SET likes = likes + 1 WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.map_posts SET likes = GREATEST(likes - 1, 0) WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_sync_post_like_count ON public.post_likes;
CREATE TRIGGER trg_sync_post_like_count
    AFTER INSERT OR DELETE ON public.post_likes
    FOR EACH ROW EXECUTE FUNCTION public.sync_post_like_count();

CREATE OR REPLACE FUNCTION public.sync_post_comment_count() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.map_posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.map_posts SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_sync_post_comment_count ON public.post_comments;
CREATE TRIGGER trg_sync_post_comment_count
    AFTER INSERT OR DELETE ON public.post_comments
    FOR EACH ROW EXECUTE FUNCTION public.sync_post_comment_count();

-- ----------------------------------------------------------------------------
-- 4. Notifications: unblock the pipe.
--    - UPDATE policy so markNotificationRead / mark-all-read work.
--    - INSERT policy for client-generated events (battle invite/result):
--      any authenticated user may notify ANOTHER user (never themselves,
--      which also keeps the trigger paths below as the only self-cleanup).
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Notifications update own" ON public.notifications;
CREATE POLICY "Notifications update own" ON public.notifications
    FOR UPDATE USING (user_id = (SELECT auth.uid()))
    WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Notifications insert for others" ON public.notifications;
CREATE POLICY "Notifications insert for others" ON public.notifications
    FOR INSERT WITH CHECK (
        (SELECT auth.uid()) IS NOT NULL
        AND user_id <> (SELECT auth.uid())
    );

-- ----------------------------------------------------------------------------
-- 5. Notification triggers for likes / comments / follows.
--    SECURITY DEFINER so they bypass RLS; skip self-notifications.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_post_liked() RETURNS TRIGGER AS $$
DECLARE
    v_owner UUID;
    v_title TEXT;
    v_liker TEXT;
BEGIN
    SELECT mp.user_id, mp.title INTO v_owner, v_title
    FROM public.map_posts mp WHERE mp.id = NEW.post_id;

    IF v_owner IS NULL OR v_owner = NEW.user_id THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(up.display_name, up.username, 'Someone') INTO v_liker
    FROM public.user_profiles up WHERE up.id = NEW.user_id;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
        v_owner, 'like', 'New like',
        COALESCE(v_liker, 'Someone') || ' liked your post "' || COALESCE(v_title, 'Untitled') || '"',
        jsonb_build_object('post_id', NEW.post_id, 'actor_id', NEW.user_id)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_notify_post_liked ON public.post_likes;
CREATE TRIGGER trg_notify_post_liked
    AFTER INSERT ON public.post_likes
    FOR EACH ROW EXECUTE FUNCTION public.notify_post_liked();

CREATE OR REPLACE FUNCTION public.notify_post_commented() RETURNS TRIGGER AS $$
DECLARE
    v_owner UUID;
    v_title TEXT;
    v_commenter TEXT;
BEGIN
    SELECT mp.user_id, mp.title INTO v_owner, v_title
    FROM public.map_posts mp WHERE mp.id = NEW.post_id;

    IF v_owner IS NULL OR v_owner = NEW.user_id THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(up.display_name, up.username, 'Someone') INTO v_commenter
    FROM public.user_profiles up WHERE up.id = NEW.user_id;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
        v_owner, 'comment', 'New comment',
        COALESCE(v_commenter, 'Someone') || ' commented: ' || LEFT(NEW.content, 120),
        jsonb_build_object('post_id', NEW.post_id, 'comment_id', NEW.id, 'actor_id', NEW.user_id)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_notify_post_commented ON public.post_comments;
CREATE TRIGGER trg_notify_post_commented
    AFTER INSERT ON public.post_comments
    FOR EACH ROW EXECUTE FUNCTION public.notify_post_commented();

CREATE OR REPLACE FUNCTION public.notify_new_follower() RETURNS TRIGGER AS $$
DECLARE
    v_follower TEXT;
BEGIN
    IF NEW.follower_id = NEW.following_id THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(up.display_name, up.username, 'Someone') INTO v_follower
    FROM public.user_profiles up WHERE up.id = NEW.follower_id;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
        NEW.following_id, 'follow', 'New follower',
        COALESCE(v_follower, 'Someone') || ' started following you',
        jsonb_build_object('actor_id', NEW.follower_id)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_notify_new_follower ON public.follows;
CREATE TRIGGER trg_notify_new_follower
    AFTER INSERT ON public.follows
    FOR EACH ROW EXECUTE FUNCTION public.notify_new_follower();
