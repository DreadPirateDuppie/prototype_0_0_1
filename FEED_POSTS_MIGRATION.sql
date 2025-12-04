-- Make latitude and longitude nullable to support feed-only posts
ALTER TABLE map_posts ALTER COLUMN latitude DROP NOT NULL;
ALTER TABLE map_posts ALTER COLUMN longitude DROP NOT NULL;
