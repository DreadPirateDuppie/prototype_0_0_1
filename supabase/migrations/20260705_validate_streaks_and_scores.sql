-- ============================================================================
-- Revoke direct client write access to daily_streaks / user_scores
-- (and xp_history), replace with validated SECURITY DEFINER RPCs
-- ============================================================================
-- Context: same shape of bug as 20260705_revoke_client_points_writes.sql.
-- init.sql / supabase_advisor_cleanup.sql give clients owner-scoped
-- INSERT/UPDATE policies on daily_streaks ("Daily streaks access" FOR ALL)
-- and user_scores ("User scores write owner" / "User scores update owner"),
-- plus the blanket "GRANT ALL ON ALL TABLES IN SCHEMA public TO
-- authenticated". Any authenticated client can therefore write an arbitrary
-- value into its own row:
--
--   * daily_streaks.current_streak — this is MONEY-ADJACENT. The hardened
--     award_points_atomic (20260705_validate_award_points_atomic.sql)
--     validates the daily_login amount as base + current_streak * multiplier
--     read from daily_streaks. A forged current_streak therefore inflates
--     the daily_login payout, partially undermining that fix. (Its
--     account-age cap on the streak bounded the damage; after this
--     migration that cap becomes belt-and-braces, because the streak value
--     itself is server-computed and can only move +1 per UTC day.)
--
--   * user_scores.player_score / ranking_score / map_score — leaderboard
--     and matchmaking standing (get_battle_leaderboard reads player_score /
--     ranking_score). Not directly redeemable for points, but freely
--     forgeable to any value.
--
--   * xp_history — also closed here, for two reasons: (a) the RPCs below
--     use deterministic xp_history rows ('battle_result:<id>',
--     'verification_ranking:<id>') as replay guards, which only works if
--     clients cannot insert or delete guard rows ("XP history access" was
--     FOR ALL with owner USING, i.e. owner DELETE was allowed); (b) after
--     this migration no legitimate client write to xp_history remains
--     (PointsService.logXpHistory's callers are all replaced by RPCs).
--
-- Legitimate client write patterns replaced (from the Flutter call sites):
--   PointsService.checkDailyStreak/_updateStreak  -> record_daily_login()
--       first login = 1, consecutive day = +1, missed day = reset to 1,
--       longest = max(longest, current); one state change per UTC day.
--   BattleAnalyticsService.updatePlayerScoreForBattle
--                                                 -> apply_battle_player_scores()
--       winner +10, loser -(5 + 2 * letters collected), clamped 0..1000,
--       once per completed battle.
--   VerificationService.updateRankingScores       -> apply_verification_ranking_scores()
--       +1 / -1 ranking per community voter by agreement with the resolved
--       result, once per attempt. NOTE: verification_attempts /
--       community_votes are not defined in init.sql — the feature's tables
--       only exist if created out-of-band. plpgsql resolves table names at
--       call time, so this migration applies cleanly either way and the
--       client already swallows the error if the tables are missing.
--   PointsService.recalculateUserXP               -> recalculate_map_score()
--       map_score recomputed purely from server-side map_posts rows
--       (posts * post_xp + sum(vote_score) * vote_xp), the same formula the
--       update_user_map_xp trigger maintains incrementally.
--   PointsService.updateMapScore / updatePosterXP / updatePlayerScore /
--   updateRankingScore (arbitrary-value setters): no callers outside the
--       flows above — removed from the client, no RPC equivalent on purpose
--       (an "set my score to N" endpoint cannot be validated).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. daily_streaks: drop every known client write policy
--    (names accumulated across supabase_advisor_cleanup.sql and the archived
--    supabase_migration_rewards.sql)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Daily streaks access" ON public.daily_streaks;
DROP POLICY IF EXISTS "Users can view their own streak" ON public.daily_streaks;
DROP POLICY IF EXISTS "Users can update their own streak" ON public.daily_streaks;
DROP POLICY IF EXISTS "Users can insert their own streak" ON public.daily_streaks;

-- Recreate SELECT-only access: owner, or admin (admin console reads state)
DROP POLICY IF EXISTS "Daily streaks select owner or admin" ON public.daily_streaks;
CREATE POLICY "Daily streaks select owner or admin" ON public.daily_streaks
    FOR SELECT
    USING (
        (SELECT auth.uid()) = user_id
        OR EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = (SELECT auth.uid()) AND up.is_admin = TRUE
        )
    );

