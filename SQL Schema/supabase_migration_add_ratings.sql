-- Add rating columns to map_posts if they don't exist
ALTER TABLE map_posts 
ADD COLUMN IF NOT EXISTS popularity_rating DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS security_rating DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS quality_rating DOUBLE PRECISION DEFAULT 0.0;

-- Create post_ratings table to track individual user ratings
CREATE TABLE IF NOT EXISTS post_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES map_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  popularity_rating DOUBLE PRECISION NOT NULL,
  security_rating DOUBLE PRECISION NOT NULL,
  quality_rating DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- Enable RLS on post_ratings
ALTER TABLE post_ratings ENABLE ROW LEVEL SECURITY;

-- Create policies for post_ratings
DROP POLICY IF EXISTS "Users can view all ratings" ON post_ratings;
CREATE POLICY "Users can view all ratings" ON post_ratings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own ratings" ON post_ratings;
CREATE POLICY "Users can insert their own ratings" ON post_ratings FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own ratings" ON post_ratings;
CREATE POLICY "Users can update their own ratings" ON post_ratings FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own ratings" ON post_ratings;
CREATE POLICY "Users can delete their own ratings" ON post_ratings FOR DELETE USING (auth.uid() = user_id);

-- Function to update average ratings on map_posts
CREATE OR REPLACE FUNCTION update_post_ratings()
RETURNS TRIGGER AS $$
DECLARE
    avg_pop DOUBLE PRECISION;
    avg_sec DOUBLE PRECISION;
    avg_qual DOUBLE PRECISION;
BEGIN
    -- Calculate new averages
    SELECT 
        COALESCE(AVG(popularity_rating), 0),
        COALESCE(AVG(security_rating), 0),
        COALESCE(AVG(quality_rating), 0)
    INTO 
        avg_pop,
        avg_sec,
        avg_qual
    FROM post_ratings
    WHERE post_id = COALESCE(NEW.post_id, OLD.post_id);

    -- Update the map_posts table
    UPDATE map_posts
    SET 
        popularity_rating = avg_pop,
        security_rating = avg_sec,
        quality_rating = avg_qual
    WHERE id = COALESCE(NEW.post_id, OLD.post_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update ratings
DROP TRIGGER IF EXISTS update_post_ratings_trigger ON post_ratings;
CREATE TRIGGER update_post_ratings_trigger
AFTER INSERT OR UPDATE OR DELETE ON post_ratings
FOR EACH ROW EXECUTE FUNCTION update_post_ratings();
