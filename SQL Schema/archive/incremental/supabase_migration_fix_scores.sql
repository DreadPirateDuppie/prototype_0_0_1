-- Create user_scores table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_scores (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    map_score NUMERIC DEFAULT 0,
    player_score NUMERIC DEFAULT 0,
    ranking_score NUMERIC DEFAULT 500,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.user_scores ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all scores (for leaderboards/profiles)
CREATE POLICY "Users can view all scores" ON public.user_scores
    FOR SELECT USING (true);

-- Policy: Users can insert their own scores
CREATE POLICY "Users can insert their own scores" ON public.user_scores
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own scores
CREATE POLICY "Users can update their own scores" ON public.user_scores
    FOR UPDATE USING (auth.uid() = user_id);

-- Function to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_user_scores_updated_at ON public.user_scores;
CREATE TRIGGER update_user_scores_updated_at
    BEFORE UPDATE ON public.user_scores
    FOR EACH ROW
    EXECUTE PROCEDURE update_updated_at_column();
