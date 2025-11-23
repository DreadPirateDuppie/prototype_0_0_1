-- Create the post_ratings table
CREATE TABLE IF NOT EXISTS post_ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES map_posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  popularity_rating DECIMAL NOT NULL,
  security_rating DECIMAL NOT NULL,
  quality_rating DECIMAL NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- Enable Row Level Security
ALTER TABLE post_ratings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read all ratings
CREATE POLICY "Ratings are visible to everyone"
  ON post_ratings FOR SELECT
  USING (true);

-- Policy: Users can insert their own ratings
CREATE POLICY "Users can insert their own ratings"
  ON post_ratings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own ratings
CREATE POLICY "Users can update their own ratings"
  ON post_ratings FOR UPDATE
  USING (auth.uid() = user_id);

-- Function to calculate and update average ratings on map_posts
CREATE OR REPLACE FUNCTION update_post_average_ratings()
RETURNS TRIGGER AS $$
DECLARE
  avg_popularity DECIMAL;
  avg_security DECIMAL;
  avg_quality DECIMAL;
BEGIN
  -- Calculate averages for the post
  SELECT 
    AVG(popularity_rating),
    AVG(security_rating),
    AVG(quality_rating)
  INTO 
    avg_popularity,
    avg_security,
    avg_quality
  FROM post_ratings
  WHERE post_id = NEW.post_id;

  -- Update the map_posts table
  UPDATE map_posts
  SET 
    popularity_rating = COALESCE(avg_popularity, 0),
    security_rating = COALESCE(avg_security, 0),
    quality_rating = COALESCE(avg_quality, 0)
  WHERE id = NEW.post_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to run the function after insert or update
DROP TRIGGER IF EXISTS update_post_ratings_trigger ON post_ratings;
CREATE TRIGGER update_post_ratings_trigger
AFTER INSERT OR UPDATE ON post_ratings
FOR EACH ROW
EXECUTE FUNCTION update_post_average_ratings();
