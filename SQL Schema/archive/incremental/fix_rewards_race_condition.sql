-- Create a function to award points atomically
CREATE OR REPLACE FUNCTION award_points_atomic(
  p_user_id UUID,
  p_amount NUMERIC,
  p_transaction_type TEXT,
  p_reference_id TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
) RETURNS NUMERIC AS $$
DECLARE
  v_new_balance NUMERIC;
BEGIN
  -- 1. Update or Insert wallet balance atomically
  INSERT INTO public.user_wallets (user_id, balance, updated_at)
  VALUES (p_user_id, p_amount, NOW())
  ON CONFLICT (user_id) DO UPDATE
  SET balance = user_wallets.balance + p_amount,
      updated_at = NOW()
  RETURNING balance INTO v_new_balance;

  -- 2. Log transaction
  INSERT INTO public.point_transactions (user_id, amount, transaction_type, reference_id, description, created_at)
  VALUES (p_user_id, p_amount, p_transaction_type, p_reference_id, p_description, NOW());

  RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION award_points_atomic TO authenticated;
