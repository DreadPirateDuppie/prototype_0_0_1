-- =============================================================================
-- SUPABASE ADVISOR HARDENING & OPTIMIZATION (v2.0)
-- This script addresses Security and Performance findings with safety safeguards.
-- 
-- SUMMARY:
-- 1. SECURITY: Moves PostGIS to 'extensions' schema.
-- 2. SECURITY: Enables RLS on all child partitions.
-- 3. STORAGE: Replaces unindexed FKs with optimized indices.
-- 4. PERFORMANCE: Renames unused indexes (Monitoring Phase).
-- 5. PERFORMANCE: Consolidates redundant RLS policies.
-- =============================================================================

BEGIN;

-- ========================================================
-- 1. SECURITY: EXTENSION HARDENING (Fix for spatial_ref_sys)
-- ========================================================
-- Moving PostGIS to a dedicated schema resolves the "RLS disabled in public" 
-- warning for spatial_ref_sys without requiring ownership of system tables.

-- A. Create internal schema
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- B. Update search path to include the new schema (Crucial for app stability)
-- This ensures that function calls like st_distance() still work without schema prefixing.
DO $$
DECLARE
    current_path TEXT;
BEGIN
    SELECT setting INTO current_path FROM pg_settings WHERE name = 'search_path';
    IF current_path NOT LIKE '%extensions%' THEN
        EXECUTE 'ALTER DATABASE postgres SET search_path TO ' || current_path || ', extensions';
        -- Also set for current session to avoid immediate errors
        EXECUTE 'SET search_path TO ' || current_path || ', extensions';
    END IF;
END $$;

-- C. Move the extension
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
    -- Ensure we are in a schema we have ownership over for the move
    IF (SELECT extnamespace::regnamespace::text FROM pg_extension WHERE extname = 'postgis') = 'public' THEN
      BEGIN
        ALTER EXTENSION postgis SET SCHEMA extensions;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Note: Could not move postgis via ALTER EXTENSION. This usually happens if you are not a superuser. Manual move in dashboard may be required if warning persists.';
      END;
    END IF;
  END IF;
END $$;

-- Note: RLS on spatial_ref_sys is NOT required when it is moved out of the public schema.

-- ========================================================
-- 2. SECURITY: PARTITION RLS ENFORCEMENT
-- ========================================================
-- Explicitly enabling RLS on partitions to satisfy the linter.

-- Messages Partitions
ALTER TABLE IF EXISTS public.messages_y2026m01 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.messages_y2026m02 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.messages_y2026m03 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.messages_default ENABLE ROW LEVEL SECURITY;

-- Notifications Partitions
ALTER TABLE IF EXISTS public.notifications_y2026m01 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications_y2026m02 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications_default ENABLE ROW LEVEL SECURITY;

-- Voting Partitions
ALTER TABLE IF EXISTS public.post_votes_p1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.post_votes_p2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.post_votes_p3 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.post_votes_p4 ENABLE ROW LEVEL SECURITY;

ALTER TABLE IF EXISTS public.video_upvotes_p1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.video_upvotes_p2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.video_upvotes_p3 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.video_upvotes_p4 ENABLE ROW LEVEL SECURITY;

-- ========================================================
-- 3. PERFORMANCE: INDEX OPTIMIZATION
-- ========================================================

-- Covering Foreign Keys
CREATE INDEX IF NOT EXISTS idx_post_votes_user_id ON public.post_votes(user_id);
CREATE INDEX IF NOT EXISTS idx_video_upvotes_user_id ON public.video_upvotes(user_id);

