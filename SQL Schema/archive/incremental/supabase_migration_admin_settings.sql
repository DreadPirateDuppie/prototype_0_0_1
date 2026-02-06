-- Create app_settings table
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Only admins can select settings (we can make some public later if needed)
CREATE POLICY "Admins can select app_settings" ON public.app_settings
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.is_admin = true
        )
    );

-- Only admins can insert/update settings
CREATE POLICY "Admins can modify app_settings" ON public.app_settings
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.is_admin = true
        )
    );

-- Insert default points settings
INSERT INTO public.app_settings (key, value)
VALUES (
    'points_config',
    '{
        "base_daily_points": 3.5,
        "streak_bonus_multiplier": 0.5,
        "first_login_bonus": 10.0,
        "post_xp": 100.0,
        "vote_xp": 1.0
    }'::jsonb
) ON CONFLICT (key) DO NOTHING;
