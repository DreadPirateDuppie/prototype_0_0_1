-- ============================================================================
-- Spot MVP Engine — "King of the Spot"
-- ============================================================================
-- The Flutter client already *renders* a full Spot MVP system — the MVP card
-- on the spot details screen, the gold crown/halo marker on the map for the
-- reigning user, admin "most competitive spots" analytics, and the trick
-- submission dialog's "Will contribute to your MVP score" promise — but
-- nothing anywhere defined or computed map_posts.mvp_user_id / mvp_score.
-- This migration is the missing server half.
--
-- Rules (server-authoritative, matching the client's existing copy):
--   * Only clips you skated yourself count (spot_videos.is_own_clip = TRUE,
--     status = 'approved', submitted_by IS NOT NULL).
--   * Each clip is worth ROUND(mvp_clip_points × difficulty_multiplier).
--   * The MVP of a spot is the top scorer; ties go to whoever landed their
--     first counting clip earliest (incumbent-friendly, no crown flapping).
--   * Crown changes notify both the newly crowned and the dethroned skater.
--   * Clients can never write mvp_user_id / mvp_score — a guard trigger
--     reverts any change not made by the recompute function itself.
--
-- Idempotent: safe to run multiple times. ⚠️ NOT YET APPLIED TO A LIVE
-- DATABASE (Supabase project status unconfirmed as of 08-07-26).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Columns + tunable configuration (existing keys win).
-- ----------------------------------------------------------------------------
ALTER TABLE public.map_posts
    ADD COLUMN IF NOT EXISTS mvp_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS mvp_score INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_map_posts_mvp_user ON public.map_posts(mvp_user_id);

UPDATE public.app_settings
SET value = '{"mvp_clip_points": 10.0}'::jsonb || value
WHERE key = 'points_config';

INSERT INTO public.app_settings (key, value)
VALUES ('points_config', '{"mvp_clip_points": 10.0}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. recompute_spot_mvp: derive the crown for one spot from spot_videos.
--    SECURITY DEFINER + a transaction-local GUC so it is the only code path
--    allowed through the tamper guard in §3.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recompute_spot_mvp(p_spot_id UUID)
RETURNS VOID AS $$
DECLARE
    v_points_per_clip NUMERIC;
    v_new_mvp UUID;
    v_new_score INTEGER := 0;
    v_old_mvp UUID;
    v_old_score INTEGER;
    v_spot_title TEXT;
BEGIN
    IF p_spot_id IS NULL THEN
        RETURN;
    END IF;

    -- Serialize per spot so concurrent clip writes can't interleave crowns.
    PERFORM pg_advisory_xact_lock(hashtextextended('spot_mvp:' || p_spot_id::text, 0));

    SELECT mvp_user_id, mvp_score, title
    INTO v_old_mvp, v_old_score, v_spot_title
    FROM public.map_posts WHERE id = p_spot_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE((value->>'mvp_clip_points')::NUMERIC, 10.0)
    INTO v_points_per_clip
    FROM public.app_settings WHERE key = 'points_config';
    v_points_per_clip := COALESCE(v_points_per_clip, 10.0);

    SELECT sub.submitted_by, sub.score
    INTO v_new_mvp, v_new_score
    FROM (
        SELECT
            sv.submitted_by,
            SUM(ROUND(v_points_per_clip * COALESCE(sv.difficulty_multiplier, 1.0)))::INTEGER AS score,
            MIN(sv.created_at) AS first_clip_at
        FROM public.spot_videos sv
        WHERE sv.spot_id = p_spot_id
          AND sv.is_own_clip = TRUE
          AND sv.status = 'approved'
          AND sv.submitted_by IS NOT NULL
        GROUP BY sv.submitted_by
        ORDER BY score DESC, first_clip_at ASC
        LIMIT 1
    ) sub;

    v_new_score := COALESCE(v_new_score, 0);

    IF v_new_mvp IS NOT DISTINCT FROM v_old_mvp
       AND v_new_score IS NOT DISTINCT FROM COALESCE(v_old_score, 0) THEN
        RETURN; -- nothing changed
    END IF;

    -- Unlock the tamper guard for this transaction only.
    PERFORM set_config('pushinn.mvp_recompute', 'on', true);

    UPDATE public.map_posts
    SET mvp_user_id = v_new_mvp,
        mvp_score = v_new_score
    WHERE id = p_spot_id;

    PERFORM set_config('pushinn.mvp_recompute', 'off', true);

    -- Crown-change notifications (skip when only the score moved).
    IF v_new_mvp IS DISTINCT FROM v_old_mvp THEN
        IF v_new_mvp IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                v_new_mvp, 'spot_mvp_crowned', 'You are the Spot MVP!',
                'You now hold the crown at "' || COALESCE(v_spot_title, 'a spot')
                    || '" with ' || v_new_score || ' pts.',
                jsonb_build_object('spot_id', p_spot_id, 'mvp_score', v_new_score)
            );
        END IF;
        IF v_old_mvp IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, type, title, body, data)
            VALUES (
                v_old_mvp, 'spot_mvp_dethroned', 'Crown lost',
                'You were dethroned at "' || COALESCE(v_spot_title, 'a spot')
                    || '". Land a clip to take it back.',
                jsonb_build_object('spot_id', p_spot_id)
            );
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.recompute_spot_mvp(UUID) FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. Tamper guard: mvp_user_id / mvp_score are derived state. Any UPDATE that
--    didn't come through recompute_spot_mvp has its MVP fields reverted
--    (silently, so legitimate client edits of title/description still work).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_spot_mvp_columns() RETURNS TRIGGER AS $$
BEGIN
    IF COALESCE(current_setting('pushinn.mvp_recompute', true), 'off') <> 'on' THEN
        NEW.mvp_user_id := OLD.mvp_user_id;
        NEW.mvp_score := OLD.mvp_score;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_guard_spot_mvp_columns ON public.map_posts;
