-- ============================================================================
-- NBD ("Never Been Done") Registry — Master Blueprint §3.3
-- ============================================================================
-- ⚠️  NOT YET APPLIED TO A LIVE DATABASE (Supabase project status unconfirmed
--     as of 08-07-26). Apply together with the other 20260708_* migrations
--     once the DB is reachable.
--
-- Skaters upload a raw clip pinned to exact geo-coordinates for a genuinely
-- new trick/spot. The clip bypasses public likes/algorithmic sorting and
-- enters a peer-review queue where verified high-tier community veterans
-- (user_profiles.is_nbd_reviewer, granted by admins) authenticate it. Once
-- the approval threshold is met the clip is permanently locked to its
-- landmark (status = 'approved'; no client UPDATE/DELETE path exists) and an
-- automated points bounty is credited to the skater's wallet + ledger.
--
-- NOTE ON THE CASH RAIL: the blueprint specifies a fiat cash bounty. The
-- points ledger entry here is real and replay-proof; converting it to a fiat
-- payout (NowPayments or bank rail) is a founder decision and is stubbed —
-- see 'nbd_bounty' transactions in point_transactions as the settlement
-- source of truth.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Veteran reviewer role + bounty config.
-- ----------------------------------------------------------------------------
ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS is_nbd_reviewer BOOLEAN DEFAULT FALSE;

-- Merge NBD config defaults into points_config (existing keys win).
UPDATE public.app_settings
SET value = '{"nbd_bounty_points": 250, "nbd_approvals_required": 3, "nbd_rejections_required": 3}'::jsonb || value
WHERE key = 'points_config';

