-- Add voting fields to battles table

ALTER TABLE battles 
ADD COLUMN setter_id TEXT,
ADD COLUMN attempter_id TEXT,
ADD COLUMN setter_vote TEXT CHECK (setter_vote IN ('landed', 'missed')),
ADD COLUMN attempter_vote TEXT CHECK (attempter_vote IN ('landed', 'missed')),
ADD COLUMN trick_name TEXT;

-- Add indexes for performance
CREATE INDEX idx_battles_setter_id ON battles(setter_id);
CREATE INDEX idx_battles_attempter_id ON battles(attempter_id);
