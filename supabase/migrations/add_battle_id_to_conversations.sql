-- Add battle_id to conversations table to link chats to specific battles
ALTER TABLE conversations ADD COLUMN battle_id UUID REFERENCES battles(id);

-- Index for faster lookups
CREATE INDEX idx_conversations_battle_id ON conversations(battle_id);