INSERT INTO public.app_settings (key, value)
VALUES ('points_config',
        '{"nbd_bounty_points": 250, "nbd_approvals_required": 3, "nbd_rejections_required": 3}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. clips: the NBD ledger. (The long-sketched `clips` table with `is_nbd`.)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    trick_name TEXT NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    -- Optional link to an existing spot landmark in the directory.
    spot_id UUID REFERENCES public.map_posts(id) ON DELETE SET NULL,
    is_nbd BOOLEAN NOT NULL DEFAULT TRUE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    approved_at TIMESTAMP WITH TIME ZONE,
    bounty_points NUMERIC,          -- filled at approval time from config
    bounty_paid BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_clips_status ON public.clips(status);
CREATE INDEX IF NOT EXISTS idx_clips_user_id ON public.clips(user_id);
CREATE INDEX IF NOT EXISTS idx_clips_location ON public.clips(latitude, longitude);

ALTER TABLE public.clips ENABLE ROW LEVEL SECURITY;

-- Approved clips are the public, map-locked registry. Owners always see
-- their own submissions; reviewers and admins see the pending queue.
DROP POLICY IF EXISTS "clips select" ON public.clips;
CREATE POLICY "clips select" ON public.clips
    FOR SELECT USING (
        status = 'approved'
        OR user_id = (SELECT auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = (SELECT auth.uid())
              AND (up.is_nbd_reviewer OR up.is_admin)
        )
    );

DROP POLICY IF EXISTS "clips insert own" ON public.clips;
CREATE POLICY "clips insert own" ON public.clips
    FOR INSERT WITH CHECK (
        user_id = (SELECT auth.uid())
        AND status = 'pending'
        AND approved_at IS NULL
        AND bounty_paid = FALSE
    );

-- No UPDATE/DELETE policies on purpose: once submitted, the record is
-- immutable to clients ("permanently locked"); state changes happen only
-- through the submit_nbd_review SECURITY DEFINER RPC below.

-- ----------------------------------------------------------------------------
-- 3. nbd_reviews: one verdict per reviewer per clip.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.nbd_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clip_id UUID NOT NULL REFERENCES public.clips(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    verdict TEXT NOT NULL CHECK (verdict IN ('approve', 'reject')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(clip_id, reviewer_id)
);

CREATE INDEX IF NOT EXISTS idx_nbd_reviews_clip_id ON public.nbd_reviews(clip_id);

ALTER TABLE public.nbd_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "nbd_reviews select" ON public.nbd_reviews;
CREATE POLICY "nbd_reviews select" ON public.nbd_reviews
    FOR SELECT USING (
        reviewer_id = (SELECT auth.uid())
        OR EXISTS (SELECT 1 FROM public.clips c
                   WHERE c.id = nbd_reviews.clip_id AND c.user_id = (SELECT auth.uid()))
        OR EXISTS (SELECT 1 FROM public.user_profiles up
                   WHERE up.id = (SELECT auth.uid()) AND (up.is_nbd_reviewer OR up.is_admin))
    );

-- Inserts happen only through the RPC (validates role + threshold + payout
-- atomically), so no INSERT policy is granted here.

-- ----------------------------------------------------------------------------
-- 4. submit_nbd_review: the whole review/approve/bounty pipeline, atomic.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_nbd_review(
    p_clip_id UUID,
    p_verdict TEXT,
    p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_is_reviewer BOOLEAN := FALSE;
    v_clip RECORD;
    v_config JSONB;
    v_approvals_required INTEGER;
    v_rejections_required INTEGER;
    v_bounty NUMERIC;
    v_approvals INTEGER;
    v_rejections INTEGER;
    v_new_status TEXT;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'submit_nbd_review: not authenticated';
    END IF;
    IF p_verdict NOT IN ('approve', 'reject') THEN
        RAISE EXCEPTION 'submit_nbd_review: verdict must be approve or reject';
    END IF;

    SELECT COALESCE(up.is_nbd_reviewer, FALSE) OR COALESCE(up.is_admin, FALSE)
    INTO v_is_reviewer
    FROM public.user_profiles up WHERE up.id = v_caller;

    IF NOT COALESCE(v_is_reviewer, FALSE) THEN
        RAISE EXCEPTION 'submit_nbd_review: caller is not an NBD reviewer';
    END IF;

    -- Serialize reviews per clip so the threshold check cannot race.
    PERFORM pg_advisory_xact_lock(hashtextextended('nbd_review:' || p_clip_id::text, 0));

    SELECT * INTO v_clip FROM public.clips WHERE id = p_clip_id;
    IF v_clip IS NULL THEN
        RAISE EXCEPTION 'submit_nbd_review: clip % not found', p_clip_id;
    END IF;
    IF v_clip.user_id = v_caller THEN
        RAISE EXCEPTION 'submit_nbd_review: reviewers cannot review their own clip';
    END IF;
    IF v_clip.status <> 'pending' THEN
        RAISE EXCEPTION 'submit_nbd_review: clip is already %', v_clip.status;
    END IF;

    INSERT INTO public.nbd_reviews (clip_id, reviewer_id, verdict, notes)
    VALUES (p_clip_id, v_caller, p_verdict, p_notes);
    -- UNIQUE(clip_id, reviewer_id) raises on double-review.

    SELECT value INTO v_config FROM public.app_settings WHERE key = 'points_config';
    v_approvals_required  := COALESCE((v_config->>'nbd_approvals_required')::INTEGER, 3);
    v_rejections_required := COALESCE((v_config->>'nbd_rejections_required')::INTEGER, 3);
    v_bounty              := COALESCE((v_config->>'nbd_bounty_points')::NUMERIC, 250);

    SELECT
        COUNT(*) FILTER (WHERE verdict = 'approve'),
        COUNT(*) FILTER (WHERE verdict = 'reject')
    INTO v_approvals, v_rejections
    FROM public.nbd_reviews WHERE clip_id = p_clip_id;

    v_new_status := 'pending';

    IF v_approvals >= v_approvals_required THEN
        v_new_status := 'approved';

        UPDATE public.clips
        SET status = 'approved',
            approved_at = now(),
            bounty_points = v_bounty,
            bounty_paid = TRUE
        WHERE id = p_clip_id AND status = 'pending';

        -- Automated bounty: wallet credit + immutable ledger entry.
        -- Replay-proof: the status<>'pending' guard above plus the advisory
        -- lock guarantee this branch runs exactly once per clip.
        INSERT INTO public.user_wallets (user_id, balance, updated_at)
        VALUES (v_clip.user_id, v_bounty, now())
        ON CONFLICT (user_id) DO UPDATE
            SET balance = user_wallets.balance + v_bounty, updated_at = now();

        INSERT INTO public.point_transactions
            (user_id, amount, transaction_type, reference_id, description)
        VALUES
            (v_clip.user_id, v_bounty, 'nbd_bounty', p_clip_id::text,
             'NBD Registry bounty: ' || v_clip.trick_name);

        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            v_clip.user_id, 'nbd_approved', 'NBD verified!',
            'Your NBD "' || v_clip.trick_name || '" was authenticated and locked to the map. Bounty: ' || v_bounty || ' pts.',
            jsonb_build_object('clip_id', p_clip_id)
        );

    ELSIF v_rejections >= v_rejections_required THEN
        v_new_status := 'rejected';

        UPDATE public.clips
        SET status = 'rejected'
        WHERE id = p_clip_id AND status = 'pending';

        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            v_clip.user_id, 'nbd_rejected', 'NBD not verified',
            'Your NBD submission "' || v_clip.trick_name || '" was not authenticated by the review panel.',
            jsonb_build_object('clip_id', p_clip_id)
        );
    END IF;

    RETURN jsonb_build_object(
        'status', v_new_status,
        'approvals', v_approvals,
        'rejections', v_rejections,
        'approvals_required', v_approvals_required
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.submit_nbd_review(UUID, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.submit_nbd_review(UUID, TEXT, TEXT) TO authenticated;
