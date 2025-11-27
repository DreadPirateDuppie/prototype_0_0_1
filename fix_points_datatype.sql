-- Fix data type mismatch for points system
-- Run this in Supabase SQL Editor to fix the INTEGER -> NUMERIC issue

-- Option 1: If you have no important data yet, drop and recreate
DROP TABLE IF EXISTS public.point_transactions CASCADE;
DROP TABLE IF EXISTS public.user_wallets CASCADE;

-- Then run the full supabase_migration_rewards.sql file

-- Option 2: If you have data you want to keep, alter the columns
-- ALTER TABLE public.user_wallets ALTER COLUMN balance TYPE NUMERIC(10,2);
-- ALTER TABLE public.point_transactions ALTER COLUMN amount TYPE NUMERIC(10,2);
