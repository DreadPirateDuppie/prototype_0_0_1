-- Create spot_videos table for video history feature
CREATE TABLE IF NOT EXISTS spot_videos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  spot_id UUID NOT NULL REFERENCES map_posts(id) ON DELETE CASCADE,
  url TEXT, -- Made optional for tricks without videos yet
  platform TEXT CHECK (platform IN ('youtube', 'instagram', 'tiktok', 'vimeo', 'other')),
  skater_name TEXT,
  description TEXT,
  submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  upvotes INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  approved_at TIMESTAMP WITH TIME ZONE,
  approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Create video_upvotes table for voting
CREATE TABLE IF NOT EXISTS video_upvotes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  video_id UUID NOT NULL REFERENCES spot_videos(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type INTEGER NOT NULL CHECK (vote_type IN (1, -1)),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(video_id, user_id)
);

-- Create indices for performance
CREATE INDEX IF NOT EXISTS idx_spot_videos_spot_id ON spot_videos(spot_id);
CREATE INDEX IF NOT EXISTS idx_spot_videos_status ON spot_videos(status);
CREATE INDEX IF NOT EXISTS idx_spot_videos_created_at ON spot_videos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_upvotes_video_id ON video_upvotes(video_id);
CREATE INDEX IF NOT EXISTS idx_video_upvotes_user_id ON video_upvotes(user_id);

-- Enable Row Level Security
ALTER TABLE spot_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_upvotes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for spot_videos
-- Anyone can view approved videos
CREATE POLICY "Anyone can view approved videos" ON spot_videos
  FOR SELECT USING (status = 'approved' OR submitted_by = auth.uid());

-- Authenticated users can submit videos
CREATE POLICY "Authenticated users can submit videos" ON spot_videos
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND submitted_by = auth.uid());

-- Users can update their own pending videos
CREATE POLICY "Users can update own pending videos" ON spot_videos
  FOR UPDATE USING (submitted_by = auth.uid() AND status = 'pending');

-- Users can delete their own videos
CREATE POLICY "Users can delete own videos" ON spot_videos
  FOR DELETE USING (submitted_by = auth.uid());

-- RLS Policies for video_upvotes
-- Anyone can view upvotes
CREATE POLICY "Anyone can view upvotes" ON video_upvotes
  FOR SELECT USING (true);

-- Authenticated users can upvote
CREATE POLICY "Authenticated users can upvote" ON video_upvotes
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

-- Users can update their own votes
CREATE POLICY "Users can update own votes" ON video_upvotes
  FOR UPDATE USING (user_id = auth.uid());

-- Users can delete their own votes
CREATE POLICY "Users can delete own votes" ON video_upvotes
  FOR DELETE USING (user_id = auth.uid());

-- Function to update video upvote count
CREATE OR REPLACE FUNCTION update_video_upvotes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE spot_videos
    SET upvotes = upvotes + NEW.vote_type
    WHERE id = NEW.video_id;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE spot_videos
    SET upvotes = upvotes + (NEW.vote_type - OLD.vote_type)
    WHERE id = NEW.video_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE spot_videos
    SET upvotes = upvotes - OLD.vote_type
    WHERE id = OLD.video_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update upvote counts
CREATE TRIGGER video_upvotes_trigger
AFTER INSERT OR UPDATE OR DELETE ON video_upvotes
FOR EACH ROW EXECUTE FUNCTION update_video_upvotes();