-- Unused Index Monitoring (7-Day Plan)
-- Renaming instead of dropping to allow immediate rollback if needed.
ALTER INDEX IF EXISTS public.idx_battles_turn_deadline RENAME TO to_be_dropped_idx_battles_turn_deadline;
ALTER INDEX IF EXISTS public.idx_user_profiles_username RENAME TO to_be_dropped_idx_user_profiles_username;
ALTER INDEX IF EXISTS public.idx_user_profiles_display_name RENAME TO to_be_dropped_idx_user_profiles_display_name;
ALTER INDEX IF EXISTS public.idx_user_profiles_is_admin RENAME TO to_be_dropped_idx_user_profiles_is_admin;
ALTER INDEX IF EXISTS public.idx_user_profiles_location_sharing RENAME TO to_be_dropped_idx_user_profiles_location_sharing;
ALTER INDEX IF EXISTS public.idx_user_profiles_location_updated RENAME TO to_be_dropped_idx_user_profiles_location_updated;
ALTER INDEX IF EXISTS public.idx_user_profiles_email RENAME TO to_be_dropped_idx_user_profiles_email;
ALTER INDEX IF EXISTS public.idx_user_profiles_is_banned RENAME TO to_be_dropped_idx_user_profiles_is_banned;
ALTER INDEX IF EXISTS public.idx_user_profiles_is_verified RENAME TO to_be_dropped_idx_user_profiles_is_verified;
ALTER INDEX IF EXISTS public.idx_map_posts_user_id RENAME TO to_be_dropped_idx_map_posts_user_id;
ALTER INDEX IF EXISTS public.idx_map_posts_created_at RENAME TO to_be_dropped_idx_map_posts_created_at;
ALTER INDEX IF EXISTS public.idx_map_posts_location RENAME TO to_be_dropped_idx_map_posts_location;

-- ========================================================
-- 4. PERFORMANCE: RLS POLICY CONSOLIDATION
-- ========================================================
-- Reducing evaluation overhead by merging redundant policies.

-- Map Posts: Consolidate INSERT/UPDATE/DELETE into ALL owner policy
DROP POLICY IF EXISTS "Map posts modify own" ON public.map_posts;
DROP POLICY IF EXISTS "Map posts insert by owner" ON public.map_posts;
DROP POLICY IF EXISTS "Map posts update by owner" ON public.map_posts;
DROP POLICY IF EXISTS "Map posts delete by owner" ON public.map_posts;
CREATE POLICY "Map posts manage own" ON public.map_posts 
FOR ALL 
USING ((SELECT auth.uid()) = user_id) 
WITH CHECK ((SELECT auth.uid()) = user_id);

-- Battles: Consolidate participant policies
DROP POLICY IF EXISTS "Battles modify participant" ON public.battles;
DROP POLICY IF EXISTS "Battles participant actions" ON public.battles;
CREATE POLICY "Battles manage participant" ON public.battles 
FOR ALL 
USING ((SELECT auth.uid()) IN (player1_id, player2_id))
WITH CHECK ((SELECT auth.uid()) IN (player1_id, player2_id));

-- Follows: Consolidate lifecycle policies
DROP POLICY IF EXISTS "Follows insert by follower" ON public.follows;
DROP POLICY IF EXISTS "Follows delete by follower" ON public.follows;
CREATE POLICY "Follows manage own" ON public.follows
FOR ALL
USING (follower_id = (SELECT auth.uid()))
WITH CHECK (follower_id = (SELECT auth.uid()));

-- User Profiles: Consolidate management policies
DROP POLICY IF EXISTS "User profiles update own" ON public.user_profiles;
DROP POLICY IF EXISTS "User profiles insert own" ON public.user_profiles;
CREATE POLICY "User profiles manage own" ON public.user_profiles
FOR ALL
USING ((SELECT auth.uid()) = id)
WITH CHECK ((SELECT auth.uid()) = id);

-- Spot Videos: Cleanup and consolidate
DROP POLICY IF EXISTS "Spot videos manage own" ON public.spot_videos;
CREATE POLICY "Spot videos manage own" ON public.spot_videos 
FOR ALL 
USING (submitted_by = (SELECT auth.uid()))
WITH CHECK (submitted_by = (SELECT auth.uid()));

-- Saved Posts: Consolidate
DROP POLICY IF EXISTS "Saved posts access own" ON public.saved_posts;
DROP POLICY IF EXISTS "Saved posts modify own" ON public.saved_posts;
CREATE POLICY "Saved posts access own" ON public.saved_posts
FOR ALL
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

COMMIT;
