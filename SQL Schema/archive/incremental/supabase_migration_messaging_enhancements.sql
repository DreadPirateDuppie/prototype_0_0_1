-- Migration: Enhance messaging system
-- Adds functions for marking messages as read and optimized fetching

-- Function to mark all messages in a conversation as read for a user
CREATE OR REPLACE FUNCTION mark_all_messages_as_read(
    p_conversation_id UUID,
    p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
    UPDATE conversation_participants
    SET last_read_at = NOW()
    WHERE conversation_id = p_conversation_id
    AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread count for all conversations of a user
CREATE OR REPLACE FUNCTION get_total_unread_count(p_user_id UUID)
RETURNS BIGINT AS $$
DECLARE
    total_unread BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO total_unread
    FROM messages m
    JOIN conversation_participants cp ON m.conversation_id = cp.conversation_id
    WHERE cp.user_id = p_user_id
    AND m.created_at > cp.last_read_at
    AND m.sender_id != p_user_id;
    
    RETURN total_unread;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure Realtime is enabled for messages and conversations
-- Note: This usually needs to be done via the Supabase dashboard or a specific SQL command
-- depending on the Supabase version/setup.
-- ALTER PUBLICATION supabase_realtime ADD TABLE messages;
-- ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
-- ALTER PUBLICATION supabase_realtime ADD TABLE conversation_participants;
