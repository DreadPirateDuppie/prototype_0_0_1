-- Create xp_history table
CREATE TABLE IF NOT EXISTS public.xp_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    score_type TEXT NOT NULL CHECK (score_type IN ('map', 'player', 'ranking')),
    amount NUMERIC NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add index for faster queries by user
CREATE INDEX IF NOT EXISTS idx_xp_history_user_id ON public.xp_history(user_id);

-- Add RLS policies
ALTER TABLE public.xp_history ENABLE ROW LEVEL SECURITY;

-- Admins can view all history
CREATE POLICY "Admins can view all xp history" ON public.xp_history
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Users can view their own history
CREATE POLICY "Users can view their own xp history" ON public.xp_history
    FOR SELECT
    USING (auth.uid() = user_id);

-- Service role can insert (for backend logic)
-- Note: In this app, we often insert from client with RLS, so we might need to allow insert for users if logic is client-side.
-- However, score updates should ideally be secure. For now, assuming client-side logic triggers it, we'll allow users to insert their own history 
-- BUT strictly speaking this should be done via database triggers or secure functions. 
-- Given the current architecture where services update scores directly:
CREATE POLICY "Users can insert their own xp history" ON public.xp_history
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.xp_history IS 'Tracks history of XP gains and losses for users';
