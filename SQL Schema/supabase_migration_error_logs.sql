-- Create error_logs table for admin error monitoring
CREATE TABLE IF NOT EXISTS public.error_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    error_message TEXT NOT NULL,
    error_stack TEXT,
    screen_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.error_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Only admins can view error logs
DROP POLICY IF EXISTS "Admins can view error logs" ON public.error_logs;
CREATE POLICY "Admins can view error logs"
    ON public.error_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND is_admin = true
        )
    );

-- Policy: Anyone can insert error logs (including anonymous users)
DROP POLICY IF EXISTS "Anyone can log errors" ON public.error_logs;
CREATE POLICY "Anyone can log errors"
    ON public.error_logs FOR INSERT
    WITH CHECK (true);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS error_logs_user_id_idx ON public.error_logs(user_id);
CREATE INDEX IF NOT EXISTS error_logs_created_at_idx ON public.error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS error_logs_screen_name_idx ON public.error_logs(screen_name);
