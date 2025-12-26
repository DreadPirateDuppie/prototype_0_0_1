-- Upvote/Downvote System Database Migration
-- Run these commands in your Supabase SQL Editor

-- 1. Create post_votes table
CREATE TABLE IF NOT EXISTS post_votes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES map_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type INTEGER NOT NULL CHECK (vote_type IN (-1, 1)),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_post_votes_post_id ON post_votes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_votes_user_id ON post_votes(user_id);

-- 3. Add vote columns to map_posts table
ALTER TABLE map_posts 
ADD COLUMN IF NOT EXISTS upvotes INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS downvotes INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS vote_score INTEGER DEFAULT 0;

-- 4. Create function to update vote counts
CREATE OR REPLACE FUNCTION update_post_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.vote_type = 1 THEN
      UPDATE map_posts SET upvotes = upvotes + 1, vote_score = vote_score + 1 WHERE id = NEW.post_id;
    ELSE
      UPDATE map_posts SET downvotes = downvotes + 1, vote_score = vote_score - 1 WHERE id = NEW.post_id;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.vote_type = 1 AND NEW.vote_type = -1 THEN
      UPDATE map_posts SET upvotes = upvotes - 1, downvotes = downvotes + 1, vote_score = vote_score - 2 WHERE id = NEW.post_id;
    ELSIF OLD.vote_type = -1 AND NEW.vote_type = 1 THEN
      UPDATE map_posts SET upvotes = upvotes + 1, downvotes = downvotes - 1, vote_score = vote_score + 2 WHERE id = NEW.post_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.vote_type = 1 THEN
      UPDATE map_posts SET upvotes = upvotes - 1, vote_score = vote_score - 1 WHERE id = OLD.post_id;
    ELSE
      UPDATE map_posts SET downvotes = downvotes - 1, vote_score = vote_score + 1 WHERE id = OLD.post_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger to automatically update vote counts
DROP TRIGGER IF EXISTS post_vote_counts_trigger ON post_votes;
CREATE TRIGGER post_vote_counts_trigger
AFTER INSERT OR UPDATE OR DELETE ON post_votes
FOR EACH ROW EXECUTE FUNCTION update_post_vote_counts();

-- 6. Enable Row Level Security
ALTER TABLE post_votes ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies for post_votes
CREATE POLICY "Users can view all votes" ON post_votes FOR SELECT USING (true);
CREATE POLICY "Users can insert their own votes" ON post_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own votes" ON post_votes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own votes" ON post_votes FOR DELETE USING (auth.uid() = user_id);
