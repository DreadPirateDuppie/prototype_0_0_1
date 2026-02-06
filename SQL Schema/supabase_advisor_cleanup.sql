-- =============================================================================
-- SUPABASE ADVISOR CLEANUP SCRIPT (v1.2)
-- This script resolves 300+ security and performance warnings.
-- Run this ONCE in your Supabase SQL Editor.
-- =============================================================================

SET search_path = public;

-- 1. SECURITY: Fix Function Search Path
DROP FUNCTION IF EXISTS update_post_vote_counts() CASCADE;

DO $$
BEGIN
    BEGIN
        ALTER FUNCTION handle_new_user() SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
    
    BEGIN
        ALTER FUNCTION award_points_atomic(uuid, numeric, text, text, text) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
    
    BEGIN
        ALTER FUNCTION get_at_risk_users(int) SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
    
    BEGIN
        ALTER FUNCTION update_user_map_xp() SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
    
    BEGIN
        ALTER FUNCTION get_stickiness_ratio() SET search_path = public;
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
END $$;

-- 2. PERFORMANCE: Drop Stale Columns & Unused Indexes
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'battles' AND column_name = 'current_setter_id') THEN
        ALTER TABLE battles DROP COLUMN current_setter_id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'battles' AND column_name = 'rps_winner_id') THEN
        ALTER TABLE battles DROP COLUMN rps_winner_id;
    END IF;
END $$;

-- Drop Unused Indexes
DROP INDEX IF EXISTS idx_ghost_lines_spot_id;
DROP INDEX IF EXISTS idx_ghost_lines_creator_id;
DROP INDEX IF EXISTS idx_trick_aliases_alias;
DROP INDEX IF EXISTS error_logs_user_id_idx;
DROP INDEX IF EXISTS error_logs_created_at_idx;
DROP INDEX IF EXISTS error_logs_screen_name_idx;
DROP INDEX IF EXISTS idx_skate_lobbies_code;
DROP INDEX IF EXISTS idx_skate_lobby_players_lobby;
DROP INDEX IF EXISTS idx_battle_tricks_battle_id;
DROP INDEX IF EXISTS idx_battle_tricks_created_at;
DROP INDEX IF EXISTS idx_trick_nodes_category;
DROP INDEX IF EXISTS idx_user_trick_progress_user_id;
DROP INDEX IF EXISTS idx_user_trick_progress_status;
DROP INDEX IF EXISTS idx_battles_bet_accepted;
DROP INDEX IF EXISTS idx_user_profiles_can_post;
DROP INDEX IF EXISTS idx_user_profiles_is_premium;

-- Deduplicate Remaining
DROP INDEX IF EXISTS idx_conversation_participants_conv_id; 
DROP INDEX IF EXISTS follows_follower_id_idx; 
DROP INDEX IF EXISTS follows_following_id_idx; 
DROP INDEX IF EXISTS map_posts_category_idx; 
DROP INDEX IF EXISTS idx_skate_lobby_events_lobby; 

-- 4. PERFORMANCE: Add Missing Foreign Key Indexes
CREATE INDEX IF NOT EXISTS idx_battles_player1_id ON battles(player1_id);
CREATE INDEX IF NOT EXISTS idx_battles_player2_id ON battles(player2_id);
CREATE INDEX IF NOT EXISTS idx_battles_current_turn_player_id ON battles(current_turn_player_id);
CREATE INDEX IF NOT EXISTS idx_battles_winner_id ON battles(winner_id);
CREATE INDEX IF NOT EXISTS idx_battles_setter_id ON battles(setter_id);
CREATE INDEX IF NOT EXISTS idx_battles_attempter_id ON battles(attempter_id);

-- 5. PERFORMANCE & SECURITY: Total RLS Policy Reset
DO $$ 
DECLARE 
    table_name_var text;
    tables_to_fix text[] := ARRAY[
        'user_profiles', 'map_posts', 'post_ratings', 'post_votes', 
        'saved_posts', 'post_reports', 'battles', 'battle_tricks', 
        'user_wallets', 'point_transactions', 'daily_streaks', 
        'user_scores', 'notifications', 'user_feedback', 'error_logs',
        'matchmaking_queue', 'skate_lobbies', 'skate_lobby_players', 
        'skate_lobby_events', 'app_settings', 'donations', 'follows',
        'conversations', 'conversation_participants', 'messages',
        'spot_videos', 'video_upvotes', 'xp_history', 'sponsorship_offers'
    ];
BEGIN
    FOREACH table_name_var IN ARRAY tables_to_fix LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = table_name_var) THEN
            FOR policy_record IN 
                SELECT policyname, tablename 
                FROM pg_policies 
                WHERE schemaname = 'public' AND tablename = table_name_var
            LOOP
                EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(policy_record.policyname) || ' ON ' || quote_ident(policy_record.tablename);
            END LOOP;
        END IF;
    END LOOP;
END $$;

-- 6. RECREATE OPTIMIZED POLICIES

