-- Migration: advanced_analytics
-- Description: Adds sophisticated analytics functions for Admin Dashboard (Retention, Health, Risk, TTV)

-- 1. Cohort Retention Analysis
-- Groups users by signup month (cohort) and tracks % active in subsequent months.
-- Activity is defined as creating a map_post.
CREATE OR REPLACE FUNCTION get_cohort_retention(months_back int DEFAULT 12)
RETURNS TABLE (
    cohort_month date,
    month_0 float,
    month_1 float,
    month_2 float,
    month_3 float,
    month_4 float,
    month_5 float,
    month_6 float,
    cohort_size bigint
) AS $$
BEGIN
    RETURN QUERY
    WITH cohorts AS (
        SELECT
            date_trunc('month', created_at)::date as cohort_date,
            id as user_id
        FROM public.user_profiles
        WHERE created_at >= date_trunc('month', current_date - (months_back || ' months')::interval)
    ),
    cohort_sizes AS (
        SELECT cohort_date, count(*) as size
        FROM cohorts
        GROUP BY cohort_date
    ),
    user_activities AS (
        SELECT
            c.user_id,
            c.cohort_date,
            -- Calculate month difference between post creation and user creation
            floor(extract(epoch from (p.created_at - c.cohort_date::timestamp)) / 2592000)::int as month_diff
        FROM cohorts c
        JOIN public.map_posts p ON p.user_id = c.user_id
        WHERE p.created_at >= c.cohort_date::timestamp
    ),
    retention_counts AS (
        SELECT
            cohort_date,
            count(DISTINCT CASE WHEN month_diff = 0 THEN user_id END) as m0,
            count(DISTINCT CASE WHEN month_diff = 1 THEN user_id END) as m1,
            count(DISTINCT CASE WHEN month_diff = 2 THEN user_id END) as m2,
            count(DISTINCT CASE WHEN month_diff = 3 THEN user_id END) as m3,
            count(DISTINCT CASE WHEN month_diff = 4 THEN user_id END) as m4,
            count(DISTINCT CASE WHEN month_diff = 5 THEN user_id END) as m5,
            count(DISTINCT CASE WHEN month_diff = 6 THEN user_id END) as m6
        FROM user_activities
        GROUP BY cohort_date
    )
    SELECT
        cs.cohort_date,
        COALESCE(rc.m0::float / NULLIF(cs.size, 0), 0) * 100,
        COALESCE(rc.m1::float / NULLIF(cs.size, 0), 0) * 100,
        COALESCE(rc.m2::float / NULLIF(cs.size, 0), 0) * 100,
        COALESCE(rc.m3::float / NULLIF(cs.size, 0), 0) * 100,
        COALESCE(rc.m4::float / NULLIF(cs.size, 0), 0) * 100,
        COALESCE(rc.m5::float / NULLIF(cs.size, 0), 0) * 100,
        COALESCE(rc.m6::float / NULLIF(cs.size, 0), 0) * 100,
        cs.size
    FROM cohort_sizes cs
    LEFT JOIN retention_counts rc ON cs.cohort_date = rc.cohort_date
    ORDER BY cs.cohort_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Stickiness Ratio (DAU / MAU)
CREATE OR REPLACE FUNCTION get_stickiness_ratio()
RETURNS TABLE (
    dau bigint,
    mau bigint,
    ratio float
) AS $$
DECLARE
    daily_active bigint;
    monthly_active bigint;