CREATE TRIGGER trg_guard_spot_mvp_columns
    BEFORE UPDATE ON public.map_posts
    FOR EACH ROW EXECUTE FUNCTION public.guard_spot_mvp_columns();

-- ----------------------------------------------------------------------------
-- 4. Recompute triggers: any change to a spot's clip ledger re-derives the
--    crown. Handles clips moving between spots (UPDATE of spot_id) too.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.on_spot_videos_changed_recompute_mvp()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        PERFORM public.recompute_spot_mvp(NEW.spot_id);
    END IF;
    IF TG_OP IN ('DELETE', 'UPDATE') THEN
        IF TG_OP = 'DELETE' OR OLD.spot_id IS DISTINCT FROM NEW.spot_id THEN
            PERFORM public.recompute_spot_mvp(OLD.spot_id);
        END IF;
    END IF;
    RETURN NULL; -- AFTER trigger; return value ignored
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_spot_videos_recompute_mvp ON public.spot_videos;
CREATE TRIGGER trg_spot_videos_recompute_mvp
    AFTER INSERT OR UPDATE OR DELETE ON public.spot_videos
    FOR EACH ROW EXECUTE FUNCTION public.on_spot_videos_changed_recompute_mvp();

-- ----------------------------------------------------------------------------
-- 5. Backfill: derive crowns for every spot that already has counting clips.
--    (Notifications for the backfill are expected — first crowning is real.)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_spot UUID;
BEGIN
    FOR v_spot IN
        SELECT DISTINCT sv.spot_id
        FROM public.spot_videos sv
        WHERE sv.is_own_clip = TRUE
          AND sv.status = 'approved'
          AND sv.submitted_by IS NOT NULL
    LOOP
        PERFORM public.recompute_spot_mvp(v_spot);
    END LOOP;
END $$;
