-- Create trick_nodes table
CREATE TABLE IF NOT EXISTS trick_nodes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    difficulty INTEGER DEFAULT 1, -- 1-10 scale
    category TEXT NOT NULL, -- 'flat', 'ledge', 'rail', 'transition', etc.
    parent_ids UUID[] DEFAULT '{}', -- Array of trick IDs required to unlock this one
    points_value INTEGER DEFAULT 100, -- XP awarded for learning
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create user_trick_progress table
CREATE TABLE IF NOT EXISTS user_trick_progress (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trick_id UUID NOT NULL REFERENCES trick_nodes(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'locked', -- 'locked', 'available', 'learned', 'mastered'
    video_proof_url TEXT,
    learned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, trick_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_trick_nodes_category ON trick_nodes(category);
CREATE INDEX IF NOT EXISTS idx_user_trick_progress_user_id ON user_trick_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_trick_progress_status ON user_trick_progress(status);

-- Enable RLS
ALTER TABLE trick_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_trick_progress ENABLE ROW LEVEL SECURITY;

-- Policies for trick_nodes (Public read, Admin write)
CREATE POLICY "Public read access for trick_nodes" ON trick_nodes
    FOR SELECT USING (true);

-- Policies for user_trick_progress (Users can read/write their own)
CREATE POLICY "Users can read own progress" ON user_trick_progress
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own progress" ON user_trick_progress
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own progress" ON user_trick_progress
    FOR UPDATE USING (auth.uid() = user_id);
