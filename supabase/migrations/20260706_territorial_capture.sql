-- ============================================================================
-- Territorial Capture ("Borough Turf" / "Capture and Defend")
-- ============================================================================
-- Implements the vault-specced territorial system:
--   * Static borough polygons (London boroughs, simplified placeholder
--     geometry — replace with real GLA GeoJSON rings later).
--   * Each borough can be owned by one Crew (minimal crew concept introduced
--     here: crews + crew_members, cap 6 — a full Crew Engine is out of scope).
--   * Defense Threshold: reigning crew's defense_score grows with their
--     activity inside the borough.
--   * Destabilization Metric: activity NOT from the reigning crew accumulates
--     as destabilization_score against the threshold, and feeds the Map Score
--     ("Destabilization Impact" component) via destabilization_xp.
--   * Capture: when destabilization_score >= defense_score the borough flips
--     to the rival crew with the most qualifying activity since the last
--     capture. Solo (crew-less) skaters destabilize but cannot own turf.
--
-- Server-authoritative: all writes go through SECURITY DEFINER RPCs with
-- per-borough / per-user advisory locks (same pattern as
-- 20260705_validate_award_points_atomic.sql). Clients only ever SELECT.
--
-- All numeric knobs live in app_settings key 'territory_config' and are
-- TUNABLE PLACEHOLDERS — the docs specify the mechanic, not the numbers.
--
-- Idempotent: safe to run multiple times. Do not run against production
-- without review; this file is intentionally not applied anywhere yet.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tunable configuration (existing keys win; defaults are prepended).
-- ----------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value)
VALUES (
    'territory_config',
    '{
        "base_defense": 100.0,
        "clip_weight": 10.0,
        "spot_weight": 25.0,
        "defend_multiplier": 1.0,
        "daily_user_event_cap": 10,
        "crew_member_cap": 6
    }'::jsonb
) ON CONFLICT (key) DO NOTHING;

UPDATE public.app_settings
SET value = '{
        "base_defense": 100.0,
        "clip_weight": 10.0,
        "spot_weight": 25.0,
        "defend_multiplier": 1.0,
        "daily_user_event_cap": 10,
        "crew_member_cap": 6
    }'::jsonb || value
WHERE key = 'territory_config';

