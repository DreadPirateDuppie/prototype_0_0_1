-- Fix missing is_verified column in map_posts table
-- This column is required for the verification feature

DO $$
BEGIN
    -- 1. Add is_verified column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'map_posts' AND column_name = 'is_verified'
    ) THEN
        ALTER TABLE map_posts
        ADD COLUMN is_verified BOOLEAN DEFAULT FALSE NOT NULL;
        
        RAISE NOTICE 'Added is_verified column to map_posts table';
    ELSE
        -- 2. If it exists, ensure NULL values are fixed and constraints are set
        UPDATE map_posts
        SET is_verified = FALSE
        WHERE is_verified IS NULL;

        ALTER TABLE map_posts 
        ALTER COLUMN is_verified SET DEFAULT FALSE,
        ALTER COLUMN is_verified SET NOT NULL;
        
        RAISE NOTICE 'Fixed is_verified column constraints in map_posts table';
    END IF;
END $$;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_map_posts_is_verified ON map_posts(is_verified);

-- Add comment for documentation
COMMENT ON COLUMN map_posts.is_verified IS 'Whether the post has been verified by an administrator';