-- ----------------------------------------------------------------------------
-- 2. user_scores: drop every known client write policy
--    (init.sql lines ~1417-1424 and supabase_advisor_cleanup.sql)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "User scores access" ON public.user_scores;
DROP POLICY IF EXISTS "User scores write owner" ON public.user_scores;
DROP POLICY IF EXISTS "User scores update owner" ON public.user_scores;

-- Recreate SELECT-only access (same shape init.sql already used)
DROP POLICY IF EXISTS "User scores select owner or admin" ON public.user_scores;
CREATE POLICY "User scores select owner or admin" ON public.user_scores
    FOR SELECT
    USING (
        (SELECT auth.uid()) = user_id
        OR EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = (SELECT auth.uid()) AND up.is_admin = TRUE
        )
    );

-- ----------------------------------------------------------------------------
-- 3. xp_history: replay-guard ledger for the RPCs below, so it must stop
--    being client-writable (and, critically, client-DELETEable).
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "XP history access" ON public.xp_history;

DROP POLICY IF EXISTS "XP history select owner or admin" ON public.xp_history;
CREATE POLICY "XP history select owner or admin" ON public.xp_history
    FOR SELECT
    USING (
        (SELECT auth.uid()) = user_id
        OR EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = (SELECT auth.uid()) AND up.is_admin = TRUE
        )
    );

-- ----------------------------------------------------------------------------
-- 4. Revoke table-level write grants (init.sql's blanket GRANT ALL gave
--    clients INSERT/UPDATE/DELETE rights; remove them so only SECURITY
--    DEFINER functions — including the existing update_user_map_xp trigger
--    function, which runs as owner — can write)
-- ----------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE ON public.daily_streaks FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.user_scores FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.xp_history FROM anon, authenticated;

-- Keep read access (RLS above still scopes rows)
GRANT SELECT ON public.daily_streaks TO authenticated;
GRANT SELECT ON public.user_scores TO authenticated;
GRANT SELECT ON public.xp_history TO authenticated;

-- Replay-guard lookups below filter on exact reason strings
CREATE INDEX IF NOT EXISTS idx_xp_history_reason ON public.xp_history (reason);

