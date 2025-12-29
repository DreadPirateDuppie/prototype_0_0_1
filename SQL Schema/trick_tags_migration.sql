-- Add tags column to spot_videos table
-- This column stores an array of tags for each trick submission

DO $$
BEGIN
    -- Add tags column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'spot_videos' AND column_name = 'tags'
    ) THEN
        ALTER TABLE spot_videos
        ADD COLUMN tags TEXT[] DEFAULT '{}' NOT NULL;
        
        RAISE NOTICE 'Added tags column to spot_videos table';
    ELSE
        RAISE NOTICE 'tags column already exists in spot_videos table';
    END IF;
END $$;

-- Create index for GIN search on tags
CREATE INDEX IF NOT EXISTS idx_spot_videos_tags ON spot_videos USING GIN (tags);

-- Add comment for documentation
COMMENT ON COLUMN spot_videos.tags IS 'Array of tags for the trick (e.g., flatground, technical, ledge)';
