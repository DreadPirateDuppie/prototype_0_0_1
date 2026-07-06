-- ==========================================================================
-- RENAME GAMBLING-TERMINOLOGY COLUMNS FOR APP STORE COMPLIANCE
-- Companion to app commit 3101345 ("replace gambling terminology
-- (bet/betting) with wagering/staking").
--
-- STATUS: NOT YET APPLIED to the live Supabase project as of 2026-07-05.
-- The Flutter code now reads/writes wager_amount / wager_accepted, so
-- battle creation, wager acceptance, and matchmaking will fail against
-- the live database until this is run in the Supabase SQL editor.
--
-- All steps are idempotent / guarded, safe to re-run.
-- ==========================================================================

-- 1. battles: merge legacy bet_amount into wager_amount, then drop it.
--    (Both columns existed historically; bet_amount was the actively
--    written one, wager_amount is the surviving canonical column.)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'battles' AND column_name = 'bet_amount'
  ) THEN
    UPDATE public.battles
    SET wager_amount = bet_amount
    WHERE COALESCE(wager_amount, 0) = 0 AND COALESCE(bet_amount, 0) > 0;

    ALTER TABLE public.battles DROP COLUMN bet_amount;
  END IF;
END $$;

-- 2. battles: rename bet_accepted -> wager_accepted.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'battles' AND column_name = 'bet_accepted'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'battles' AND column_name = 'wager_accepted'
  ) THEN
    ALTER TABLE public.battles RENAME COLUMN bet_accepted TO wager_accepted;
  END IF;
END $$;

-- 3. Rename the supporting index if it still carries the old name.
ALTER INDEX IF EXISTS idx_battles_bet_accepted RENAME TO idx_battles_wager_accepted;

-- 4. matchmaking_queue: rename bet_amount -> wager_amount.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'matchmaking_queue' AND column_name = 'bet_amount'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'matchmaking_queue' AND column_name = 'wager_amount'
  ) THEN
    ALTER TABLE public.matchmaking_queue RENAME COLUMN bet_amount TO wager_amount;
  END IF;
END $$;

-- 5. point_transactions: relabel legacy transaction_type values.
--    (Display/history only; app now writes 'wager_entry' etc.)
UPDATE public.point_transactions SET transaction_type = 'wager_entry'  WHERE transaction_type = 'bet_entry';
UPDATE public.point_transactions SET transaction_type = 'wager_win'    WHERE transaction_type = 'bet_win';
UPDATE public.point_transactions SET transaction_type = 'wager_won'    WHERE transaction_type = 'bet_won';
UPDATE public.point_transactions SET transaction_type = 'wager_placed' WHERE transaction_type = 'bet_placed';

-- 6. Refresh column comments to match new terminology.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'battles' AND column_name = 'wager_amount'
  ) THEN
    COMMENT ON COLUMN public.battles.wager_amount IS 'Amount of points wagered on this battle (0 = no wager)';
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'battles' AND column_name = 'wager_accepted'
  ) THEN
    COMMENT ON COLUMN public.battles.wager_accepted IS 'Whether the opponent has accepted the wager';
  END IF;
END $$;
