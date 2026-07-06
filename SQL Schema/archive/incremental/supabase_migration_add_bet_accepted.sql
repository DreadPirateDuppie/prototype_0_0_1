-- Add missing columns to battles table
ALTER TABLE battles
ADD COLUMN IF NOT EXISTS wager_accepted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS wager_amount INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_quickfire BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS turn_deadline TIMESTAMP WITH TIME ZONE;

-- Create index for wager_accepted to help with queries filtering by accepted wagers
CREATE INDEX IF NOT EXISTS idx_battles_wager_accepted ON battles(wager_accepted);
