import 'package:supabase_flutter/supabase_flutter.dart';

enum ConversationType { direct, group }

class Conversation {
  final String id;
  final ConversationType type;
  final String? name;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;
  final bool isArchived;
  final String? avatarUrl;
  final int participantCount;
  final String? lastMessagePreview;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    required this.isArchived,
    this.avatarUrl,
    this.participantCount = 0,
    this.lastMessagePreview,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      type: json['type'] == 'direct' ? ConversationType.direct : ConversationType.group,
      name: json['name'],
      description: json['description'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastMessageAt: DateTime.parse(json['last_message_at']),
      isArchived: json['is_archived'] ?? false,
      avatarUrl: json['avatar_url'],
      participantCount: json['participant_count'] ?? 0,
      lastMessagePreview: json['last_message_preview'],
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String messageType;
  final String? mediaUrl;
  final String? mediaName;
  final int? mediaSize;
  final String? replyToId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isEdited;
  final Map<String, dynamic>? sender;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.mediaUrl,
    this.mediaName,
    this.mediaSize,
    this.replyToId,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.isEdited,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      messageType: json['message_type'] ?? 'text',
      mediaUrl: json['media_url'],
      mediaName: json['media_name'],
      mediaSize: json['media_size'],
      replyToId: json['reply_to_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isDeleted: json['is_deleted'] ?? false,
      isEdited: json['is_edited'] ?? false,
      sender: json['sender'],
    );
  }
}

class Participant {
  final String id;
  final String conversationId;
  final String userId;
  final DateTime joinedAt;
  final String role;
  final DateTime lastReadAt;
  final bool isPinned;
  final bool isMuted;
  final Map<String, dynamic>? user;

  Participant({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.joinedAt,
    required this.role,
    required this.lastReadAt,
    required this.isPinned,
    required this.isMuted,
    this.user,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      joinedAt: DateTime.parse(json['joined_at']),
      role: json['role'] ?? 'member',
      lastReadAt: DateTime.parse(json['last_read_at']),
      isPinned: json['is_pinned'] ?? false,
      isMuted: json['is_muted'] ?? false,
      user: json['user'],
    );
  }
}
