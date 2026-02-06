-- Add missing columns to battles table
ALTER TABLE battles
ADD COLUMN IF NOT EXISTS bet_accepted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS bet_amount INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS wager_amount INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_quickfire BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS turn_deadline TIMESTAMP WITH TIME ZONE;

-- Create index for bet_accepted to help with queries filtering by accepted bets
CREATE INDEX IF NOT EXISTS idx_battles_bet_accepted ON battles(bet_accepted);
