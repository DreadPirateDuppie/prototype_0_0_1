-- Add MVP columns to map_posts table
ALTER TABLE map_posts 
ADD COLUMN IF NOT EXISTS mvp_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS mvp_score INTEGER DEFAULT 0;

-- Create function to calculate MVP
CREATE OR REPLACE FUNCTION calculate_spot_mvp()
RETURNS TRIGGER AS $$
DECLARE
    target_spot_id UUID;
    new_mvp_id UUID;
    new_mvp_score INTEGER;
BEGIN
    -- Determine the spot_id based on the operation
    IF (TG_OP = 'DELETE') THEN
        target_spot_id := OLD.spot_id;
    ELSE
        target_spot_id := NEW.spot_id;
    END IF;

    -- Calculate the new MVP for the spot
    -- We sum upvotes for each user on this spot
    SELECT 
        submitted_by, 
        SUM(upvotes) as total_votes
    INTO 
        new_mvp_id, 
        new_mvp_score
    FROM 
        spot_videos
    WHERE 
        spot_id = target_spot_id
        AND status = 'approved' -- Only count approved videos
    GROUP BY 
        submitted_by
    ORDER BY 
        total_votes DESC
    LIMIT 1;

    -- If no videos or votes, reset MVP
    IF new_mvp_id IS NULL THEN
        new_mvp_score := 0;
    END IF;

    -- Update the map_posts table
    UPDATE map_posts
    SET 
        mvp_user_id = new_mvp_id,
        mvp_score = COALESCE(new_mvp_score, 0)
    WHERE 
        id = target_spot_id;

    RETURN NULL; -- Result is ignored since this is an AFTER trigger
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update MVP on video changes or vote changes
-- Note: We need to trigger this when spot_videos upvotes change. 
-- However, upvotes are usually aggregated on spot_videos from video_upvotes table.
-- If `spot_videos.upvotes` is updated by another trigger (from video_upvotes), we should listen to UPDATE on spot_videos.

DROP TRIGGER IF EXISTS trigger_update_spot_mvp ON spot_videos;

CREATE TRIGGER trigger_update_spot_mvp
AFTER INSERT OR UPDATE OF upvotes, status OR DELETE ON spot_videos
FOR EACH ROW
EXECUTE FUNCTION calculate_spot_mvp();