-- Map Score integration: per-destabilizing-event XP ("Destabilization Impact",
-- the 15% component of the documented Map Score formula, expressed in the
-- codebase's existing additive-XP model).
UPDATE public.app_settings
SET value = '{"destabilization_xp": 15.0}'::jsonb || value
WHERE key = 'points_config';

-- ----------------------------------------------------------------------------
-- 2. Tables
-- ----------------------------------------------------------------------------

-- Minimal crew concept (prerequisite for turf ownership; full Crew Engine is
-- a separate feature). One crew per user, cap enforced in join/create RPCs.
CREATE TABLE IF NOT EXISTS public.crews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    color_hex TEXT NOT NULL DEFAULT '#00FF41',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.crew_members (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    crew_id UUID NOT NULL REFERENCES public.crews(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member', -- 'leader' | 'member'
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_crew_members_crew_id ON public.crew_members(crew_id);

-- Static borough turf lines. Polygon is a JSONB array of [lat, lng] pairs
-- (closed ring implied; last point connects back to first). No PostGIS
-- dependency — point-in-polygon is done in plpgsql below.
CREATE TABLE IF NOT EXISTS public.boroughs (
    id TEXT PRIMARY KEY,          -- slug, e.g. 'southwark'
    name TEXT NOT NULL,
    polygon JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Current ownership + live scores per borough.
CREATE TABLE IF NOT EXISTS public.borough_ownership (
    borough_id TEXT PRIMARY KEY REFERENCES public.boroughs(id) ON DELETE CASCADE,
    owning_crew_id UUID REFERENCES public.crews(id) ON DELETE SET NULL,
    defense_score NUMERIC NOT NULL DEFAULT 100.0,
    destabilization_score NUMERIC NOT NULL DEFAULT 0.0,
    last_captured_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Ledger of every activity that fed defense/destabilization, plus capture
-- records. This is what powers the B2B "who dominates borough X" query.
CREATE TABLE IF NOT EXISTS public.territory_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    borough_id TEXT NOT NULL REFERENCES public.boroughs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    crew_id UUID REFERENCES public.crews(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL, -- 'spot_created' | 'clip_upload' | 'capture'
    weight NUMERIC NOT NULL DEFAULT 0,
    is_destabilizing BOOLEAN NOT NULL DEFAULT FALSE,
    reference_id TEXT,        -- map_posts.id / spot_videos.id that triggered it
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Replay-proofing: one territory event per (type, source row).
CREATE UNIQUE INDEX IF NOT EXISTS idx_territory_events_type_reference
    ON public.territory_events (event_type, reference_id)
    WHERE reference_id IS NOT NULL;

-- Dominance / recalculation lookups.
CREATE INDEX IF NOT EXISTS idx_territory_events_borough_crew_created
    ON public.territory_events (borough_id, crew_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_territory_events_user_destab
    ON public.territory_events (user_id) WHERE is_destabilizing;

-- ----------------------------------------------------------------------------
-- 3. RLS: authenticated read-only. All writes via SECURITY DEFINER RPCs.
-- ----------------------------------------------------------------------------
ALTER TABLE public.crews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crew_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boroughs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.borough_ownership ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.territory_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "crews_select_authenticated" ON public.crews;
CREATE POLICY "crews_select_authenticated" ON public.crews
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "crew_members_select_authenticated" ON public.crew_members;
CREATE POLICY "crew_members_select_authenticated" ON public.crew_members
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "boroughs_select_authenticated" ON public.boroughs;
CREATE POLICY "boroughs_select_authenticated" ON public.boroughs
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "borough_ownership_select_authenticated" ON public.borough_ownership;
CREATE POLICY "borough_ownership_select_authenticated" ON public.borough_ownership
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "territory_events_select_authenticated" ON public.territory_events;
CREATE POLICY "territory_events_select_authenticated" ON public.territory_events
    FOR SELECT TO authenticated USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.crews,
                                public.crew_members,
                                public.boroughs,
                                public.borough_ownership,
                                public.territory_events
    FROM anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4. Seed boroughs (PLACEHOLDER GEOMETRY — coarse hand-drawn rings around
--    eight inner-London boroughs; replace with real borough boundary GeoJSON
--    before launch. Rings may slightly overlap; find_borough_for_point
--    resolves ties by borough id order.)
-- ----------------------------------------------------------------------------
INSERT INTO public.boroughs (id, name, polygon) VALUES
('camden', 'Camden',
 '[[51.5735,-0.2135],[51.5720,-0.1425],[51.5510,-0.1050],[51.5325,-0.1070],[51.5170,-0.1290],[51.5240,-0.1750],[51.5480,-0.2000]]'::jsonb),
('hackney', 'Hackney',
 '[[51.5770,-0.0870],[51.5745,-0.0165],[51.5310,-0.0180],[51.5210,-0.0560],[51.5280,-0.0830],[51.5450,-0.0800]]'::jsonb),
('islington', 'Islington',
 '[[51.5750,-0.1425],[51.5750,-0.0870],[51.5450,-0.0800],[51.5280,-0.0950],[51.5170,-0.1050],[51.5325,-0.1070],[51.5510,-0.1050]]'::jsonb),
('lambeth', 'Lambeth',
 '[[51.5090,-0.1220],[51.5080,-0.1040],[51.4720,-0.1110],[51.4310,-0.0900],[51.4110,-0.1150],[51.4210,-0.1450],[51.4650,-0.1350]]'::jsonb),
('lewisham', 'Lewisham',
 '[[51.4900,-0.0470],[51.4910,-0.0100],[51.4600,0.0060],[51.4210,-0.0100],[51.4110,-0.0400],[51.4210,-0.0650],[51.4600,-0.0450]]'::jsonb),
('southwark', 'Southwark',
 '[[51.5080,-0.1040],[51.5050,-0.0780],[51.4900,-0.0470],[51.4600,-0.0450],[51.4210,-0.0650],[51.4310,-0.0900],[51.4720,-0.1110]]'::jsonb),
('tower_hamlets', 'Tower Hamlets',
 '[[51.5310,-0.0830],[51.5310,-0.0180],[51.5290,0.0090],[51.5070,0.0090],[51.4870,-0.0100],[51.5100,-0.0790]]'::jsonb),
('westminster', 'Westminster',
 '[[51.5395,-0.2135],[51.5310,-0.1450],[51.5170,-0.1120],[51.4990,-0.1120],[51.4855,-0.1450],[51.4870,-0.1900],[51.5130,-0.2190]]'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- Every borough starts unowned at the base defense threshold.
INSERT INTO public.borough_ownership (borough_id, defense_score)
SELECT b.id,
       COALESCE((
           SELECT (s.value->>'base_defense')::NUMERIC
           FROM public.app_settings s WHERE s.key = 'territory_config'
       ), 100.0)
FROM public.boroughs b
ON CONFLICT (borough_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. Geometry helpers (no PostGIS: ray-casting over the JSONB ring).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.territory_point_in_polygon(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_polygon JSONB
) RETURNS BOOLEAN AS $$
DECLARE
    v_n INTEGER;
    i INTEGER;
    j INTEGER;
    lat_i DOUBLE PRECISION; lng_i DOUBLE PRECISION;
    lat_j DOUBLE PRECISION; lng_j DOUBLE PRECISION;
    v_inside BOOLEAN := FALSE;
BEGIN
    IF p_polygon IS NULL OR jsonb_typeof(p_polygon) <> 'array' THEN
        RETURN FALSE;
    END IF;
    v_n := jsonb_array_length(p_polygon);
    IF v_n < 3 THEN
        RETURN FALSE;
    END IF;

    j := v_n - 1;
    FOR i IN 0..(v_n - 1) LOOP
        lat_i := (p_polygon->i->>0)::DOUBLE PRECISION;
        lng_i := (p_polygon->i->>1)::DOUBLE PRECISION;
        lat_j := (p_polygon->j->>0)::DOUBLE PRECISION;
        lng_j := (p_polygon->j->>1)::DOUBLE PRECISION;

        IF ((lat_i > p_lat) <> (lat_j > p_lat)) AND
           (p_lng < (lng_j - lng_i) * (p_lat - lat_i) / (lat_j - lat_i) + lng_i) THEN
            v_inside := NOT v_inside;
        END IF;
        j := i;
    END LOOP;
    RETURN v_inside;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION public.find_borough_for_point(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION
) RETURNS TEXT AS $$
    SELECT b.id
    FROM public.boroughs b
    WHERE public.territory_point_in_polygon(p_lat, p_lng, b.polygon)
    ORDER BY b.id
    LIMIT 1;
$$ LANGUAGE sql STABLE;

-- ----------------------------------------------------------------------------
-- 6. Crew RPCs (minimal: create / join / leave, cap enforced server-side).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_crew(
    p_name TEXT,
    p_color_hex TEXT DEFAULT '#00FF41'
) RETURNS UUID AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_crew_id UUID;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'create_crew: not authenticated';
    END IF;
    IF p_name IS NULL OR length(trim(p_name)) < 2 OR length(trim(p_name)) > 32 THEN
        RAISE EXCEPTION 'create_crew: name must be 2-32 characters';
    END IF;
    IF p_color_hex IS NULL OR p_color_hex !~ '^#[0-9a-fA-F]{6}$' THEN
        RAISE EXCEPTION 'create_crew: color must be a #RRGGBB hex value';
    END IF;

    -- Serialize per-user so a double-tap cannot create/join twice.
    PERFORM pg_advisory_xact_lock(hashtextextended('crew_membership:' || v_caller::text, 0));

    IF EXISTS (SELECT 1 FROM public.crew_members cm WHERE cm.user_id = v_caller) THEN
        RAISE EXCEPTION 'create_crew: you are already in a crew';
    END IF;

    INSERT INTO public.crews (name, color_hex, created_by)
    VALUES (trim(p_name), lower(p_color_hex), v_caller)
    RETURNING id INTO v_crew_id;

    INSERT INTO public.crew_members (user_id, crew_id, role)
    VALUES (v_caller, v_crew_id, 'leader');

    RETURN v_crew_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.join_crew(p_crew_id UUID)
RETURNS VOID AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_cap INTEGER;
    v_count INTEGER;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'join_crew: not authenticated';
    END IF;
    IF p_crew_id IS NULL THEN
        RAISE EXCEPTION 'join_crew: crew id is required';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended('crew_membership:' || v_caller::text, 0));
    -- Serialize per-crew so concurrent joins cannot blow past the cap.
    PERFORM pg_advisory_xact_lock(hashtextextended('crew_roster:' || p_crew_id::text, 0));

    IF EXISTS (SELECT 1 FROM public.crew_members cm WHERE cm.user_id = v_caller) THEN
        RAISE EXCEPTION 'join_crew: you are already in a crew';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.crews c WHERE c.id = p_crew_id) THEN
        RAISE EXCEPTION 'join_crew: crew % not found', p_crew_id;
    END IF;

    SELECT COALESCE((s.value->>'crew_member_cap')::INTEGER, 6) INTO v_cap
    FROM public.app_settings s WHERE s.key = 'territory_config';
    v_cap := COALESCE(v_cap, 6);

    SELECT COUNT(*) INTO v_count FROM public.crew_members cm WHERE cm.crew_id = p_crew_id;
    IF v_count >= v_cap THEN
        RAISE EXCEPTION 'join_crew: crew is full (cap %)', v_cap;
    END IF;

    INSERT INTO public.crew_members (user_id, crew_id, role)
    VALUES (v_caller, p_crew_id, 'member');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.leave_crew()
RETURNS VOID AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_crew_id UUID;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'leave_crew: not authenticated';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended('crew_membership:' || v_caller::text, 0));

    DELETE FROM public.crew_members cm
    WHERE cm.user_id = v_caller
    RETURNING cm.crew_id INTO v_crew_id;

    IF v_crew_id IS NULL THEN
        RAISE EXCEPTION 'leave_crew: you are not in a crew';
    END IF;

    -- Dissolve empty crews; borough_ownership.owning_crew_id nulls out via FK.
    DELETE FROM public.crews c
    WHERE c.id = v_crew_id
      AND NOT EXISTS (SELECT 1 FROM public.crew_members cm WHERE cm.crew_id = c.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ----------------------------------------------------------------------------
-- 7. record_territory_activity: the single write path for the whole system.
--    Coordinates are NEVER taken from the client — they are resolved from the
--    referenced map_posts / spot_videos row, which the caller must own.
--
--    p_activity_type:
--      'spot_created' — p_reference_id is a map_posts.id owned by the caller
--                       (New Spot Discovery; heaviest weight).
--      'clip_upload'  — p_reference_id is a spot_videos.id submitted by the
--                       caller; location comes from the parent spot.
--
--    Behaviour:
--      * caller in the reigning crew  -> weight feeds defense_score
--      * anyone else (rival crew OR solo) -> weight feeds destabilization_score
--        and awards destabilization_xp to the caller's map_score
--        ("Destabilization Impact" Map Score component)
--      * when destabilization_score >= defense_score, the rival crew with the
--        most destabilizing weight since the last capture takes ownership;
--        scores reset (defense = max(base, challenger activity), destab = 0).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_territory_activity(
    p_reference_id UUID,
    p_activity_type TEXT
) RETURNS JSONB AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_config JSONB;
    v_base_defense NUMERIC;
    v_clip_weight NUMERIC;
    v_spot_weight NUMERIC;
    v_defend_mult NUMERIC;
    v_daily_cap INTEGER;
    v_destab_xp NUMERIC;

    v_lat DOUBLE PRECISION;
    v_lng DOUBLE PRECISION;
    v_weight NUMERIC;
    v_borough_id TEXT;
    v_crew_id UUID;
    v_owner RECORD;
    v_is_destab BOOLEAN;
    v_today_count INTEGER;
    v_captured BOOLEAN := FALSE;
    v_challenger UUID;
    v_challenger_sum NUMERIC;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'record_territory_activity: not authenticated';
    END IF;
    IF p_reference_id IS NULL OR p_activity_type IS NULL THEN
        RAISE EXCEPTION 'record_territory_activity: reference and type are required';
    END IF;

    SELECT value INTO v_config FROM public.app_settings WHERE key = 'territory_config';
    v_base_defense := COALESCE((v_config->>'base_defense')::NUMERIC, 100.0);
    v_clip_weight  := COALESCE((v_config->>'clip_weight')::NUMERIC, 10.0);
    v_spot_weight  := COALESCE((v_config->>'spot_weight')::NUMERIC, 25.0);
    v_defend_mult  := COALESCE((v_config->>'defend_multiplier')::NUMERIC, 1.0);
    v_daily_cap    := COALESCE((v_config->>'daily_user_event_cap')::INTEGER, 10);

    SELECT COALESCE((s.value->>'destabilization_xp')::NUMERIC, 15.0) INTO v_destab_xp
    FROM public.app_settings s WHERE s.key = 'points_config';
    v_destab_xp := COALESCE(v_destab_xp, 15.0);

    -- Resolve the activity to server-side coordinates the caller cannot spoof.
    CASE p_activity_type
    WHEN 'spot_created' THEN
        SELECT mp.latitude, mp.longitude INTO v_lat, v_lng
        FROM public.map_posts mp
        WHERE mp.id = p_reference_id AND mp.user_id = v_caller;
        IF v_lat IS NULL THEN
            RAISE EXCEPTION 'record_territory_activity: post not found or not yours';
        END IF;
        v_weight := v_spot_weight;
    WHEN 'clip_upload' THEN
        SELECT mp.latitude, mp.longitude INTO v_lat, v_lng
        FROM public.spot_videos sv
        JOIN public.map_posts mp ON mp.id = sv.spot_id
        WHERE sv.id = p_reference_id AND sv.submitted_by = v_caller;
        IF v_lat IS NULL THEN
            RAISE EXCEPTION 'record_territory_activity: clip not found or not yours';
        END IF;
        v_weight := v_clip_weight;
    ELSE
        RAISE EXCEPTION 'record_territory_activity: activity_type "%" is not allowed', p_activity_type;
    END CASE;

    v_borough_id := public.find_borough_for_point(v_lat, v_lng);
    IF v_borough_id IS NULL THEN
        -- Outside all turf lines: nothing to record, not an error.
        RETURN jsonb_build_object('recorded', FALSE, 'reason', 'outside_turf');
    END IF;

    -- Serialize all mutations for this borough (capture race protection).
    PERFORM pg_advisory_xact_lock(hashtextextended('territory:' || v_borough_id, 0));

    -- Replay-proof: one event per source row.
    IF EXISTS (
        SELECT 1 FROM public.territory_events te
        WHERE te.event_type = p_activity_type
          AND te.reference_id = p_reference_id::TEXT
    ) THEN
        RETURN jsonb_build_object('recorded', FALSE, 'reason', 'already_recorded');
    END IF;

    -- Per-user daily grind cap inside a single borough.
    SELECT COUNT(*) INTO v_today_count
    FROM public.territory_events te
    WHERE te.user_id = v_caller
      AND te.borough_id = v_borough_id
      AND te.event_type <> 'capture'
      AND te.created_at >= date_trunc('day', now() AT TIME ZONE 'utc') AT TIME ZONE 'utc';
    IF v_today_count >= v_daily_cap THEN
        RETURN jsonb_build_object('recorded', FALSE, 'reason', 'daily_cap');
    END IF;

    SELECT cm.crew_id INTO v_crew_id
    FROM public.crew_members cm WHERE cm.user_id = v_caller;

    -- Ensure the ownership row exists (boroughs seeded later still work).
    INSERT INTO public.borough_ownership (borough_id, defense_score)
    VALUES (v_borough_id, v_base_defense)
    ON CONFLICT (borough_id) DO NOTHING;

    SELECT * INTO v_owner FROM public.borough_ownership bo
    WHERE bo.borough_id = v_borough_id FOR UPDATE;

    v_is_destab := (v_owner.owning_crew_id IS NULL)
                OR (v_crew_id IS NULL)
                OR (v_crew_id <> v_owner.owning_crew_id);

    INSERT INTO public.territory_events
        (borough_id, user_id, crew_id, event_type, weight, is_destabilizing, reference_id)
    VALUES
        (v_borough_id, v_caller, v_crew_id, p_activity_type, v_weight, v_is_destab, p_reference_id::TEXT);

    IF v_is_destab THEN
        UPDATE public.borough_ownership
        SET destabilization_score = destabilization_score + v_weight,
            updated_at = now()
        WHERE borough_id = v_borough_id;

        -- Map Score "Destabilization Impact" component: destabilizing activity
        -- earns map XP (kept consistent by recalculate_map_score below).
        INSERT INTO public.user_scores (user_id, map_score)
        VALUES (v_caller, v_destab_xp)
        ON CONFLICT (user_id) DO UPDATE
            SET map_score = user_scores.map_score + v_destab_xp;
        INSERT INTO public.xp_history (user_id, score_type, amount, reason)
        VALUES (v_caller, 'map', v_destab_xp, 'Destabilization Impact');
    ELSE
        UPDATE public.borough_ownership
        SET defense_score = defense_score + v_weight * v_defend_mult,
            updated_at = now()
        WHERE borough_id = v_borough_id;
    END IF;

    -- Re-read and check the flip condition.
    SELECT * INTO v_owner FROM public.borough_ownership bo
    WHERE bo.borough_id = v_borough_id;

    IF v_owner.destabilization_score >= v_owner.defense_score THEN
        -- Challenger = crew with the most destabilizing weight since the last
        -- capture. Solo skaters destabilize but cannot take ownership.
        SELECT te.crew_id, SUM(te.weight) INTO v_challenger, v_challenger_sum
        FROM public.territory_events te
        WHERE te.borough_id = v_borough_id
          AND te.is_destabilizing
          AND te.crew_id IS NOT NULL
          AND (v_owner.owning_crew_id IS NULL OR te.crew_id <> v_owner.owning_crew_id)
          AND te.created_at > COALESCE(v_owner.last_captured_at, '-infinity'::TIMESTAMPTZ)
        GROUP BY te.crew_id
        ORDER BY SUM(te.weight) DESC, MIN(te.created_at) ASC
        LIMIT 1;

        IF v_challenger IS NOT NULL THEN
            UPDATE public.borough_ownership
            SET owning_crew_id = v_challenger,
                defense_score = GREATEST(v_base_defense, COALESCE(v_challenger_sum, 0)),
                destabilization_score = 0,
                last_captured_at = now(),
                updated_at = now()
            WHERE borough_id = v_borough_id;

            INSERT INTO public.territory_events
                (borough_id, user_id, crew_id, event_type, weight, is_destabilizing, reference_id)
            VALUES
                (v_borough_id, v_caller, v_challenger, 'capture', 0, FALSE, NULL);

            v_captured := TRUE;
        END IF;
        -- No eligible crew: the borough stays fully destabilized ("ready to
        -- flip") until a crewed rival posts qualifying activity.
    END IF;

    SELECT * INTO v_owner FROM public.borough_ownership bo
    WHERE bo.borough_id = v_borough_id;

    RETURN jsonb_build_object(
        'recorded', TRUE,
        'borough_id', v_borough_id,
        'is_destabilizing', v_is_destab,
        'captured', v_captured,
        'owning_crew_id', v_owner.owning_crew_id,
        'defense_score', v_owner.defense_score,
        'destabilization_score', v_owner.destabilization_score
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ----------------------------------------------------------------------------
-- 8. Read models
-- ----------------------------------------------------------------------------
-- Live borough state for the map layer (Fragile State = fragility 0..1;
-- opacity on the client fades as fragility rises).
CREATE OR REPLACE VIEW public.borough_states
WITH (security_invoker = on) AS
SELECT
    b.id AS borough_id,
    b.name,
    b.polygon,
    bo.owning_crew_id,
    c.name AS owning_crew_name,
    c.color_hex AS owning_crew_color,
    COALESCE(bo.defense_score, 0) AS defense_score,
    COALESCE(bo.destabilization_score, 0) AS destabilization_score,
    CASE
        WHEN COALESCE(bo.defense_score, 0) <= 0 THEN
            CASE WHEN COALESCE(bo.destabilization_score, 0) > 0 THEN 1.0 ELSE 0.0 END
        ELSE LEAST(bo.destabilization_score / bo.defense_score, 1.0)
    END AS fragility,
    bo.last_captured_at
FROM public.boroughs b
LEFT JOIN public.borough_ownership bo ON bo.borough_id = b.id
LEFT JOIN public.crews c ON c.id = bo.owning_crew_id;

-- B2B "Territorial Dominance" support: which crew (and how hard) dominates a
-- borough. No brand UI yet — schema-level support only.
CREATE OR REPLACE VIEW public.borough_crew_dominance
WITH (security_invoker = on) AS
SELECT
    te.borough_id,
    te.crew_id,
    c.name AS crew_name,
    COUNT(*) AS event_count,
    SUM(te.weight) AS total_weight,
    MAX(te.created_at) AS last_activity_at
FROM public.territory_events te
LEFT JOIN public.crews c ON c.id = te.crew_id
WHERE te.event_type <> 'capture'
GROUP BY te.borough_id, te.crew_id, c.name;

GRANT SELECT ON public.borough_states, public.borough_crew_dominance TO authenticated;
REVOKE ALL ON public.borough_states, public.borough_crew_dominance FROM anon;

-- ----------------------------------------------------------------------------
-- 9. Map Score integration: recalculate_map_score now includes the
--    "Destabilization Impact" component (destabilizing territory events *
--    destabilization_xp) on top of the existing posts/votes XP. Body is
--    otherwise identical to 20260705_validate_streaks_and_scores.sql §8.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalculate_map_score(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_is_admin BOOLEAN := FALSE;
    v_config JSONB;
    v_post_xp NUMERIC;
    v_vote_xp NUMERIC;
    v_destab_xp NUMERIC;
    v_post_count INTEGER;
    v_vote_score NUMERIC;
    v_destab_count INTEGER;
    v_total NUMERIC;
    v_old NUMERIC;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'recalculate_map_score: not authenticated';
    END IF;
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'recalculate_map_score: user id is required';
    END IF;

    SELECT COALESCE(up.is_admin, FALSE) INTO v_is_admin
    FROM public.user_profiles up WHERE up.id = v_caller;
    IF p_user_id <> v_caller AND NOT COALESCE(v_is_admin, FALSE) THEN
        RAISE EXCEPTION 'recalculate_map_score: can only recalculate your own score';
    END IF;

    SELECT value INTO v_config FROM public.app_settings WHERE key = 'points_config';
    v_post_xp   := COALESCE((v_config->>'post_xp')::NUMERIC, 100.0);
    v_vote_xp   := COALESCE((v_config->>'vote_xp')::NUMERIC, 1.0);
    v_destab_xp := COALESCE((v_config->>'destabilization_xp')::NUMERIC, 15.0);

    SELECT COUNT(*), COALESCE(SUM(mp.vote_score), 0)
    INTO v_post_count, v_vote_score
    FROM public.map_posts mp WHERE mp.user_id = p_user_id;

    SELECT COUNT(*) INTO v_destab_count
    FROM public.territory_events te
    WHERE te.user_id = p_user_id AND te.is_destabilizing;

    v_total := GREATEST(
        v_post_count * v_post_xp
        + v_vote_score * v_vote_xp
        + v_destab_count * v_destab_xp,
        0);

    SELECT us.map_score INTO v_old FROM public.user_scores us
    WHERE us.user_id = p_user_id FOR UPDATE;
    v_old := COALESCE(v_old, 0);

    INSERT INTO public.user_scores (user_id, map_score)
    VALUES (p_user_id, v_total)
    ON CONFLICT (user_id) DO UPDATE SET map_score = EXCLUDED.map_score;

    IF v_total <> v_old THEN
        INSERT INTO public.xp_history (user_id, score_type, amount, reason)
        VALUES (p_user_id, 'map', v_total - v_old, 'XP Recalculation');
    END IF;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ----------------------------------------------------------------------------
-- 10. Grants: authenticated only; never anon / PUBLIC.
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.create_crew(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_crew(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.join_crew(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_crew(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.leave_crew() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leave_crew() TO authenticated;

REVOKE ALL ON FUNCTION public.record_territory_activity(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_territory_activity(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.recalculate_map_score(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recalculate_map_score(UUID) TO authenticated;

-- Geometry helpers are harmless reads but keep them tight anyway.
REVOKE ALL ON FUNCTION public.territory_point_in_polygon(DOUBLE PRECISION, DOUBLE PRECISION, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.territory_point_in_polygon(DOUBLE PRECISION, DOUBLE PRECISION, JSONB) TO authenticated;
REVOKE ALL ON FUNCTION public.find_borough_for_point(DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_borough_for_point(DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
