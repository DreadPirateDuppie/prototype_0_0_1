-- Create user_wallets table to track point balance
CREATE TABLE IF NOT EXISTS public.user_wallets (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    balance NUMERIC(10,2) DEFAULT 0 NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for user_wallets
ALTER TABLE public.user_wallets ENABLE ROW LEVEL SECURITY;

-- Policies for user_wallets
DROP POLICY IF EXISTS "Users can view their own wallet" ON public.user_wallets;
CREATE POLICY "Users can view their own wallet" 
    ON public.user_wallets FOR SELECT 
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own wallet" ON public.user_wallets;
CREATE POLICY "Users can update their own wallet" 
    ON public.user_wallets FOR UPDATE 
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own wallet" ON public.user_wallets;
CREATE POLICY "Users can insert their own wallet" 
    ON public.user_wallets FOR INSERT 
    WITH CHECK (auth.uid() = user_id);


-- Create daily_streaks table
CREATE TABLE IF NOT EXISTS public.daily_streaks (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0 NOT NULL,
    last_login_date DATE,
    longest_streak INTEGER DEFAULT 0 NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for daily_streaks
ALTER TABLE public.daily_streaks ENABLE ROW LEVEL SECURITY;

-- Policies for daily_streaks
DROP POLICY IF EXISTS "Users can view their own streak" ON public.daily_streaks;
CREATE POLICY "Users can view their own streak" 
    ON public.daily_streaks FOR SELECT 
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own streak" ON public.daily_streaks;
CREATE POLICY "Users can update their own streak" 
    ON public.daily_streaks FOR UPDATE 
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own streak" ON public.daily_streaks;
CREATE POLICY "Users can insert their own streak" 
    ON public.daily_streaks FOR INSERT 
    WITH CHECK (auth.uid() = user_id);


-- Create point_transactions table (The Ledger)
CREATE TABLE IF NOT EXISTS public.point_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    amount NUMERIC(10,2) NOT NULL, -- Positive for earning, negative for spending
    transaction_type TEXT NOT NULL, -- 'daily_login', 'post_reward', 'upvote_reward', 'wager_entry', 'wager_win'
    reference_id TEXT, -- Optional ID to link to post, battle, etc.
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for point_transactions
ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;

-- Policies for point_transactions
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.point_transactions;
CREATE POLICY "Users can view their own transactions" 
    ON public.point_transactions FOR SELECT 
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own transactions" ON public.point_transactions;
CREATE POLICY "Users can insert their own transactions" 
    ON public.point_transactions FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_point_transactions_user_id ON public.point_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_point_transactions_created_at ON public.point_transactions(created_at);

-- Create battles table if it doesn't exist (Base Schema)
CREATE TABLE IF NOT EXISTS public.battles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    player1_id UUID REFERENCES auth.users(id) NOT NULL,
    player2_id UUID REFERENCES auth.users(id) NOT NULL,
    game_mode TEXT NOT NULL,
    custom_letters TEXT,
    player1_letters TEXT DEFAULT '',
    player2_letters TEXT DEFAULT '',
    set_trick_video_url TEXT,
    attempt_video_url TEXT,
    verification_status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    winner_id UUID REFERENCES auth.users(id),
    current_turn_player_id UUID REFERENCES auth.users(id) NOT NULL
);

-- Enable RLS for battles
ALTER TABLE public.battles ENABLE ROW LEVEL SECURITY;

-- Policies for battles
DROP POLICY IF EXISTS "Users can view battles they are involved in" ON public.battles;
CREATE POLICY "Users can view battles they are involved in" 
    ON public.battles FOR SELECT 
    USING (auth.uid() = player1_id OR auth.uid() = player2_id);

DROP POLICY IF EXISTS "Users can create battles" ON public.battles;
CREATE POLICY "Users can create battles" 
    ON public.battles FOR INSERT 
    WITH CHECK (auth.uid() = player1_id);

DROP POLICY IF EXISTS "Users can update battles they are involved in" ON public.battles;
CREATE POLICY "Users can update battles they are involved in" 
    ON public.battles FOR UPDATE 
    USING (auth.uid() = player1_id OR auth.uid() = player2_id);


-- Add wager_amount to battles table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'battles' AND column_name = 'wager_amount') THEN
        ALTER TABLE public.battles ADD COLUMN wager_amount INTEGER DEFAULT 0;
    END IF;
END $$;
