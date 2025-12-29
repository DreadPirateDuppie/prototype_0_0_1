-- Consolidated Migration for Matchmaking and Skate Lobbies
-- This script creates all necessary tables for both Quick Match and Local Game features.

-- 1. Matchmaking Queue Table (for Quick Match)
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
  UNIQUE(user_id)
);

-- 2. Skate Lobbies Table (for Local Game)
CREATE TABLE IF NOT EXISTS skate_lobbies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    host_id UUID REFERENCES auth.users(id) NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'completed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Skate Lobby Players Table
CREATE TABLE IF NOT EXISTS skate_lobby_players (
    lobby_id UUID REFERENCES skate_lobbies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    letters TEXT DEFAULT '',
    is_host BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (lobby_id, user_id)
);

-- 4. Skate Lobby Events Table
CREATE TABLE IF NOT EXISTS skate_lobby_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lobby_id UUID REFERENCES skate_lobbies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('set', 'miss', 'land', 'chat', 'join', 'leave')),
    data TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_status ON matchmaking_queue(status);
CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_ranking ON matchmaking_queue(ranking_score);
CREATE INDEX IF NOT EXISTS idx_skate_lobbies_code ON skate_lobbies(code);
CREATE INDEX IF NOT EXISTS idx_skate_lobby_players_lobby ON skate_lobby_players(lobby_id);

-- Enable Row Level Security
ALTER TABLE matchmaking_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE skate_lobbies ENABLE ROW LEVEL SECURITY;
ALTER TABLE skate_lobby_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE skate_lobby_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Matchmaking Queue
CREATE POLICY matchmaking_queue_all ON matchmaking_queue 
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- RLS Policies for Skate Lobbies
CREATE POLICY skate_lobbies_all ON skate_lobbies
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY skate_lobby_players_all ON skate_lobby_players
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY skate_lobby_events_all ON skate_lobby_events
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Enable Realtime
-- Note: You may need to run these individually if they fail due to existing publications
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE tablename = 'matchmaking_queue') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE matchmaking_queue;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE tablename = 'skate_lobbies') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE skate_lobbies;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE tablename = 'skate_lobby_players') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE skate_lobby_players;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE tablename = 'skate_lobby_events') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE skate_lobby_events;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not add tables to publication. Ensure publication exists.';
END $$;
