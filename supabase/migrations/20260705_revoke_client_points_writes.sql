-- ============================================================================
-- Revoke direct client write access to points tables
-- ============================================================================
-- Context: the Flutter client previously contained a fallback path that read
-- the wallet balance, added an amount locally, and upserted the result back
-- into user_wallets (plus a matching client-side point_transactions insert).
-- Combined with the broad "GRANT ALL ON ALL TABLES IN SCHEMA public TO
-- authenticated" in init.sql and owner-scoped write RLS policies
-- ("User wallets access" FOR ALL, "Point transactions insert owner", etc.),
-- any authenticated client could set its own balance to an arbitrary value.
--
-- After this migration, ALL balance changes must go through the
-- SECURITY DEFINER RPC award_points_atomic (or the admin reversal RPC below).
-- Clients keep read-only access to their own rows.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Drop every known client write policy on user_wallets
--    (names accumulated across init.sql, supabase_advisor_cleanup.sql and the
--    archived supabase_migration_rewards.sql)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "User wallets access" ON public.user_wallets;
DROP POLICY IF EXISTS "Users can view their own wallet" ON public.user_wallets;
DROP POLICY IF EXISTS "Users can update their own wallet" ON public.user_wallets;
DROP POLICY IF EXISTS "Users can insert their own wallet" ON public.user_wallets;

-- Recreate SELECT-only access: owner, or admin (admin console reads balances)
DROP POLICY IF EXISTS "User wallets select owner or admin" ON public.user_wallets;
CREATE POLICY "User wallets select owner or admin" ON public.user_wallets
    FOR SELECT
    USING (
        (SELECT auth.uid()) = user_id
        OR EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = (SELECT auth.uid()) AND up.is_admin = TRUE
        )
    );

-- ----------------------------------------------------------------------------
-- 2. Drop every known client write policy on point_transactions
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Point transactions access" ON public.point_transactions;
DROP POLICY IF EXISTS "Point transactions insert owner" ON public.point_transactions;
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.point_transactions;
DROP POLICY IF EXISTS "Users can insert their own transactions" ON public.point_transactions;
DROP POLICY IF EXISTS "Users can view own transactions" ON public.point_transactions;

-- Recreate SELECT-only access: owner, or admin (admin console views ledgers)
DROP POLICY IF EXISTS "Point transactions select owner" ON public.point_transactions;
DROP POLICY IF EXISTS "Point transactions select owner or admin" ON public.point_transactions;
CREATE POLICY "Point transactions select owner or admin" ON public.point_transactions
    FOR SELECT
    USING (
        (SELECT auth.uid()) = user_id
        OR EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = (SELECT auth.uid()) AND up.is_admin = TRUE
        )
    );

-- ----------------------------------------------------------------------------
-- 3. Revoke table-level write grants (RLS is bypassed-by-grant nowhere, but
--    init.sql's blanket GRANT ALL gave clients INSERT/UPDATE/DELETE rights;
--    remove them so only SECURITY DEFINER functions can write)
-- ----------------------------------------------------------------------------
REVOKE INSERT, UPDATE, DELETE ON public.user_wallets FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.point_transactions FROM anon, authenticated;

-- Keep read access (RLS above still scopes rows)
GRANT SELECT ON public.user_wallets TO authenticated;
GRANT SELECT ON public.point_transactions TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. Admin-only reversal RPC. The admin console previously deleted a
--    transaction row and client-computed the reversed balance; that write
--    path is now revoked, so provide a server-authoritative equivalent.
--    Amount and user are read from the stored row, never from the client.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_reverse_point_transaction(p_transaction_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_user_id UUID;
    v_amount NUMERIC;
    v_new_balance NUMERIC;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND is_admin = TRUE
    ) THEN
        RAISE EXCEPTION 'Only admins can reverse point transactions';
    END IF;

    DELETE FROM public.point_transactions
    WHERE id = p_transaction_id
    RETURNING user_id, amount INTO v_user_id, v_amount;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Point transaction % not found', p_transaction_id;
    END IF;

    UPDATE public.user_wallets
    SET balance = balance - v_amount,
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING balance INTO v_new_balance;

    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.admin_reverse_point_transaction(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_reverse_point_transaction(UUID) TO authenticated;
