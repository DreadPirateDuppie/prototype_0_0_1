-- Create map_posts table
CREATE TABLE map_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    likes INTEGER DEFAULT 0,
    photo_url TEXT,
    popularity_rating DOUBLE PRECISION DEFAULT 0.0,
    security_rating DOUBLE PRECISION DEFAULT 0.0,
    quality_rating DOUBLE PRECISION DEFAULT 0.0
);

-- Enable Row Level Security
ALTER TABLE map_posts ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Users can view all posts
CREATE POLICY "Users can view all posts"
ON map_posts
FOR SELECT
USING (true);

-- Users can insert their own posts
CREATE POLICY "Users can insert own posts"
ON map_posts
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own posts
CREATE POLICY "Users can update own posts"
ON map_posts
FOR UPDATE
USING (auth.uid() = user_id);

-- Users can delete their own posts
CREATE POLICY "Users can delete own posts"
ON map_posts
FOR DELETE
USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX idx_map_posts_user_id ON map_posts(user_id);
CREATE INDEX idx_map_posts_created_at ON map_posts(created_at);
CREATE INDEX idx_map_posts_location ON map_posts(latitude, longitude);
