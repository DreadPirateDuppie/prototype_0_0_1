-- Create ghost_lines table
CREATE TABLE IF NOT EXISTS ghost_lines (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    spot_id UUID NOT NULL, -- Can be null if it's a street line not tied to a spot? Let's say it must be tied to a spot for now.
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    path_points JSONB NOT NULL, -- Array of {lat, lng, timestamp}
    trick_markers JSONB DEFAULT '[]', -- Array of {lat, lng, trick_name, timestamp}
    duration_seconds INTEGER,
    distance_meters FLOAT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Add foreign key to spots table if it exists (assuming map_posts serves as spots)
    CONSTRAINT fk_spot FOREIGN KEY (spot_id) REFERENCES map_posts(id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ghost_lines_spot_id ON ghost_lines(spot_id);
CREATE INDEX IF NOT EXISTS idx_ghost_lines_creator_id ON ghost_lines(creator_id);

-- Enable RLS
ALTER TABLE ghost_lines ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Public read access for ghost_lines" ON ghost_lines
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own ghost_lines" ON ghost_lines
    FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Users can delete own ghost_lines" ON ghost_lines
    FOR DELETE USING (auth.uid() = creator_id);
