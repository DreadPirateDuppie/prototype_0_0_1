-- Migration: pro_admin_dashboard
-- Description: Adds functions for admin dashboard analytics (Active Users, Post Stats, User Growth)

-- 1. Daily Active Users (Approximated by last_sign_in_at or updated_at if sign-in tracking isn't strict)
-- Note: Supabase's auth.users table is not directly joinable in simple queries from the client usually, 
-- but we can query public.user_profiles. detailed activity tracking might need a separate table, 
-- but updates to user_profiles (e.g. last_active) is a good proxy.
-- If you don't have a 'last_active' column, we will use 'updated_at' as a rough proxy or just count creates for growth.
-- For "Active Users", let's assume valid activity updates the 'updated_at' or we just count total creates for "Growth".
-- Let's stick to "Growth" (New Users) and "Post Activity" for now as they are deterministic from existing timestamps.

-- Function: Get Daily New Users (User Growth)
CREATE OR REPLACE FUNCTION get_user_growth_stats(days_ago int DEFAULT 30)
RETURNS TABLE (
    day date,
    count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        date_series.day::date,
        COUNT(u.created_at)::bigint
    FROM
        generate_series(
            CURRENT_DATE - (days_ago - 1) * INTERVAL '1 day',
            CURRENT_DATE,
            '1 day'
        ) AS date_series(day)
    LEFT JOIN
        public.user_profiles u
    ON
        DATE(u.created_at) = date_series.day
    GROUP BY
        date_series.day
    ORDER BY
        date_series.day;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get Daily Post Stats
CREATE OR REPLACE FUNCTION get_daily_post_stats(days_ago int DEFAULT 30)
RETURNS TABLE (
    day date,
    count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        date_series.day::date,
        COUNT(p.created_at)::bigint
    FROM
        generate_series(
            CURRENT_DATE - (days_ago - 1) * INTERVAL '1 day',
            CURRENT_DATE,
            '1 day'
        ) AS date_series(day)
    LEFT JOIN
        public.map_posts p
    ON
        DATE(p.created_at) = date_series.day
    GROUP BY
        date_series.day
    ORDER BY
        date_series.day;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions (Adjust role as necessary, e.g. service_role or authenticated if RLS handles it)
GRANT EXECUTE ON FUNCTION get_user_growth_stats(int) TO authenticated;
GRANT EXECUTE ON FUNCTION get_daily_post_stats(int) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_growth_stats(int) TO service_role;
GRANT EXECUTE ON FUNCTION get_daily_post_stats(int) TO service_role;
