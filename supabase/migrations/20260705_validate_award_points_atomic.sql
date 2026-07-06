-- ============================================================================
-- Server-side validation for award_points_atomic
-- ============================================================================
-- Context: 20260705_revoke_client_points_writes.sql forced all balance
-- changes through the SECURITY DEFINER RPC award_points_atomic, but the RPC
-- itself still trusted the caller blindly: any authenticated user could call
-- it directly via the Supabase REST API and credit ANY amount to ANY user
-- for ANY transaction_type.
--
-- This migration replaces the function body with a per-transaction_type
-- allow-list validated against real server-side state. The signature is
-- unchanged (uuid, numeric, text, text, text), so no client code changes
-- and supabase_advisor_cleanup.sql's ALTER FUNCTION still matches.
--
-- Enforced rules (see per-type comments in the function body):
--   daily_login      self only; amount must match points_config formula
--                    against the server-visible daily_streaks row (streak
--                    capped by account age); max one per user per UTC day.
--   ad_watch         self only; amount must equal configured ad value;
--                    server-enforced cooldown matching the client's 2h
--                    cooldown (minus 5 min clock-skew allowance).
--   wager_entry      self only; amount must be negative (a stake deduction
--                    can never mint); resulting balance must be >= 0.
--   battle_win       caller must be a participant of the referenced battle;
--                    recipient must be its winner_id; amount must equal the
--                    battle's wager_amount; wager must have been accepted;
--                    only one payout per battle (replay-proof).
--   create_post      admin only; amount must equal configured value; the
--                    referenced map_post must exist and belong to the
--                    recipient; only one award per post (replay-proof).
--   admin_adjustment admin only (user_profiles.is_admin), any amount.
--   anything else    rejected.
--
-- All checks for a given recipient are serialized with a per-user advisory
-- transaction lock so concurrent calls cannot race past the duplicate /
-- cooldown checks.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Config: add the two award values that were previously hardcoded in the
--    Flutter client (4.2/ad in rewarded_ad_service.dart, 5.0/verified post in
--    admin_service.dart) to points_config, without overwriting existing keys.
-- ----------------------------------------------------------------------------
INSERT INTO public.app_settings (key, value)
VALUES (
    'points_config',
    '{
        "base_daily_points": 3.5,
        "streak_bonus_multiplier": 0.5,
        "first_login_bonus": 10.0,
        "post_xp": 100.0,
        "vote_xp": 1.0,
        "ad_watch_points": 4.2,
        "post_verify_points": 5.0
    }'::jsonb
) ON CONFLICT (key) DO NOTHING;

-- Merge defaults for the new keys into an existing row (existing keys win:
-- defaults are prepended, stored values override them).
UPDATE public.app_settings
SET value = '{"ad_watch_points": 4.2, "post_verify_points": 5.0}'::jsonb || value
WHERE key = 'points_config';

