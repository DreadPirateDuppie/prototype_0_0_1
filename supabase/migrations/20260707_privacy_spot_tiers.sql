-- ============================================================================
-- Privacy-First Spot Architecture (tiered spot visibility)
-- ============================================================================
-- Implements the vault-specced Anti-Gatekeeping Protocol: every map_posts row
-- carries a visibility_level so hidden street spots can be kept off the
-- public map:
--   * public — visible to everyone (existing default behaviour, unchanged).
--   * crew   — visible only to members of the poster's crew (crew_id).
--   * invite — visible only to specifically invited users (spot_invites).
--
-- Enforced at the RLS layer (not just client-side filtering) so a private
-- spot is never broadcast even to a client that queries Supabase directly.
-- The Flutter client additionally reads visibility_level/crew_id to badge
-- markers and reuses the crew-membership pattern already in
-- TerritoryService.getMyCrew() (see 20260706_territorial_capture.sql).
--
-- Idempotent: safe to run multiple times. Not applied anywhere yet — review
-- before running against the live project.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Columns.
-- ----------------------------------------------------------------------------
ALTER TABLE public.map_posts
    ADD COLUMN IF NOT EXISTS visibility_level TEXT NOT NULL DEFAULT 'public';

-- Constrain separately (IF NOT EXISTS guard for CHECK constraints via DO block,
-- since "ADD CONSTRAINT IF NOT EXISTS" isn't supported for CHECK in Postgres).
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'map_posts_visibility_level_check'
    ) THEN
        ALTER TABLE public.map_posts
            ADD CONSTRAINT map_posts_visibility_level_check
            CHECK (visibility_level IN ('public', 'crew', 'invite'));
    END IF;
END $$;

ALTER TABLE public.map_posts
    ADD COLUMN IF NOT EXISTS crew_id UUID REFERENCES public.crews(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_map_posts_visibility_level ON public.map_posts(visibility_level);
CREATE INDEX IF NOT EXISTS idx_map_posts_crew_id ON public.map_posts(crew_id) WHERE crew_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 2. Invite Tier: per-user, per-spot invites for temporary sessions/private
--    battles. Schema + RPC only for now — no invite-picker UI yet (same scope
--    boundary the territory work drew around the B2B dominance view).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.spot_invites (
    spot_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
    invited_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (spot_id, invited_user_id)
);

CREATE INDEX IF NOT EXISTS idx_spot_invites_invited_user ON public.spot_invites(invited_user_id);

ALTER TABLE public.spot_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "spot_invites_select_own" ON public.spot_invites;
CREATE POLICY "spot_invites_select_own" ON public.spot_invites
    FOR SELECT TO authenticated
    USING (
        invited_user_id = (SELECT auth.uid())
        OR invited_by = (SELECT auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.map_posts mp
            WHERE mp.id = spot_invites.spot_id AND mp.user_id = (SELECT auth.uid())
        )
    );

REVOKE INSERT, UPDATE, DELETE ON public.spot_invites FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.invite_user_to_spot(
    p_spot_id UUID,
    p_invited_user_id UUID
) RETURNS VOID AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_owner UUID;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'invite_user_to_spot: not authenticated';
    END IF;
    IF p_spot_id IS NULL OR p_invited_user_id IS NULL THEN
        RAISE EXCEPTION 'invite_user_to_spot: spot and invited user are required';
    END IF;

    SELECT user_id INTO v_owner FROM public.map_posts WHERE id = p_spot_id;
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'invite_user_to_spot: spot % not found', p_spot_id;
    END IF;
    IF v_owner <> v_caller THEN
        RAISE EXCEPTION 'invite_user_to_spot: only the spot owner can invite';
    END IF;

    INSERT INTO public.spot_invites (spot_id, invited_user_id, invited_by)
    VALUES (p_spot_id, p_invited_user_id, v_caller)
    ON CONFLICT (spot_id, invited_user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.invite_user_to_spot(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.invite_user_to_spot(UUID, UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. RLS: replace the blanket "select public" policy with tiered visibility.
--    Owners can always see their own posts regardless of tier. The existing
--    "Map posts modify own" ALL policy is untouched.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Map posts select public" ON public.map_posts;
DROP POLICY IF EXISTS "Map posts select visibility tiered" ON public.map_posts;
CREATE POLICY "Map posts select visibility tiered" ON public.map_posts
    FOR SELECT
    USING (
        visibility_level = 'public'
        OR user_id = (SELECT auth.uid())
        OR (
            visibility_level = 'crew'
            AND crew_id IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM public.crew_members cm
                WHERE cm.crew_id = map_posts.crew_id AND cm.user_id = (SELECT auth.uid())
            )
        )
        OR (
            visibility_level = 'invite'
            AND EXISTS (
                SELECT 1 FROM public.spot_invites si
                WHERE si.spot_id = map_posts.id AND si.invited_user_id = (SELECT auth.uid())
            )
        )
    );
