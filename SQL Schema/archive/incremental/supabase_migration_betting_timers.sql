-- Migration: Add wagerting and timer functionality to battles
-- Run this in Supabase SQL editor

-- Add points to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 1000;

-- Update existing users to have starting points if they don't have any
UPDATE profiles SET points = 1000 WHERE points IS NULL;

-- Add wagerting and timer columns to battles table
ALTER TABLE battles ADD COLUMN IF NOT EXISTS wager_amount INTEGER DEFAULT 0;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS is_quickfire BOOLEAN DEFAULT FALSE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS turn_deadline TIMESTAMP WITH TIME ZONE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS wager_accepted BOOLEAN DEFAULT FALSE;

-- Add index for timer queries (to find expired turns)
CREATE INDEX IF NOT EXISTS idx_battles_turn_deadline ON battles(turn_deadline) WHERE turn_deadline IS NOT NULL;

-- Add index for pending wager acceptances
CREATE INDEX IF NOT EXISTS idx_battles_wager_accepted ON battles(wager_accepted) WHERE wager_accepted = FALSE AND wager_amount > 0;

COMMENT ON COLUMN profiles.points IS 'User points balance for wagerting on battles';
COMMENT ON COLUMN battles.wager_amount IS 'Amount of points wagered on this battle (0 = no wager)';
COMMENT ON COLUMN battles.is_quickfire IS 'Whether this is a quick-fire battle (4:20 timer)';
COMMENT ON COLUMN battles.turn_deadline IS 'Timestamp when current turn expires (auto-letter if missed)';
COMMENT ON COLUMN battles.wager_accepted IS 'Whether the opponent has accepted the wager';
