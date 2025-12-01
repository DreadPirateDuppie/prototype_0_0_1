-- Add voting fields to battles table

ALTER TABLE battles 
ADD COLUMN IF NOT EXISTS setter_id TEXT,
ADD COLUMN IF NOT EXISTS attempter_id TEXT,
ADD COLUMN IF NOT EXISTS setter_vote TEXT CHECK (setter_vote IN ('landed', 'missed')),
ADD COLUMN IF NOT EXISTS attempter_vote TEXT CHECK (attempter_vote IN ('landed', 'missed')),
ADD COLUMN IF NOT EXISTS trick_name TEXT;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_battles_setter_id ON battles(setter_id);
CREATE INDEX IF NOT EXISTS idx_battles_attempter_id ON battles(attempter_id);