-- ----------------------------------------------------------------------------
-- 5. record_daily_login: the ONLY write path to daily_streaks.
--    Self-only, no parameters — the server decides everything from its own
--    clock and its own row, so there is nothing for a client to forge. The
--    streak can only ever move to 1 (first login / missed day) or +1 (login
--    on the day after the last one), at most one state change per UTC day.
--    UTC is used deliberately: it matches award_points_atomic's
--    once-per-UTC-day daily_login check, so the two can never disagree
--    about what "today" is (the old client used device-local midnight).
--    Pre-existing forged rows are laundered by re-capping the streak at
--    account age, the same bound award_points_atomic applies.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_daily_login()
RETURNS JSONB AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_today DATE := (now() AT TIME ZONE 'utc')::date;
    v_row public.daily_streaks%ROWTYPE;
    v_status TEXT;
    v_new_streak INTEGER;
    v_new_longest INTEGER;
    v_signup_at TIMESTAMPTZ;
    v_max_streak INTEGER;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'record_daily_login: not authenticated';
    END IF;

    -- Serialize per user so concurrent calls cannot both pass the
    -- last_login_date checks and double-increment.
    PERFORM pg_advisory_xact_lock(hashtextextended('record_daily_login:' || v_caller::text, 0));

    SELECT * INTO v_row FROM public.daily_streaks WHERE user_id = v_caller;

    IF v_row.user_id IS NULL OR v_row.last_login_date IS NULL THEN
        -- First ever recorded login
        v_status := 'first_login';
        v_new_streak := 1;
    ELSIF v_row.last_login_date = v_today THEN
        -- Already recorded today: idempotent no-op
        RETURN jsonb_build_object(
            'status', 'already_logged_today',
            'current_streak', v_row.current_streak,
            'longest_streak', v_row.longest_streak,
            'last_login_date', v_row.last_login_date
        );
    ELSIF v_row.last_login_date = v_today - 1 THEN
        -- Logged in yesterday: streak continues
        v_status := 'incremented';
        v_new_streak := v_row.current_streak + 1;
    ELSE
        -- Missed a day (or the stored date is in the future, i.e. was
        -- forged while the table was client-writable): reset
        v_status := 'reset';
        v_new_streak := 1;
    END IF;

    -- A legitimate streak can never exceed the number of distinct UTC days
    -- since signup (inclusive); cap it so a previously forged current_streak
    -- cannot keep compounding via +1. Date arithmetic (not epoch flooring)
    -- so a signup at 23:50 UTC still allows streak 2 the next day.
    SELECT u.created_at INTO v_signup_at FROM auth.users u WHERE u.id = v_caller;
    v_max_streak := GREATEST(1,
        (v_today - (COALESCE(v_signup_at, now()) AT TIME ZONE 'utc')::date) + 1);
    v_new_streak := LEAST(v_new_streak, v_max_streak);
    v_new_longest := LEAST(GREATEST(COALESCE(v_row.longest_streak, 0), v_new_streak), v_max_streak);

    INSERT INTO public.daily_streaks (user_id, current_streak, longest_streak, last_login_date, updated_at)
    VALUES (v_caller, v_new_streak, v_new_longest, v_today, now())
    ON CONFLICT (user_id) DO UPDATE
        SET current_streak = EXCLUDED.current_streak,
            longest_streak = EXCLUDED.longest_streak,
            last_login_date = EXCLUDED.last_login_date,
            updated_at = now();

    RETURN jsonb_build_object(
        'status', v_status,
        'current_streak', v_new_streak,
        'longest_streak', v_new_longest,
        'last_login_date', v_today
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.record_daily_login() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_daily_login() TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. apply_battle_player_scores: player_score changes for a completed
--    battle, replacing BattleAnalyticsService.updatePlayerScoreForBattle's
--    two read-modify-write upserts. Amounts are computed entirely from the
--    battles row (winner +10; loser -(5 + 2 * letters collected); clamped
--    to 0..1000, exactly the old client formula) and applied at most once
--    per battle via the xp_history guard rows.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_battle_player_scores(p_battle_id UUID)
RETURNS VOID AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_guard TEXT := 'battle_result:' || p_battle_id::text;
    v_battle RECORD;
    v_loser UUID;
    v_loser_letters TEXT;
    v_points_lost NUMERIC;
    v_old NUMERIC;
    v_new NUMERIC;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'apply_battle_player_scores: not authenticated';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(v_guard, 0));

    SELECT b.player1_id, b.player2_id, b.winner_id, b.status,
           b.player1_letters, b.player2_letters
    INTO v_battle
    FROM public.battles b WHERE b.id = p_battle_id;

    IF v_battle IS NULL THEN
        RAISE EXCEPTION 'apply_battle_player_scores: battle % not found', p_battle_id;
    END IF;
    IF v_caller <> v_battle.player1_id AND v_caller <> v_battle.player2_id THEN
        RAISE EXCEPTION 'apply_battle_player_scores: caller is not a participant of this battle';
    END IF;
    IF v_battle.status <> 'completed' OR v_battle.winner_id IS NULL THEN
        RAISE EXCEPTION 'apply_battle_player_scores: battle is not completed';
    END IF;
    IF v_battle.winner_id <> v_battle.player1_id AND v_battle.winner_id <> v_battle.player2_id THEN
        RAISE EXCEPTION 'apply_battle_player_scores: recorded winner is not a participant';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.xp_history xh
        WHERE xh.score_type = 'player' AND xh.reason = v_guard
    ) THEN
        RAISE EXCEPTION 'apply_battle_player_scores: scores already applied for battle %', p_battle_id;
    END IF;

    IF v_battle.winner_id = v_battle.player1_id THEN
        v_loser := v_battle.player2_id;
        v_loser_letters := v_battle.player2_letters;
    ELSE
        v_loser := v_battle.player1_id;
        v_loser_letters := v_battle.player1_letters;
    END IF;
    -- Fewer letters = better performance = less point loss (old client rule)
    v_points_lost := 5 + 2 * COALESCE(length(v_loser_letters), 0);

    -- Winner: +10, capped at 1000
    SELECT us.player_score INTO v_old FROM public.user_scores us
    WHERE us.user_id = v_battle.winner_id FOR UPDATE;
    v_old := COALESCE(v_old, 0);
    v_new := LEAST(GREATEST(v_old + 10, 0), 1000);
    INSERT INTO public.user_scores (user_id, player_score)
    VALUES (v_battle.winner_id, v_new)
    ON CONFLICT (user_id) DO UPDATE SET player_score = EXCLUDED.player_score;
    -- Guard rows are inserted even when the clamped delta is 0, otherwise a
    -- capped battle would stay replayable.
    INSERT INTO public.xp_history (user_id, score_type, amount, reason)
    VALUES (v_battle.winner_id, 'player', v_new - v_old, v_guard);

    -- Loser: -(5 + 2 * letters), floored at 0
    SELECT us.player_score INTO v_old FROM public.user_scores us
    WHERE us.user_id = v_loser FOR UPDATE;
    v_old := COALESCE(v_old, 0);
    v_new := GREATEST(v_old - v_points_lost, 0);
    INSERT INTO public.user_scores (user_id, player_score)
    VALUES (v_loser, v_new)
    ON CONFLICT (user_id) DO UPDATE SET player_score = EXCLUDED.player_score;
    INSERT INTO public.xp_history (user_id, score_type, amount, reason)
    VALUES (v_loser, 'player', v_new - v_old, v_guard);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.apply_battle_player_scores(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_battle_player_scores(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 7. apply_verification_ranking_scores: ranking_score +1/-1 per community
--    voter by agreement with the attempt's stored result, replacing
--    VerificationService.updateRankingScores' client-side loop (which
--    passed the majority result from the client; here it is re-read from
--    the verification_attempts row). Once per attempt via xp_history guard
--    rows. See header note: these tables are not in init.sql, so the body
--    only resolves them at call time.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_verification_ranking_scores(p_attempt_id UUID)
RETURNS VOID AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_guard TEXT := 'verification_ranking:' || p_attempt_id::text;
    v_attempt RECORD;
    v_battle RECORD;
    v_vote RECORD;
    v_adj NUMERIC;
    v_old NUMERIC;
    v_new NUMERIC;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'apply_verification_ranking_scores: not authenticated';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(v_guard, 0));

    SELECT va.battle_id, va.status, va.result
    INTO v_attempt
    FROM public.verification_attempts va WHERE va.id = p_attempt_id;

    IF v_attempt IS NULL THEN
        RAISE EXCEPTION 'apply_verification_ranking_scores: attempt % not found', p_attempt_id;
    END IF;
    -- Enum strings as the Dart client stores them: VerificationStatus.resolved
    -- -> 'resolved', VoteType.land/noLand -> 'land'/'noLand' ('rebate' never
    -- affects ranking).
    IF v_attempt.status <> 'resolved' OR v_attempt.result IS NULL
       OR v_attempt.result NOT IN ('land', 'noLand') THEN
        RAISE EXCEPTION 'apply_verification_ranking_scores: attempt is not resolved with a land/noLand result';
    END IF;

    SELECT b.player1_id, b.player2_id INTO v_battle
    FROM public.battles b WHERE b.id = v_attempt.battle_id;

    -- Caller must have skin in the game: a battle participant or one of the
    -- attempt's voters (resolution is triggered from whichever client casts
    -- the deciding vote).
    IF NOT (
        v_caller = v_battle.player1_id
        OR v_caller = v_battle.player2_id
        OR EXISTS (
            SELECT 1 FROM public.community_votes cv
            WHERE cv.attempt_id = p_attempt_id AND cv.user_id = v_caller
        )
    ) THEN
        RAISE EXCEPTION 'apply_verification_ranking_scores: caller is not involved in this attempt';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.xp_history xh
        WHERE xh.score_type = 'ranking' AND xh.reason = v_guard
    ) THEN
        RAISE EXCEPTION 'apply_verification_ranking_scores: already applied for attempt %', p_attempt_id;
    END IF;

    -- One adjustment per voter; a voter's own vote row only ever moves their
    -- ranking by +/-1 per attempt, so vote forging cannot mint standing.
    FOR v_vote IN
        SELECT DISTINCT ON (cv.user_id) cv.user_id, cv.vote_type
        FROM public.community_votes cv
        WHERE cv.attempt_id = p_attempt_id AND cv.vote_type IN ('land', 'noLand')
        ORDER BY cv.user_id, cv.created_at DESC
    LOOP
        v_adj := CASE WHEN v_vote.vote_type = v_attempt.result THEN 1 ELSE -1 END;

        SELECT us.ranking_score INTO v_old FROM public.user_scores us
        WHERE us.user_id = v_vote.user_id FOR UPDATE;
        v_old := COALESCE(v_old, 500);
        v_new := LEAST(GREATEST(v_old + v_adj, 0), 1000);

        INSERT INTO public.user_scores (user_id, ranking_score)
        VALUES (v_vote.user_id, v_new)
        ON CONFLICT (user_id) DO UPDATE SET ranking_score = EXCLUDED.ranking_score;

        INSERT INTO public.xp_history (user_id, score_type, amount, reason)
        VALUES (v_vote.user_id, 'ranking', v_new - v_old, v_guard);
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.apply_verification_ranking_scores(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_verification_ranking_scores(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 8. recalculate_map_score: repair/recompute of map_score from server-side
--    map_posts rows only (posts * post_xp + sum(vote_score) * vote_xp, the
--    same formula the update_user_map_xp trigger maintains incrementally),
--    replacing PointsService.recalculateUserXP's client-computed upsert.
--    Nothing here is client-influenced except *whose* score to recompute,
--    and recomputing someone's score from real data is harmless — still
--    restricted to self-or-admin to match the old call pattern.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalculate_map_score(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_is_admin BOOLEAN := FALSE;
    v_config JSONB;
    v_post_xp NUMERIC;
    v_vote_xp NUMERIC;
    v_post_count INTEGER;
    v_vote_score NUMERIC;
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
    v_post_xp := COALESCE((v_config->>'post_xp')::NUMERIC, 100.0);
    v_vote_xp := COALESCE((v_config->>'vote_xp')::NUMERIC, 1.0);

    SELECT COUNT(*), COALESCE(SUM(mp.vote_score), 0)
    INTO v_post_count, v_vote_score
    FROM public.map_posts mp WHERE mp.user_id = p_user_id;

    v_total := GREATEST(v_post_count * v_post_xp + v_vote_score * v_vote_xp, 0);

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

REVOKE ALL ON FUNCTION public.recalculate_map_score(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recalculate_map_score(UUID) TO authenticated;
