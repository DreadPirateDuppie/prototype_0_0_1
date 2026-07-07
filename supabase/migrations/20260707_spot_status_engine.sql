-- ============================================================================
-- Live Intelligence / Status Engine ("Waze for Skating")
-- ============================================================================
-- Implements the vault-specced Live Intelligence API + "Eyes on the Street":
--   * Status payloads: SECURITY_ACTIVE, WET, LOCKED_OFF, SESSION_ALIVE.
--   * Temporal logic: a status is only "current" for a 4-hour TTL; once no
--     report has landed within that window the spot implicitly reverts to
--     CLEAR (the client treats "no row in spot_current_status" as CLEAR).
--   * Heads Up: reporting SECURITY_ACTIVE or LOCKED_OFF as a *new* escalation
--     (i.e. the spot wasn't already flagged with that status) notifies every
--     user who has favorited (saved_posts) the spot, via the existing
--     `notifications` table/UI.
--
-- Server-authoritative, same shape as 20260706_territorial_capture.sql:
-- clients only ever SELECT the read view; all writes go through a single
-- SECURITY DEFINER RPC.
--
-- Idempotent: safe to run multiple times. Not applied anywhere yet — the
-- live Supabase project (fsogspnecjsoltcmwveg.supabase.co) has not been
-- confirmed reachable; review before running.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tunable configuration (existing keys win; defaults are prepended).
-- ----------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value)
VALUES (
    'spot_status_config',
    '{
        "ttl_hours": 4.0,
        "report_cooldown_minutes": 5.0
    }'::jsonb
) ON CONFLICT (key) DO NOTHING;

UPDATE public.app_settings
SET value = '{
        "ttl_hours": 4.0,
        "report_cooldown_minutes": 5.0
    }'::jsonb || value
WHERE key = 'spot_status_config';

