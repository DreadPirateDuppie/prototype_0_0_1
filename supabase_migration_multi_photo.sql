-- Add photo_urls column to map_posts
ALTER TABLE map_posts 
ADD COLUMN IF NOT EXISTS photo_urls TEXT[] DEFAULT ARRAY[]::TEXT[];

-- Migrate existing photo_url data to photo_urls
UPDATE map_posts 
SET photo_urls = ARRAY[photo_url] 
WHERE photo_url IS NOT NULL AND (photo_urls IS NULL OR array_length(photo_urls, 1) IS NULL);

-- Create index for better performance (optional, but good practice if we query by photos)
-- CREATE INDEX IF NOT EXISTS idx_map_posts_photo_urls ON map_posts USING GIN (photo_urls);
