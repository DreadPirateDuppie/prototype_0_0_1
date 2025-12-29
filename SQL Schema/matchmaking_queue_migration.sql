-- Matchmaking Queue Table
-- Tracks players waiting for Quick Match opponents

CREATE TABLE IF NOT EXISTS matchmaking_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_mode TEXT NOT NULL DEFAULT 'skate',
  is_quickfire BOOLEAN NOT NULL DEFAULT true,
  bet_amount INTEGER NOT NULL DEFAULT 0,
  ranking_score DOUBLE PRECISION NOT NULL DEFAULT 500,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'waiting', -- 'waiting', 'matched', 'cancelled'
  matched_with UUID REFERENCES auth.users(id),
  battle_id UUID REFERENCES battles(id),
  UNIQUE(user_id) -- Only one queue entry per user at a time
);

-- Create index for faster matching queries
CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_status ON matchmaking_queue(status);
CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_ranking ON matchmaking_queue(ranking_score);
CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_joined ON matchmaking_queue(joined_at);

-- Enable Row Level Security
ALTER TABLE matchmaking_queue ENABLE ROW LEVEL SECURITY;

-- Users can insert their own queue entry
CREATE POLICY matchmaking_queue_insert ON matchmaking_queue 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Everyone can view queue entries (needed for matching)
CREATE POLICY matchmaking_queue_select ON matchmaking_queue 
  FOR SELECT USING (true);

-- Users can delete their own queue entry
CREATE POLICY matchmaking_queue_delete ON matchmaking_queue 
  FOR DELETE USING (auth.uid() = user_id);

-- Users can update their own queue entry
CREATE POLICY matchmaking_queue_update ON matchmaking_queue 
  FOR UPDATE USING (auth.uid() = user_id);

-- Enable realtime for live updates
ALTER PUBLICATION supabase_realtime ADD TABLE matchmaking_queue;
