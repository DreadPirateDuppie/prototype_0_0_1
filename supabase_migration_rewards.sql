-- Create user_wallets table to track point balance
CREATE TABLE IF NOT EXISTS public.user_wallets (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    balance INTEGER DEFAULT 0 NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for user_wallets
ALTER TABLE public.user_wallets ENABLE ROW LEVEL SECURITY;

-- Policies for user_wallets
CREATE POLICY "Users can view their own wallet" 
    ON public.user_wallets FOR SELECT 
    USING (auth.uid() = user_id);

-- Only service role can update wallets (for security)
-- But for now, we'll allow users to update their own wallet via client-side logic 
-- (In a real production app, this should be done via Edge Functions)
CREATE POLICY "Users can update their own wallet" 
    ON public.user_wallets FOR UPDATE 
    USING (auth.uid() = user_id);

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
CREATE POLICY "Users can view their own streak" 
    ON public.daily_streaks FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own streak" 
    ON public.daily_streaks FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own streak" 
    ON public.daily_streaks FOR INSERT 
    WITH CHECK (auth.uid() = user_id);


-- Create point_transactions table (The Ledger)
CREATE TABLE IF NOT EXISTS public.point_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    amount INTEGER NOT NULL, -- Positive for earning, negative for spending
    transaction_type TEXT NOT NULL, -- 'daily_login', 'post_reward', 'upvote_reward', 'wager_entry', 'wager_win'
    reference_id TEXT, -- Optional ID to link to post, battle, etc.
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for point_transactions
ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;

-- Policies for point_transactions
CREATE POLICY "Users can view their own transactions" 
    ON public.point_transactions FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own transactions" 
    ON public.point_transactions FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_point_transactions_user_id ON public.point_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_point_transactions_created_at ON public.point_transactions(created_at);

-- Trigger to automatically create wallet and streak records for new users
-- (This would typically be done via a trigger on auth.users, but we'll handle it in the app code for now to avoid complex SQL triggers)

-- Add wager_amount to battles table
ALTER TABLE public.battles ADD COLUMN IF NOT EXISTS wager_amount INTEGER DEFAULT 0;