-- user_profiles
CREATE POLICY "Profiles are viewable by everyone" ON user_profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING ((SELECT auth.uid()) = id);
CREATE POLICY "Users can insert own profile" ON user_profiles FOR INSERT WITH CHECK ((SELECT auth.uid()) = id);

-- map_posts
CREATE POLICY "Map posts access" ON map_posts FOR ALL 
    USING (true) 
    WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND user_id = (SELECT auth.uid()));

-- error_logs
CREATE POLICY "Error logs access" ON error_logs FOR ALL
    USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true))
    WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

-- point_transactions
CREATE POLICY "Point transactions access" ON point_transactions FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- user_wallets
CREATE POLICY "User wallets access" ON user_wallets FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- post_reports (Admins can manage, Users can insert and view own)
CREATE POLICY "Post reports management" ON post_reports FOR ALL
    USING (
        EXISTS (SELECT 1 FROM user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true)
        OR reporter_user_id = (SELECT auth.uid())
    )
    WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

-- app_settings
CREATE POLICY "Admins can manage app_settings" ON app_settings FOR ALL USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true));

-- battles
CREATE POLICY "Battles access" ON battles FOR ALL
    USING ((SELECT auth.uid()) = player1_id OR (SELECT auth.uid()) = player2_id)
    WITH CHECK ((SELECT auth.uid()) = player1_id);

-- battle_tricks
CREATE POLICY "Battle tricks access" ON battle_tricks FOR ALL
    USING (true)
    WITH CHECK ((SELECT auth.uid()) = setter_id);

-- matchmaking_queue
CREATE POLICY "Matchmaking queue access" ON matchmaking_queue FOR ALL 
    USING ((SELECT auth.role()) = 'authenticated') 
    WITH CHECK ((SELECT auth.role()) = 'authenticated');

-- skate_lobbies
CREATE POLICY "Skate lobbies access" ON skate_lobbies FOR ALL USING ((SELECT auth.role()) = 'authenticated') WITH CHECK ((SELECT auth.role()) = 'authenticated');
CREATE POLICY "Skate lobby players access" ON skate_lobby_players FOR ALL USING ((SELECT auth.role()) = 'authenticated') WITH CHECK ((SELECT auth.role()) = 'authenticated');
CREATE POLICY "Skate lobby events access" ON skate_lobby_events FOR ALL USING ((SELECT auth.role()) = 'authenticated') WITH CHECK ((SELECT auth.role()) = 'authenticated');

-- notifications
CREATE POLICY "Notifications access" ON notifications FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- user_feedback
CREATE POLICY "User feedback access" ON user_feedback FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- follows
CREATE POLICY "Follows access" ON follows FOR ALL
    USING (true)
    WITH CHECK ((SELECT auth.uid()) = follower_id);

-- conversations / messages / participants
CREATE POLICY "Conversations access" ON conversations FOR ALL 
    USING (EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = conversations.id AND user_id = (SELECT auth.uid())))
    WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "Conversation participants access" ON conversation_participants FOR ALL
    USING (EXISTS (SELECT 1 FROM conversation_participants cp2 WHERE cp2.conversation_id = conversation_participants.conversation_id AND cp2.user_id = (SELECT auth.uid())))
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Messages access" ON messages FOR ALL
    USING (EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = messages.conversation_id AND user_id = (SELECT auth.uid())))
    WITH CHECK (sender_id = (SELECT auth.uid()));

-- post_ratings
CREATE POLICY "Post ratings access" ON post_ratings FOR ALL
    USING (true)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- post_votes
CREATE POLICY "Post votes access" ON post_votes FOR ALL
    USING (true)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- spot_videos / video_upvotes
CREATE POLICY "Spot videos access" ON spot_videos FOR ALL
    USING (status = 'approved' OR submitted_by = (SELECT auth.uid()))
    WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY "Video upvotes access" ON video_upvotes FOR ALL
    USING (true)
    WITH CHECK (user_id = (SELECT auth.uid()));

-- daily_streaks / saved_posts
CREATE POLICY "Daily streaks access" ON daily_streaks FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Saved posts access" ON saved_posts FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- user_scores / xp_history
CREATE POLICY "User scores access" ON user_scores FOR ALL
    USING (true)
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "XP history access" ON xp_history FOR ALL
    USING (
        EXISTS (SELECT 1 FROM user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true)
        OR (SELECT auth.uid()) = user_id
    )
    WITH CHECK ((SELECT auth.uid()) = user_id);

-- donations / sponsorship_offers
CREATE POLICY "Donations access" ON donations FOR ALL
    USING (
        EXISTS (SELECT 1 FROM user_profiles WHERE id = (SELECT auth.uid()) AND is_admin = true)
        OR (SELECT auth.uid()) = user_id
    )
    WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Sponsorship offers access" ON sponsorship_offers FOR ALL
    USING (true)
    WITH CHECK (true); -- Usually restricted by app logic or role-based if needed

-- End of cleanup script
