-- RPC for Battle Leaderboard
-- Returns top players by battle score with win/loss counts

DROP FUNCTION IF EXISTS get_battle_leaderboard(INTEGER);

CREATE OR REPLACE FUNCTION get_battle_leaderboard(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    display_name TEXT,
    avatar_url TEXT,
    player_score DOUBLE PRECISION,
    ranking_score DOUBLE PRECISION,
    wins INTEGER,
    losses INTEGER,
    total_battles INTEGER,
    win_percentage DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            up.id as user_id,
            up.username,
            up.display_name,
            up.avatar_url,
            COALESCE(us.player_score, 0)::DOUBLE PRECISION as player_score,
            COALESCE(us.ranking_score, 0)::DOUBLE PRECISION as ranking_score,
            COALESCE((SELECT COUNT(*)::INTEGER FROM battles b WHERE b.winner_id = up.id AND b.status = 'completed'), 0) as wins,
            COALESCE((SELECT COUNT(*)::INTEGER FROM battles b WHERE (b.player1_id = up.id OR b.player2_id = up.id) AND b.winner_id != up.id AND b.status = 'completed'), 0) as losses
        FROM 
            user_profiles up
        LEFT JOIN 
            user_scores us ON up.id = us.user_id
    )
    SELECT 
        *,
        (wins + losses) as total_battles,
        CASE 
            WHEN (wins + losses) > 0 THEN (wins::DOUBLE PRECISION / (wins + losses) * 100)
            ELSE 0 
        END as win_percentage
    FROM stats
    ORDER BY player_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access
GRANT EXECUTE ON FUNCTION get_battle_leaderboard(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_battle_leaderboard(INTEGER) TO anon;
