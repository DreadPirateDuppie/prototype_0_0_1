import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_models.dart';
import 'supabase_service.dart';

class MessagingService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Conversation models
  static Future<List<Conversation>> getConversations() async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return [];

      final response = await _client.rpc('get_user_conversations', params: {
        'user_uuid': user.id,
      });

      final List<dynamic> data = response as List;
      return data.map((json) => Conversation.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<String?> getOrCreateDirectConversation(String otherUserId) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return null;

      final response = await _client.rpc('get_or_create_direct_conversation', params: {
        'user1_id': user.id,
        'user2_id': otherUserId,
      });

      return response as String?;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> createGroupConversation({
    required String name,
    String? description,
    List<String>? participantIds,
    String? avatarUrl,
    String? battleId,
  }) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return null;

      final conversation = await _client.from('conversations').insert({
        'type': 'group',
        'name': name,
        'description': description,
        'created_by': user.id,
        'avatar_url': avatarUrl,
        'battle_id': battleId,
      }).select().single();

      final conversationId = conversation['id'] as String;

      await _client.from('conversation_participants').insert({
        'conversation_id': conversationId,
        'user_id': user.id,
        'role': 'admin',
      });

      if (participantIds != null && participantIds.isNotEmpty) {
        final participants = participantIds.map((id) => {
          'conversation_id': conversationId,
          'user_id': id,
          'role': 'member',
        }).toList();

        await _client.from('conversation_participants').insert(participants);
      }

      return conversationId;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getOrCreateBattleConversation(String battleId, List<String> participantIds) async {
    try {
      // Check if conversation exists for this battle
      final response = await _client
          .from('conversations')
          .select('id')
          .eq('battle_id', battleId)
          .maybeSingle();

      if (response != null) {
        return response['id'] as String;
      }

      // Create new conversation
      return await createGroupConversation(
        name: 'Battle Chat',
        battleId: battleId,
        participantIds: participantIds,
      );
    } catch (e) {
      return null;
    }
  }

  // Messages with pagination
  static Future<List<Message>> getMessages(String conversationId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await _client
          .from('messages')
          .select('''
            *,
            sender:user_profiles!sender_id(id, username, display_name, avatar_url)
          ''')
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List;
      return data.map((json) => Message.fromJson(json)).toList().reversed.toList();
    } catch (e) {
      return [];
    }
  }

  static Future<String?> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    String? mediaName,
    int? mediaSize,
    String? replyToId,
  }) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return null;

      final message = await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'content': content,
        'message_type': messageType,
        'media_url': mediaUrl,
        'media_name': mediaName,
        'media_size': mediaSize,
        'reply_to_id': replyToId,
      }).select().single();

      await updateLastReadTime(conversationId);

      return message['id'] as String;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> markAllMessagesAsRead(String conversationId) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return false;

      await _client.rpc('mark_all_messages_as_read', params: {
        'p_conversation_id': conversationId,
        'p_user_id': user.id,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateLastReadTime(String conversationId) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return false;

      await _client
          .from('conversation_participants')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Real-time subscriptions
  static Stream<List<Conversation>> subscribeToConversations() {
    final user = SupabaseService.getCurrentUser();
    if (user == null) return Stream.value([]);

    final controller = StreamController<List<Conversation>>.broadcast();

    // Initial load
    getConversations().then((conversations) {
      if (!controller.isClosed) controller.add(conversations);
    });

    // SCALABILITY REFINE: Instead of listening to all conversations/messages, 
    // listen specifically to active participation records for this user.
    // This scales O(1) per user relative to global traffic.
    final channel = _client.channel('user_conversations:${user.id}');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversation_participants',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (payload) async {
        final conversations = await getConversations();
        if (!controller.isClosed) controller.add(conversations);
      },
    ).subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  static Stream<Message> subscribeToMessages(String conversationId) {
    final controller = StreamController<Message>.broadcast();

    final channel = _client.channel('public:messages:conversation_id=eq.$conversationId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) async {
        // Fetch the full message with sender details
        final response = await _client
            .from('messages')
            .select('''
              *,
              sender:user_profiles!sender_id(id, username, display_name, avatar_url)
            ''')
            .eq('id', payload.newRecord['id'])
            .single();
        
        if (!controller.isClosed) {
          controller.add(Message.fromJson(response));
        }
      },
    ).subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  // Typing indicators using Presence
  static RealtimeChannel subscribeToTypingIndicators(String conversationId, Function(List<String> typingUserIds) onUpdate) {
    final user = SupabaseService.getCurrentUser();
    final channel = _client.channel('typing:$conversationId');

    channel.onPresenceSync((payload) {
      final presenceState = channel.presenceState();
      final typingUserIds = <String>[];
      
      for (final presence in presenceState) {
        final p = presence as dynamic;
        final payload = p.payload as Map<String, dynamic>;
        if (payload['is_typing'] == true && payload['user_id'] != user?.id) {
          typingUserIds.add(payload['user_id'] as String);
        }
      }
      
      onUpdate(typingUserIds);
    }).subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.track({
          'user_id': user?.id,
          'is_typing': false,
        });
      }
    });

    return channel;
  }

  static Future<void> setTypingStatus(RealtimeChannel channel, bool isTyping) async {
    final user = SupabaseService.getCurrentUser();
    await channel.track({
      'user_id': user?.id,
      'is_typing': isTyping,
    });
  }

  // Get mutual followers for messaging
  static Future<List<Map<String, dynamic>>> getMutualFollowersForMessaging() async {
    try {
      final mutualFollowers = await SupabaseService.getMutualFollowers();
      return mutualFollowers;
    } catch (e) {
      return [];
    }
  }

  // Search users for starting conversations
  static Future<List<Map<String, dynamic>>> searchUsersForMessaging(String query) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return [];

      final response = await _client
          .from('user_profiles')
          .select('id, username, display_name, avatar_url')
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .neq('id', user.id)
          .limit(20);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Participant>> getConversationParticipants(String conversationId) async {
    try {
      final response = await _client
          .from('conversation_participants')
          .select('''
            *,
            user:user_profiles!user_id(id, username, display_name, avatar_url)
          ''')
          .eq('conversation_id', conversationId);

      final List<dynamic> data = response as List;
      return data.map((json) => Participant.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Archive/Unarchive conversations
  static Future<bool> archiveConversation(String conversationId) async {
    try {
      await _client
          .from('conversations')
          .update({'is_archived': true})
          .eq('id', conversationId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unarchiveConversation(String conversationId) async {
    try {
      await _client
          .from('conversations')
          .update({'is_archived': false})
          .eq('id', conversationId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete message (soft delete)
  static Future<bool> deleteMessage(String messageId) async {
    try {
      await _client
          .from('messages')
          .update({'is_deleted': true})
          .eq('id', messageId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Edit message
  static Future<bool> editMessage(String messageId, String newContent) async {
    try {
      await _client
          .from('messages')
          .update({
            'content': newContent,
            'is_edited': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Pin/Unpin conversations
  static Future<bool> pinConversation(String conversationId) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return false;

      await _client
          .from('conversation_participants')
          .update({'is_pinned': true})
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unpinConversation(String conversationId) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return false;

      await _client
          .from('conversation_participants')
          .update({'is_pinned': false})
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Mute/Unmute conversations
  static Future<bool> muteConversation(String conversationId) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return false;

      await _client
          .from('conversation_participants')
          .update({'is_muted': true})
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unmuteConversation(String conversationId) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return false;

      await _client
          .from('conversation_participants')
          .update({'is_muted': false})
          .eq('conversation_id', conversationId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Upload media files
  static Future<String?> uploadMediaFile(String filePath, String fileName, String contentType) async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final filename = 'chat_media_${user.id}_$timestamp.$extension';

      await _client.storage
          .from('post_images') // Reusing existing bucket
          .uploadBinary(
            filename,
            await File(filePath).readAsBytes(),
            fileOptions: FileOptions(contentType: contentType),
          );

      final publicUrl = _client.storage
          .from('post_images')
          .getPublicUrl(filename);

      return publicUrl;
    } catch (e) {
      return null;
    }
  }
}