-- ----------------------------------------------------------------------------
-- 2. Table: append-only ledger of user-reported spot status.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.spot_status_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    status_type TEXT NOT NULL CHECK (
        status_type IN ('SECURITY_ACTIVE', 'WET', 'LOCKED_OFF', 'SESSION_ALIVE')
    ),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_spot_status_reports_spot_created
    ON public.spot_status_reports (spot_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_spot_status_reports_user_spot_created
    ON public.spot_status_reports (user_id, spot_id, created_at DESC);

ALTER TABLE public.spot_status_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "spot_status_reports_select_authenticated" ON public.spot_status_reports;
CREATE POLICY "spot_status_reports_select_authenticated" ON public.spot_status_reports
    FOR SELECT TO authenticated USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.spot_status_reports FROM anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. Config helper (STABLE so it can be inlined into the view).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.spot_status_ttl_hours() RETURNS NUMERIC AS $$
    SELECT COALESCE(
        (value->>'ttl_hours')::NUMERIC,
        4.0
    )
    FROM public.app_settings WHERE key = 'spot_status_config';
$$ LANGUAGE sql STABLE;

-- ----------------------------------------------------------------------------
-- 4. Read model: one row per spot with an unexpired report. Absence of a row
--    for a spot_id means CLEAR — the client is expected to treat it as such.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.spot_current_status
WITH (security_invoker = on) AS
SELECT DISTINCT ON (sr.spot_id)
    sr.spot_id,
    sr.status_type,
    sr.user_id AS reported_by,
    sr.created_at AS reported_at,
    sr.created_at + make_interval(hours => public.spot_status_ttl_hours()) AS expires_at
FROM public.spot_status_reports sr
WHERE sr.created_at > now() - make_interval(hours => public.spot_status_ttl_hours())
ORDER BY sr.spot_id, sr.created_at DESC;

GRANT SELECT ON public.spot_current_status TO authenticated;
REVOKE ALL ON public.spot_current_status FROM anon;

-- ----------------------------------------------------------------------------
-- 5. report_spot_status: the single write path.
--    * Enforces a per-user/per-spot cooldown so one skater can't spam the
--      feed (default 5 minutes, tunable via spot_status_config).
--    * On a *new* SECURITY_ACTIVE / LOCKED_OFF escalation (the spot's prior
--      current status was something else), fires a "Heads Up" notification
--      to everyone who has the spot in saved_posts (their favorites).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.report_spot_status(
    p_spot_id UUID,
    p_status TEXT
) RETURNS JSONB AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_cooldown_minutes NUMERIC;
    v_last_report TIMESTAMP WITH TIME ZONE;
    v_prev_status TEXT;
    v_spot_title TEXT;
    v_is_escalation BOOLEAN := FALSE;
    v_notified_count INTEGER := 0;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'report_spot_status: not authenticated';
    END IF;
    IF p_spot_id IS NULL THEN
        RAISE EXCEPTION 'report_spot_status: spot id is required';
    END IF;
    IF p_status IS NULL OR p_status NOT IN
        ('SECURITY_ACTIVE', 'WET', 'LOCKED_OFF', 'SESSION_ALIVE') THEN
        RAISE EXCEPTION 'report_spot_status: status "%" is not a valid payload', p_status;
    END IF;

    SELECT title INTO v_spot_title FROM public.map_posts WHERE id = p_spot_id;
    IF v_spot_title IS NULL THEN
        RAISE EXCEPTION 'report_spot_status: spot % not found', p_spot_id;
    END IF;

    -- Serialize per-spot so a flurry of reports can't double-fire Heads Up.
    PERFORM pg_advisory_xact_lock(hashtextextended('spot_status:' || p_spot_id::text, 0));

    SELECT COALESCE((value->>'report_cooldown_minutes')::NUMERIC, 5.0)
    INTO v_cooldown_minutes
    FROM public.app_settings WHERE key = 'spot_status_config';
    v_cooldown_minutes := COALESCE(v_cooldown_minutes, 5.0);

    SELECT created_at INTO v_last_report
    FROM public.spot_status_reports
    WHERE spot_id = p_spot_id AND user_id = v_caller
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_report IS NOT NULL
        AND v_last_report > now() - make_interval(mins => v_cooldown_minutes) THEN
        RETURN jsonb_build_object('recorded', FALSE, 'reason', 'cooldown');
    END IF;

    -- Current status before this report, to detect a fresh escalation.
    SELECT status_type INTO v_prev_status
    FROM public.spot_current_status
    WHERE spot_id = p_spot_id;

    v_is_escalation := (p_status IN ('SECURITY_ACTIVE', 'LOCKED_OFF'))
        AND (v_prev_status IS DISTINCT FROM p_status);

    INSERT INTO public.spot_status_reports (spot_id, user_id, status_type)
    VALUES (p_spot_id, v_caller, p_status);

    IF v_is_escalation THEN
        INSERT INTO public.notifications (user_id, type, title, body, data)
        SELECT
            sp.user_id,
            'spot_status_heads_up',
            CASE p_status
                WHEN 'SECURITY_ACTIVE' THEN 'Heads Up: Security Active'
                ELSE 'Heads Up: Spot Locked Off'
            END,
            v_spot_title || ' was just flagged as ' ||
                CASE p_status
                    WHEN 'SECURITY_ACTIVE' THEN 'having active security/police'
                    ELSE 'locked off / inaccessible'
                END || '.',
            jsonb_build_object('spot_id', p_spot_id, 'status_type', p_status)
        FROM public.saved_posts sp
        WHERE sp.post_id = p_spot_id AND sp.user_id <> v_caller;

        GET DIAGNOSTICS v_notified_count = ROW_COUNT;
    END IF;

    RETURN jsonb_build_object(
        'recorded', TRUE,
        'spot_id', p_spot_id,
        'status_type', p_status,
        'is_escalation', v_is_escalation,
        'notified_count', v_notified_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.report_spot_status(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.report_spot_status(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.spot_status_ttl_hours() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.spot_status_ttl_hours() TO authenticated;
