-- Migration: Add messaging system tables
-- Creates tables for conversations, participants, and messages

-- Conversations table
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type VARCHAR(20) NOT NULL CHECK (type IN ('direct', 'group')),
  name VARCHAR(255), -- Group name (null for direct messages)
  description TEXT, -- Group description
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_archived BOOLEAN DEFAULT FALSE,
  avatar_url TEXT -- Group avatar URL
);

-- Conversation participants table
CREATE TABLE conversation_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member')),
  last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_pinned BOOLEAN DEFAULT FALSE,
  is_muted BOOLEAN DEFAULT FALSE,
  UNIQUE(conversation_id, user_id)
);

-- Messages table
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  content TEXT NOT NULL,
  message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'system')),
  media_url TEXT, -- For image/file messages
  media_name TEXT, -- Original filename
  media_size INTEGER, -- File size in bytes
  reply_to_id UUID REFERENCES messages(id), -- For replies
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_deleted BOOLEAN DEFAULT FALSE,
  is_edited BOOLEAN DEFAULT FALSE,
  read_by JSONB DEFAULT '[]'::jsonb -- Array of user IDs who have read this message
);

-- Create indexes for performance
CREATE INDEX idx_conversations_created_by ON conversations(created_by);
CREATE INDEX idx_conversations_type ON conversations(type);
CREATE INDEX idx_conversation_participants_user_id ON conversation_participants(user_id);
CREATE INDEX idx_conversation_participants_conversation_id ON conversation_participants(conversation_id);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_conversations_updated_at BEFORE UPDATE ON conversations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_messages_updated_at BEFORE UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to update last_message_at in conversations
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations 
    SET last_message_at = NEW.created_at 
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_conversation_last_message_trigger 
    AFTER INSERT ON messages 
    FOR EACH ROW EXECUTE FUNCTION update_conversation_last_message();

-- Add RLS (Row Level Security) policies
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Conversations policies
CREATE POLICY "Users can view conversations they participate in" ON conversations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversation_participants 
            WHERE conversation_id = conversations.id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create conversations" ON conversations
    FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY "Conversation creators and admins can update conversations" ON conversations
    FOR UPDATE USING (
        created_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM conversation_participants 
            WHERE conversation_id = conversations.id 
            AND user_id = auth.uid() 
            AND role IN ('admin', 'moderator')
        )
    );

-- Conversation participants policies
CREATE POLICY "Users can view participants of conversations they're in" ON conversation_participants
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversation_participants cp2 
            WHERE cp2.conversation_id = conversation_participants.conversation_id 
            AND cp2.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can join conversations they're invited to" ON conversation_participants
    FOR INSERT WITH CHECK (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM conversation_participants cp2 
            WHERE cp2.conversation_id = conversation_participants.conversation_id 
            AND cp2.user_id = auth.uid() 
            AND cp2.role IN ('admin', 'moderator')
        )
    );

CREATE POLICY "Users can update their own participation" ON conversation_participants
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Admins can manage all participants" ON conversation_participants
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM conversation_participants cp2 
            WHERE cp2.conversation_id = conversation_participants.conversation_id 
            AND cp2.user_id = auth.uid() 
            AND cp2.role IN ('admin', 'moderator')
        )
    );

-- Messages policies
CREATE POLICY "Users can view messages in conversations they're in" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversation_participants 
            WHERE conversation_id = messages.conversation_id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can send messages in conversations they're in" ON messages
    FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM conversation_participants 
            WHERE conversation_id = messages.conversation_id 
            AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own messages" ON messages
    FOR UPDATE USING (sender_id = auth.uid());

CREATE POLICY "Users can delete their own messages" ON messages
    FOR DELETE USING (sender_id = auth.uid());

-- Create function to get or create direct conversation between two users
CREATE OR REPLACE FUNCTION get_or_create_direct_conversation(
    user1_id UUID,
    user2_id UUID
)
RETURNS UUID AS $$
DECLARE
    conversation_id UUID;
    existing_conversation UUID;
BEGIN
    -- Check if conversation already exists
    SELECT c.id INTO existing_conversation
    FROM conversations c
    JOIN conversation_participants p1 ON c.id = p1.conversation_id
    JOIN conversation_participants p2 ON c.id = p2.conversation_id
    WHERE c.type = 'direct'
    AND p1.user_id = user1_id
    AND p2.user_id = user2_id
    LIMIT 1;

    IF existing_conversation IS NOT NULL THEN
        RETURN existing_conversation;
    END IF;

    -- Create new direct conversation
    INSERT INTO conversations (type, created_by)
    VALUES ('direct', user1_id)
    RETURNING id INTO conversation_id;

    -- Add both users as participants
    INSERT INTO conversation_participants (conversation_id, user_id, role)
    VALUES 
        (conversation_id, user1_id, 'admin'),
        (conversation_id, user2_id, 'member');

    RETURN conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get conversations for a user
CREATE OR REPLACE FUNCTION get_user_conversations(user_uuid UUID)
RETURNS TABLE (
    id UUID,
    type VARCHAR(20),
    name VARCHAR(255),
    description TEXT,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    last_message_at TIMESTAMP WITH TIME ZONE,
    is_archived BOOLEAN,
    avatar_url TEXT,
    participant_count BIGINT,
    last_message_preview TEXT,
    unread_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.type,
        c.name,
        c.description,
        c.created_by,
        c.created_at,
        c.updated_at,
        c.last_message_at,
        c.is_archived,
        c.avatar_url,
        COUNT(cp.user_id) as participant_count,
        (SELECT m.content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_preview,
        COUNT(CASE WHEN m.created_at > cp.last_read_at THEN 1 END) as unread_count
    FROM conversations c
    JOIN conversation_participants cp ON c.id = cp.conversation_id
    LEFT JOIN messages m ON c.id = m.conversation_id
    WHERE cp.user_id = user_uuid
    AND c.is_archived = FALSE
    GROUP BY c.id, cp.last_read_at
    ORDER BY c.last_message_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
