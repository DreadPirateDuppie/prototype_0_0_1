-- Multiplayer SKATE Lobby Migration

-- 1. Lobbies Table
CREATE TABLE IF NOT EXISTS skate_lobbies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    host_id UUID REFERENCES auth.users(id) NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'completed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Lobby Players Table
CREATE TABLE IF NOT EXISTS skate_lobby_players (
    lobby_id UUID REFERENCES skate_lobbies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    letters TEXT DEFAULT '',
    is_host BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (lobby_id, user_id)
);

-- 3. Lobby Events Table (for game log)
CREATE TABLE IF NOT EXISTS skate_lobby_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lobby_id UUID REFERENCES skate_lobbies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('set', 'miss', 'land', 'chat', 'join', 'leave')),
    data TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_skate_lobbies_code ON skate_lobbies(code);
CREATE INDEX IF NOT EXISTS idx_skate_lobby_players_lobby ON skate_lobby_players(lobby_id);
CREATE INDEX IF NOT EXISTS idx_skate_lobby_events_lobby ON skate_lobby_events(lobby_id);

-- RLS Policies (Simplified for prototype: allow all authenticated users to read/write)
ALTER TABLE skate_lobbies ENABLE ROW LEVEL SECURITY;
ALTER TABLE skate_lobby_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE skate_lobby_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read/write for lobbies" ON skate_lobbies
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow public read/write for lobby players" ON skate_lobby_players
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow public read/write for lobby events" ON skate_lobby_events
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Realtime publication
-- Add tables to realtime publication so clients can subscribe
ALTER PUBLICATION supabase_realtime ADD TABLE skate_lobbies;
ALTER PUBLICATION supabase_realtime ADD TABLE skate_lobby_players;
ALTER PUBLICATION supabase_realtime ADD TABLE skate_lobby_events;