BEGIN
    -- DAU: Users who posted in last 24h
    SELECT count(DISTINCT user_id) INTO daily_active
    FROM public.map_posts
    WHERE created_at >= (now() - interval '24 hours');

    -- MAU: Users who posted in last 30d
    SELECT count(DISTINCT user_id) INTO monthly_active
    FROM public.map_posts
    WHERE created_at >= (now() - interval '30 days');

    RETURN QUERY SELECT
        daily_active,
        monthly_active,
        CASE 
            WHEN monthly_active > 0 THEN (daily_active::float / monthly_active::float) * 100
            ELSE 0.0
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Customer Health Score
-- Returns users with a score 0-100 based on activity
CREATE OR REPLACE FUNCTION get_customer_health_scores(limit_cnt int DEFAULT 50)
RETURNS TABLE (
    user_id uuid,
    username text,
    avatar_url text,
    health_score float,
    last_active_days int
) AS $$
BEGIN
    RETURN QUERY
    WITH metrics AS (
        SELECT
            u.id,
            u.username,
            u.avatar_url,
            -- Recency: Days since last post (capped at 30 days for score)
            COALESCE(extract(day from now() - max(p.created_at)), 60) as days_since_post,
            -- Frequency: Total posts in last 30 days
            count(p.id) filter (where p.created_at > now() - interval '30 days') as posts_last_30d,
            -- Wallet: Balance (normalized to max 1000 for score limits)
            COALESCE(sum(w.balance), 0) as wallet_balance
        FROM public.user_profiles u
        LEFT JOIN public.map_posts p ON p.user_id = u.id
        LEFT JOIN public.user_wallets w ON w.user_id = u.id
        GROUP BY u.id
    )
    SELECT
        id,
        metrics.username,
        metrics.avatar_url,
        -- Scoring Algorithm:
        -- Recency (40%): 40 pts if active today, decreasing to 0 if >30 days inactive
        (CASE WHEN days_since_post > 30 THEN 0 ELSE (30 - days_since_post) / 30.0 * 40 END) +
        -- Frequency (40%): 2 pts per post, max 40 pts (20 posts)
        LEAST(posts_last_30d * 2, 40) +
        -- Wallet (20%): 1 pt per 50 units, max 20 pts (1000 units)
        LEAST(wallet_balance / 50.0, 20)
        as score,
        days_since_post::int
    FROM metrics
    ORDER BY score DESC -- Default to showing healthiest customers first
    LIMIT limit_cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Time To Value (TTV)
-- Average time (hours) from user creation to first post
CREATE OR REPLACE FUNCTION get_time_to_value_stats()
RETURNS float AS $$
DECLARE
    avg_hours float;
BEGIN
    SELECT
        AVG(extract(epoch FROM (first_post_time - user_created_time)) / 3600.0)
    INTO avg_hours
    FROM (
        SELECT
            u.created_at as user_created_time,
            min(p.created_at) as first_post_time
        FROM public.user_profiles u
        JOIN public.map_posts p ON p.user_id = u.id
        GROUP BY u.id
    ) t;

    RETURN COALESCE(avg_hours, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. At-Risk Users Alert
-- Users who were active last week but dropped activity by >50% this week
CREATE OR REPLACE FUNCTION get_at_risk_users(limit_cnt int DEFAULT 20)
RETURNS TABLE (
    user_id uuid,
    username text,
    activity_last_week bigint,
    activity_this_week bigint,
    drop_percentage float
) AS $$
BEGIN
    RETURN QUERY
    WITH weekly_activity AS (
        SELECT
            u.id,
            u.username,
            count(p.id) filter (where p.created_at >= now() - interval '7 days') as this_week,
            count(p.id) filter (where p.created_at >= now() - interval '14 days' AND p.created_at < now() - interval '7 days') as last_week
        FROM public.user_profiles u
        JOIN public.map_posts p ON p.user_id = u.id
        WHERE p.created_at >= now() - interval '14 days'
        GROUP BY u.id
    )
    SELECT
        id,
        weekly_activity.username,
        last_week,
        this_week,
        CASE WHEN last_week > 0 THEN ((last_week - this_week)::float / last_week::float) * 100 ELSE 0 END as drop_pct
    FROM weekly_activity
    WHERE last_week > 2 -- Filter out low volume users to avoid noise
      AND this_week < (last_week * 0.5) -- Activity dropped by >50%
    ORDER BY drop_pct DESC
    LIMIT limit_cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Permissions
GRANT EXECUTE ON FUNCTION get_cohort_retention(int) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_stickiness_ratio() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_customer_health_scores(int) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_time_to_value_stats() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_at_risk_users(int) TO authenticated, service_role;