-- ----------------------------------------------------------------------------
-- 2. Indexes for the validation lookups (per-user/type recency and
--    per-type/reference replay checks).
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_point_transactions_user_type_created
    ON public.point_transactions (user_id, transaction_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_point_transactions_type_reference
    ON public.point_transactions (transaction_type, reference_id)
    WHERE reference_id IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 3. The hardened function.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.award_points_atomic(
    p_user_id UUID,
    p_amount NUMERIC,
    p_transaction_type TEXT,
    p_reference_id TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL
) RETURNS NUMERIC AS $$
DECLARE
    c_eps CONSTANT NUMERIC := 0.005;  -- tolerance for double -> numeric round-trips

    v_caller UUID := auth.uid();
    v_is_admin BOOLEAN := FALSE;
    v_new_balance NUMERIC;

    v_config JSONB;
    v_base_daily NUMERIC;
    v_streak_mult NUMERIC;
    v_first_login NUMERIC;
    v_ad_points NUMERIC;
    v_post_points NUMERIC;

    v_streak INTEGER;
    v_signup_at TIMESTAMPTZ;
    v_max_streak INTEGER;
    v_last_ad TIMESTAMPTZ;
    v_ref_uuid UUID;
    v_battle RECORD;
    v_post_owner UUID;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'award_points_atomic: not authenticated';
    END IF;
    IF p_user_id IS NULL OR p_amount IS NULL OR p_transaction_type IS NULL THEN
        RAISE EXCEPTION 'award_points_atomic: user, amount and type are required';
    END IF;

    -- Serialize all awards for this recipient so concurrent calls cannot
    -- race past the once-per-day / cooldown / replay checks below.
    PERFORM pg_advisory_xact_lock(hashtextextended('award_points_atomic:' || p_user_id::text, 0));

    SELECT COALESCE(up.is_admin, FALSE) INTO v_is_admin
    FROM public.user_profiles up
    WHERE up.id = v_caller;
    v_is_admin := COALESCE(v_is_admin, FALSE);

    SELECT value INTO v_config FROM public.app_settings WHERE key = 'points_config';
    v_base_daily  := COALESCE((v_config->>'base_daily_points')::NUMERIC, 3.5);
    v_streak_mult := COALESCE((v_config->>'streak_bonus_multiplier')::NUMERIC, 0.5);
    v_first_login := COALESCE((v_config->>'first_login_bonus')::NUMERIC, 10.0);
    v_ad_points   := COALESCE((v_config->>'ad_watch_points')::NUMERIC, 4.2);
    v_post_points := COALESCE((v_config->>'post_verify_points')::NUMERIC, 5.0);

    CASE p_transaction_type

    -- ------------------------------------------------------------------
    -- daily_login: self-award produced by PointsService.checkDailyStreak.
    -- The client upserts daily_streaks BEFORE awarding, so current_streak
    -- here is the new streak value. Legitimate amounts are exactly:
    --   first_login_bonus                      (first ever daily_login)
    --   base_daily_points                      (streak reset)
    --   base + current_streak * multiplier     (streak increment)
    -- The streak used for validation is capped by account age (a streak
    -- cannot exceed days-since-signup + 1), which bounds abuse of the
    -- still-client-writable daily_streaks table. Max one per UTC day.
    -- ------------------------------------------------------------------
    WHEN 'daily_login' THEN
        IF p_user_id <> v_caller THEN
            RAISE EXCEPTION 'daily_login can only be awarded to yourself';
        END IF;
        IF EXISTS (
            SELECT 1 FROM public.point_transactions pt
            WHERE pt.user_id = p_user_id
              AND pt.transaction_type = 'daily_login'
              AND pt.created_at >= date_trunc('day', now() AT TIME ZONE 'utc') AT TIME ZONE 'utc'
        ) THEN
            RAISE EXCEPTION 'daily_login already awarded today';
        END IF;

        SELECT ds.current_streak INTO v_streak
        FROM public.daily_streaks ds WHERE ds.user_id = p_user_id;
        v_streak := GREATEST(COALESCE(v_streak, 1), 1);

        SELECT u.created_at INTO v_signup_at FROM auth.users u WHERE u.id = p_user_id;
        v_max_streak := GREATEST(1,
            FLOOR(EXTRACT(EPOCH FROM (now() - COALESCE(v_signup_at, now()))) / 86400)::INTEGER + 2);
        v_streak := LEAST(v_streak, v_max_streak);

        IF NOT (
            (ABS(p_amount - v_first_login) < c_eps AND NOT EXISTS (
                SELECT 1 FROM public.point_transactions pt
                WHERE pt.user_id = p_user_id AND pt.transaction_type = 'daily_login'
            ))
            OR ABS(p_amount - v_base_daily) < c_eps
            OR ABS(p_amount - (v_base_daily + v_streak * v_streak_mult)) < c_eps
        ) THEN
            RAISE EXCEPTION 'daily_login amount % does not match configured award', p_amount;
        END IF;

    -- ------------------------------------------------------------------
    -- ad_watch: self-award from RewardedAdService. Amount must equal the
    -- configured per-ad value. The client enforces a 2-hour cooldown
    -- (RewardsProvider.adCooldown); enforce the same server-side with a
    -- 5-minute clock-skew allowance. No verifiable per-impression id is
    -- available (no AdMob SSV), so the cooldown is the replay bound.
    -- ------------------------------------------------------------------
    WHEN 'ad_watch' THEN
        IF p_user_id <> v_caller THEN
            RAISE EXCEPTION 'ad_watch can only be awarded to yourself';
        END IF;
        IF ABS(p_amount - v_ad_points) >= c_eps THEN
            RAISE EXCEPTION 'ad_watch amount % does not match configured award', p_amount;
        END IF;
        SELECT MAX(pt.created_at) INTO v_last_ad
        FROM public.point_transactions pt
        WHERE pt.user_id = p_user_id AND pt.transaction_type = 'ad_watch';
        IF v_last_ad IS NOT NULL AND now() - v_last_ad < INTERVAL '115 minutes' THEN
            RAISE EXCEPTION 'ad_watch cooldown has not expired';
        END IF;

    -- ------------------------------------------------------------------
    -- wager_entry: stake deduction when creating or accepting a wagered
    -- battle. Strictly negative and self-only, so this type can never
    -- mint points; the balance may not go below zero (checked after the
    -- wallet update below).
    -- ------------------------------------------------------------------
    WHEN 'wager_entry' THEN
        IF p_user_id <> v_caller THEN
            RAISE EXCEPTION 'wager_entry can only be applied to yourself';
        END IF;
        IF p_amount >= 0 THEN
            RAISE EXCEPTION 'wager_entry amount must be negative';
        END IF;

    -- ------------------------------------------------------------------
    -- battle_win: wager payout on battle completion. Verified against the
    -- battles row: caller must be a participant, recipient must be the
    -- recorded winner, amount must equal the battle's wager_amount, the
    -- wager must have been accepted (i.e. both sides were debited), and
    -- each battle pays out at most once.
    -- ------------------------------------------------------------------
    WHEN 'battle_win' THEN
        IF p_reference_id IS NULL THEN
            RAISE EXCEPTION 'battle_win requires the battle id as reference_id';
        END IF;
        BEGIN
            v_ref_uuid := p_reference_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'battle_win reference_id is not a valid battle id';
        END;

        SELECT b.player1_id, b.player2_id, b.winner_id, b.wager_amount, b.wager_accepted
        INTO v_battle
        FROM public.battles b WHERE b.id = v_ref_uuid;

        IF v_battle IS NULL THEN
            RAISE EXCEPTION 'battle_win: battle % not found', p_reference_id;
        END IF;
        IF v_caller <> v_battle.player1_id AND v_caller <> v_battle.player2_id THEN
            RAISE EXCEPTION 'battle_win: caller is not a participant of this battle';
        END IF;
        IF v_battle.winner_id IS NULL OR p_user_id <> v_battle.winner_id THEN
            RAISE EXCEPTION 'battle_win: recipient is not the recorded winner';
        END IF;
        IF COALESCE(v_battle.wager_amount, 0) <= 0 OR NOT COALESCE(v_battle.wager_accepted, FALSE) THEN
            RAISE EXCEPTION 'battle_win: battle has no accepted wager';
        END IF;
        IF ABS(p_amount - v_battle.wager_amount) >= c_eps THEN
            RAISE EXCEPTION 'battle_win amount % does not match battle wager', p_amount;
        END IF;
        IF EXISTS (
            SELECT 1 FROM public.point_transactions pt
            WHERE pt.transaction_type = 'battle_win' AND pt.reference_id = p_reference_id
        ) THEN
            RAISE EXCEPTION 'battle_win already paid out for battle %', p_reference_id;
        END IF;

    -- ------------------------------------------------------------------
    -- create_post: admin verifies a map post and the creator is awarded a
    -- fixed configured amount, once per post.
    -- ------------------------------------------------------------------
    WHEN 'create_post' THEN
        IF NOT v_is_admin THEN
            RAISE EXCEPTION 'create_post awards require an admin caller';
        END IF;
        IF p_reference_id IS NULL THEN
            RAISE EXCEPTION 'create_post requires the post id as reference_id';
        END IF;
        BEGIN
            v_ref_uuid := p_reference_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'create_post reference_id is not a valid post id';
        END;
        SELECT mp.user_id INTO v_post_owner FROM public.map_posts mp WHERE mp.id = v_ref_uuid;
        IF v_post_owner IS NULL THEN
            RAISE EXCEPTION 'create_post: post % not found', p_reference_id;
        END IF;
        IF v_post_owner <> p_user_id THEN
            RAISE EXCEPTION 'create_post: recipient does not own the referenced post';
        END IF;
        IF ABS(p_amount - v_post_points) >= c_eps THEN
            RAISE EXCEPTION 'create_post amount % does not match configured award', p_amount;
        END IF;
        IF EXISTS (
            SELECT 1 FROM public.point_transactions pt
            WHERE pt.transaction_type = 'create_post' AND pt.reference_id = p_reference_id
        ) THEN
            RAISE EXCEPTION 'create_post already awarded for post %', p_reference_id;
        END IF;

    -- ------------------------------------------------------------------
    -- admin_adjustment: manual add/remove from the admin console. Gated on
    -- user_profiles.is_admin, same check as admin_reverse_point_transaction.
    -- ------------------------------------------------------------------
    WHEN 'admin_adjustment' THEN
        IF NOT v_is_admin THEN
            RAISE EXCEPTION 'admin_adjustment requires an admin caller';
        END IF;

    ELSE
        RAISE EXCEPTION 'transaction_type "%" is not allowed', p_transaction_type;
    END CASE;

    -- Validated: apply atomically (unchanged from the original function).
    INSERT INTO public.user_wallets (user_id, balance, updated_at)
    VALUES (p_user_id, p_amount, NOW())
    ON CONFLICT (user_id) DO UPDATE
        SET balance = user_wallets.balance + p_amount, updated_at = NOW()
    RETURNING balance INTO v_new_balance;

    -- A stake may never overdraw the wallet (raising here rolls back both
    -- the wallet update and the transaction insert).
    IF p_transaction_type = 'wager_entry' AND v_new_balance < 0 THEN
        RAISE EXCEPTION 'wager_entry: insufficient balance';
    END IF;

    INSERT INTO public.point_transactions (user_id, amount, transaction_type, reference_id, description, created_at)
    VALUES (p_user_id, p_amount, p_transaction_type, p_reference_id, p_description, NOW());

    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ----------------------------------------------------------------------------
-- 4. Grants: authenticated users only; never anon / PUBLIC.
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.award_points_atomic(UUID, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_points_atomic(UUID, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
