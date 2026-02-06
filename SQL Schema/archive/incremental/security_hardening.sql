-- Security Hardening Migration
-- Addresses security warnings from the Supabase Dashboard

-- 1. Enable RLS for public tables that were newly created or missed
ALTER TABLE IF EXISTS public.spot_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.battles ENABLE ROW LEVEL SECURITY;

-- 2. Define Policies for spot_videos (if not already existing)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'spot_videos' AND policyname = 'Anyone can view approved videos') THEN
        CREATE POLICY "Anyone can view approved videos" ON public.spot_videos
            FOR SELECT USING (status = 'approved' OR submitted_by = auth.uid());
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'spot_videos' AND policyname = 'Authenticated users can submit videos') THEN
        CREATE POLICY "Authenticated users can submit videos" ON public.spot_videos
            FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND submitted_by = auth.uid());
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'spot_videos' AND policyname = 'Users can update own pending videos') THEN
        CREATE POLICY "Users can update own pending videos" ON public.spot_videos
            FOR UPDATE USING (submitted_by = auth.uid() AND status = 'pending');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'spot_videos' AND policyname = 'Users can delete own videos') THEN
        CREATE POLICY "Users can delete own videos" ON public.spot_videos
            FOR DELETE USING (submitted_by = auth.uid());
    END IF;
END
$$;

-- 3. Define Policies for battles (if not already existing)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'battles' AND policyname = 'Users can view battles they are involved in') THEN
        CREATE POLICY "Users can view battles they are involved in" 
            ON public.battles FOR SELECT 
            USING (auth.uid() = player1_id OR auth.uid() = player2_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'battles' AND policyname = 'Users can create battles') THEN
        CREATE POLICY "Users can create battles" 
            ON public.battles FOR INSERT 
            WITH CHECK (auth.uid() = player1_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'battles' AND policyname = 'Users can update battles they are involved in') THEN
        CREATE POLICY "Users can update battles they are involved in" 
            ON public.battles FOR UPDATE 
            USING (auth.uid() = player1_id OR auth.uid() = player2_id);
    END IF;
END
$$;

-- 4. Secure functions by setting search_path
-- This prevents search path hijacking

DO $$
BEGIN
    -- Use nested blocks to ignore errors if functions don't exist
    BEGIN
        ALTER FUNCTION public.handle_new_user() SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
    
    BEGIN
        ALTER FUNCTION public.handle_sync_user_email() SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
    
    BEGIN
        ALTER FUNCTION public.handle_sync_user_email_on_insert() SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
    
    BEGIN
        ALTER FUNCTION public.get_battle_leaderboard(INTEGER) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;

    BEGIN
        ALTER FUNCTION public.update_updated_at_column() SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
END
$$;
