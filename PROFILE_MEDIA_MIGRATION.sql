-- Create profile_media table for user-uploaded photos and videos
-- These are independent of map posts and do not award points

CREATE TABLE IF NOT EXISTS profile_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  media_url TEXT NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video')),
  thumbnail_url TEXT, -- Optional thumbnail for videos
  caption TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_profile_media_user_id ON profile_media(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_media_created_at ON profile_media(created_at DESC);

-- Enable Row Level Security
ALTER TABLE profile_media ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all profile media (public)
CREATE POLICY "profile_media_select_policy" ON profile_media
  FOR SELECT
  USING (true);

-- Policy: Users can only insert their own media
CREATE POLICY "profile_media_insert_policy" ON profile_media
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only delete their own media
CREATE POLICY "profile_media_delete_policy" ON profile_media
  FOR DELETE
  USING (auth.uid() = user_id);

-- Policy: Users can only update their own media (for caption edits)
CREATE POLICY "profile_media_update_policy" ON profile_media
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
