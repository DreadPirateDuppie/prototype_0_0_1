-- Create post_likes table to track individual user likes
CREATE TABLE post_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES map_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- Enable Row Level Security
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Users can view likes on posts they can see
CREATE POLICY "Users can view post likes"
ON post_likes
FOR SELECT
USING (true);

-- Users can insert their own likes
CREATE POLICY "Users can insert own likes"
ON post_likes
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own likes
CREATE POLICY "Users can delete own likes"
ON post_likes
FOR DELETE
USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX idx_post_likes_user_id ON post_likes(user_id);

-- Update map_posts table to add rating counts
ALTER TABLE map_posts
ADD COLUMN popularity_rating_count INTEGER DEFAULT 0,
ADD COLUMN security_rating_count INTEGER DEFAULT 0,
ADD COLUMN quality_rating_count INTEGER DEFAULT 0;

-- Create post_ratings table to track individual ratings
CREATE TABLE post_ratings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES map_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    popularity_rating INTEGER NOT NULL CHECK (popularity_rating >= 1 AND popularity_rating <= 5),
    security_rating INTEGER NOT NULL CHECK (security_rating >= 1 AND security_rating <= 5),
    quality_rating INTEGER NOT NULL CHECK (quality_rating >= 1 AND quality_rating <= 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- Enable Row Level Security
ALTER TABLE post_ratings ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Users can view ratings on posts they can see
CREATE POLICY "Users can view post ratings"
ON post_ratings
FOR SELECT
USING (true);

-- Users can insert their own ratings
CREATE POLICY "Users can insert own ratings"
ON post_ratings
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own ratings
CREATE POLICY "Users can update own ratings"
ON post_ratings
FOR UPDATE
USING (auth.uid() = user_id);

-- Users can delete their own ratings
CREATE POLICY "Users can delete own ratings"
ON post_ratings
FOR DELETE
USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX idx_post_ratings_post_id ON post_ratings(post_id);
CREATE INDEX idx_post_ratings_user_id ON post_ratings(user_id);

-- Function to update post ratings when a rating is added/updated/deleted
CREATE OR REPLACE FUNCTION update_post_ratings()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the map_posts table with new average ratings and counts
    UPDATE map_posts
    SET
        popularity_rating = COALESCE((
            SELECT AVG(popularity_rating)::float
            FROM post_ratings
            WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
        ), 0.0),
        security_rating = COALESCE((
            SELECT AVG(security_rating)::float
            FROM post_ratings
            WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
        ), 0.0),
        quality_rating = COALESCE((
            SELECT AVG(quality_rating)::float
            FROM post_ratings
            WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
        ), 0.0),
        popularity_rating_count = (
            SELECT COUNT(*)
            FROM post_ratings
            WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
        ),
        security_rating_count = (
            SELECT COUNT(*)
            FROM post_ratings
            WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
        ),
        quality_rating_count = (
            SELECT COUNT(*)
            FROM post_ratings
            WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
        )
    WHERE id = COALESCE(NEW.post_id, OLD.post_id);

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update ratings
CREATE TRIGGER trigger_update_post_ratings_insert
    AFTER INSERT ON post_ratings
    FOR EACH ROW EXECUTE FUNCTION update_post_ratings();

CREATE TRIGGER trigger_update_post_ratings_update
    AFTER UPDATE ON post_ratings
    FOR EACH ROW EXECUTE FUNCTION update_post_ratings();

CREATE TRIGGER trigger_update_post_ratings_delete
    AFTER DELETE ON post_ratings
    FOR EACH ROW EXECUTE FUNCTION update_post_ratings();

-- Function to update likes count when likes are added/removed
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE map_posts
    SET likes = (
        SELECT COUNT(*)
        FROM post_likes
        WHERE post_id = COALESCE(NEW.post_id, OLD.post_id)
    )
    WHERE id = COALESCE(NEW.post_id, OLD.post_id);

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update likes count
CREATE TRIGGER trigger_update_post_likes_count_insert
    AFTER INSERT ON post_likes
    FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

CREATE TRIGGER trigger_update_post_likes_count_delete
    AFTER DELETE ON post_likes
    FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();
