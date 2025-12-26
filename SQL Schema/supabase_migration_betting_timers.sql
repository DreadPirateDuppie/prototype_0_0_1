-- Migration: Add betting and timer functionality to battles
-- Run this in Supabase SQL editor

-- Add points to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 1000;

-- Update existing users to have starting points if they don't have any
UPDATE profiles SET points = 1000 WHERE points IS NULL;

-- Add betting and timer columns to battles table
ALTER TABLE battles ADD COLUMN IF NOT EXISTS bet_amount INTEGER DEFAULT 0;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS is_quickfire BOOLEAN DEFAULT FALSE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS turn_deadline TIMESTAMP WITH TIME ZONE;
ALTER TABLE battles ADD COLUMN IF NOT EXISTS bet_accepted BOOLEAN DEFAULT FALSE;

-- Add index for timer queries (to find expired turns)
CREATE INDEX IF NOT EXISTS idx_battles_turn_deadline ON battles(turn_deadline) WHERE turn_deadline IS NOT NULL;

-- Add index for pending bet acceptances
CREATE INDEX IF NOT EXISTS idx_battles_bet_accepted ON battles(bet_accepted) WHERE bet_accepted = FALSE AND bet_amount > 0;

COMMENT ON COLUMN profiles.points IS 'User points balance for betting on battles';
COMMENT ON COLUMN battles.bet_amount IS 'Amount of points wagered on this battle (0 = no bet)';
COMMENT ON COLUMN battles.is_quickfire IS 'Whether this is a quick-fire battle (4:20 timer)';
COMMENT ON COLUMN battles.turn_deadline IS 'Timestamp when current turn expires (auto-letter if missed)';
COMMENT ON COLUMN battles.bet_accepted IS 'Whether the opponent has accepted the bet';
