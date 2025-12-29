import 'package:flutter/material.dart';
import '../models/message_models.dart';
import '../services/messaging_service.dart';
import '../screens/chat_screen.dart';
import '../screens/create_group_dialog.dart';
import '../screens/new_chat_dialog.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: matrixGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CHATS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: matrixGreen,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: matrixGreen),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: matrixGreen),
            onPressed: _showNewChatOptions,
          ),
        ],
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: MessagingService.subscribeToConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: matrixGreen),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final conversations = snapshot.data ?? [];
          return _buildContent(conversations);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: matrixGreen,
        onPressed: _showNewChatOptions,
        child: const Icon(Icons.chat_bubble, color: Colors.black),
      ),
    );
  }

  Widget _buildContent(List<Conversation> conversations) {
    const matrixGreen = Color(0xFF00FF41);

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: matrixGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                color: matrixGreen,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a chat with your friends!',
              style: TextStyle(
                fontSize: 14,
                color: matrixGreen,
              ),
            ),
          ],
        ),
      );
    }

    final filteredConversations = _filterConversations(conversations);

    return RefreshIndicator(
      onRefresh: () async {
        // StreamBuilder will handle the refresh automatically if the stream updates,
        // but we can trigger a manual fetch if needed.
        setState(() {});
      },
      child: ListView.builder(
        itemCount: filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = filteredConversations[index];
          return _buildConversationTile(conversation);
        },
      ),
    );
  }

  List<Conversation> _filterConversations(List<Conversation> conversations) {
    if (_searchQuery.isEmpty) return conversations;

    return conversations.where((conversation) {
      final name = conversation.name;
      final lastMessage = conversation.lastMessagePreview;
      
      return (name?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             (lastMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  Widget _buildConversationTile(Conversation conversation) {
    const matrixGreen = Color(0xFF00FF41);
    final isGroup = conversation.type == ConversationType.group;
    final name = conversation.name;
    final lastMessage = conversation.lastMessagePreview;
    final unreadCount = conversation.unreadCount;
    final participantCount = conversation.participantCount;
    final lastMessageAt = conversation.lastMessageAt;
    final avatarUrl = conversation.avatarUrl;

    // Format last message time
    String timeText = '';
    final now = DateTime.now();
    final difference = now.difference(lastMessageAt);

    if (difference.inDays > 0) {
      timeText = '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      timeText = '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      timeText = '${difference.inMinutes}m';
    } else {
      timeText = 'now';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: () => _openChat(conversation.id),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: matrixGreen.withValues(alpha: 0.2),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Icon(
                      isGroup ? Icons.group : Icons.person,
                      color: matrixGreen,
                    )
                  : null,
            ),
            if (isGroup && participantCount > 0)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: matrixGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$participantCount',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name ?? (isGroup ? 'Group Chat' : 'Direct Message'),
          style: const TextStyle(
            color: matrixGreen,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          lastMessage ?? 'No messages yet',
          style: TextStyle(
            color: matrixGreen.withValues(alpha: 0.7),
            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: TextStyle(
                  color: matrixGreen.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: matrixGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openChat(String conversationId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversationId: conversationId),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'Search Conversations',
          style: TextStyle(color: Color(0xFF00FF41)),
        ),
        content: TextField(
          style: const TextStyle(color: Color(0xFF00FF41)),
          decoration: const InputDecoration(
            hintText: 'Search by name or message...',
            hintStyle: TextStyle(color: Color(0xFF00FF41)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00FF41)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00FF41)),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _searchQuery = '';
              });
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Start New Chat',
              style: TextStyle(
                color: Color(0xFF00FF41),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF00FF41)),
              title: const Text(
                'Direct Message',
                style: TextStyle(color: Color(0xFF00FF41)),
              ),
              subtitle: const Text(
                'Chat with a friend',
                style: TextStyle(color: Color(0xFF00FF41)),
              ),
              onTap: () {
                Navigator.pop(context);
                _showNewChatDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group, color: Color(0xFF00FF41)),
              title: const Text(
                'Group Chat',
                style: TextStyle(color: Color(0xFF00FF41)),
              ),
              subtitle: const Text(
                'Create a group with friends',
                style: TextStyle(color: Color(0xFF00FF41)),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCreateGroupDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => NewChatDialog(
        onChatCreated: (conversationId) {
          Navigator.pop(context);
          if (conversationId != null) {
            _openChat(conversationId);
          }
        },
      ),
    );
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateGroupDialog(
        onGroupCreated: (conversationId) {
          Navigator.pop(context);
          if (conversationId != null) {
            _openChat(conversationId);
          }
        },
      ),
    );
  }
}
