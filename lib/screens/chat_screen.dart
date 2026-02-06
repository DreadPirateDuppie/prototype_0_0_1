import 'dart:async';
import '../utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_models.dart';
import '../services/messaging_service.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;

  const ChatScreen({
    super.key,
    required this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 20;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Participant> _participants = [];
  List<String> _typingUserIds = [];
  RealtimeChannel? _typingChannel;
  Timer? _typingTimer;

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _loadConversationDetails();
    _subscribeToMessages();
    _setupTypingIndicators();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingTimer?.cancel();
    if (_typingChannel != null) {
      MessagingService.setTypingStatus(_typingChannel!, false);
      _typingChannel!.unsubscribe();
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 && !_isLoadingMore && _hasMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      final messages = await MessagingService.getMessages(widget.conversationId, limit: _pageSize);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          _hasMore = messages.length >= _pageSize;
        });
        _scrollToBottom(animated: false);
        _markAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ErrorHelper.showError(context, 'Error loading messages: $e');
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreMessages = await MessagingService.getMessages(
        widget.conversationId,
        limit: _pageSize,
        offset: _messages.length,
      );

      if (mounted) {
        setState(() {
          _messages.insertAll(0, moreMessages);
          _isLoadingMore = false;
          _hasMore = moreMessages.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _subscribeToMessages() {
    _messageSubscription = MessagingService.subscribeToMessages(widget.conversationId).listen((newMessage) {
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.add(newMessage);
          }
        });
        _scrollToBottom();
        _markAsRead();
      }
    });
  }

  void _setupTypingIndicators() {
    _typingChannel = MessagingService.subscribeToTypingIndicators(widget.conversationId, (typingUserIds) {
      if (mounted) {
        setState(() {
          _typingUserIds = typingUserIds;
        });
      }
    });
  }

  void _onTypingChanged() {
    if (_typingTimer?.isActive ?? false) return;

    MessagingService.setTypingStatus(_typingChannel!, true);
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        MessagingService.setTypingStatus(_typingChannel!, false);
      }
    });
  }

  Future<void> _loadConversationDetails() async {
    try {
      final participants = await MessagingService.getConversationParticipants(widget.conversationId);
      if (mounted) {
        setState(() {
          _participants = participants;
        });
      }
    } catch (e) {
      AppLogger.log('Error loading conversation details: $e', name: 'ChatScreen');
    }
  }

  Future<void> _markAsRead() async {
    await MessagingService.markAllMessagesAsRead(widget.conversationId);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    MessagingService.setTypingStatus(_typingChannel!, false);
    _typingTimer?.cancel();

    try {
      await MessagingService.sendMessage(
        conversationId: widget.conversationId,
        content: content,
      );
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error sending message: $e');
      }
    }
  }

  Future<void> _sendImageMessage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final mediaUrl = await MessagingService.uploadMediaFile(
          image.path,
          image.name,
          'image/jpeg',
        );

        if (mediaUrl != null) {
          await MessagingService.sendMessage(
            conversationId: widget.conversationId,
            content: 'Image',
            messageType: 'image',
            mediaUrl: mediaUrl,
            mediaName: image.name,
          );
        } else {
          if (mounted) {
            ErrorHelper.showError(context, 'Failed to upload image');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error sending image: $e');
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          if (animated) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: matrixGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _buildChatTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: matrixGreen),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: matrixGreen),
                  )
                : _buildMessagesList(),
          ),
          _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatTitle() {
    const matrixGreen = Color(0xFF00FF41);
    
    if (_participants.isEmpty) {
      return const Text(
        'Chat',
        style: TextStyle(
          color: matrixGreen,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // For now, assume it's a direct message if there are 2 participants
    // In a real app, you'd check the conversation type
    final otherParticipants = _participants.where(
      (p) => p.userId != SupabaseService.getCurrentUser()?.id,
    ).toList();

    if (otherParticipants.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Group Chat',
            style: TextStyle(
              color: matrixGreen,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            '${_participants.length} members',
            style: TextStyle(
              color: matrixGreen.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      );
    } else if (otherParticipants.isNotEmpty) {
      final otherUser = otherParticipants.first.user;
      return Text(
        otherUser?['display_name'] ?? otherUser?['username'] ?? 'Chat',
        style: const TextStyle(
          color: matrixGreen,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      return const Text(
        'Chat',
        style: TextStyle(
          color: matrixGreen,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet. Start the conversation!',
          style: TextStyle(
            color: Color(0xFF00FF41),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 && _isLoadingMore) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Color(0xFF00FF41), strokeWidth: 2),
            ),
          );
        }
        
        final messageIndex = _isLoadingMore ? index - 1 : index;
        final message = _messages[messageIndex];
        final isMe = message.senderId == SupabaseService.getCurrentUser()?.id;
        
        // Check if we should show the sender name (group chat and not me)
        final showSenderName = !isMe && _participants.length > 2;
        
        return _buildMessageBubble(message, isMe, showSenderName);
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, bool showSenderName) {
    const matrixGreen = Color(0xFF00FF41);
    final messageType = message.messageType;
    final content = message.content;
    final sender = message.sender;
    final createdAt = message.createdAt;
    final isEdited = message.isEdited;

    // Format time
    String timeText = '';
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      timeText = '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      timeText = '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      timeText = '${difference.inMinutes}m ago';
    } else {
      timeText = 'now';
    }

    return Container(
      margin: EdgeInsets.only(
        top: 8,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderName)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 12),
              child: Text(
                sender?['display_name'] ?? sender?['username'] ?? 'Unknown',
                style: TextStyle(
                  color: matrixGreen.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? matrixGreen : Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: matrixGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (messageType == 'image' && message.mediaUrl != null)
                  _buildImageMessage(message),
                if (messageType == 'text')
                  Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.black : matrixGreen,
                      fontSize: 16,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        color: isMe ? Colors.black.withValues(alpha: 0.7) : matrixGreen.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    if (isEdited)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'edited',
                          style: TextStyle(
                            color: isMe ? Colors.black.withValues(alpha: 0.7) : matrixGreen.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(Message message) {
    final mediaUrl = message.mediaUrl!;
    final mediaName = message.mediaName;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            mediaUrl,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 150,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image),
              );
            },
          ),
          if (mediaName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                mediaName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingUserIds.isEmpty) return const SizedBox.shrink();

    final typingNames = _typingUserIds.map((id) {
      final participant = _participants.firstWhere((p) => p.userId == id, orElse: () => Participant(id: '', conversationId: '', userId: id, joinedAt: DateTime.now(), role: '', lastReadAt: DateTime.now(), isPinned: false, isMuted: false));
      return participant.user?['display_name'] ?? participant.user?['username'] ?? 'Someone';
    }).join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        '$typingNames ${_typingUserIds.length > 1 ? 'are' : 'is'} typing...',
        style: TextStyle(
          color: const Color(0xFF00FF41).withValues(alpha: 0.5),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    const matrixGreen = Color(0xFF00FF41);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: matrixGreen.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image, color: matrixGreen),
            onPressed: _sendImageMessage,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: matrixGreen),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFF00FF41)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onChanged: (_) => _onTypingChanged(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: matrixGreen),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _showChatOptions() {
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
              'Chat Options',
              style: TextStyle(
                color: Color(0xFF00FF41),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.people, color: Color(0xFF00FF41)),
              title: const Text(
                'View Members',
                style: TextStyle(color: Color(0xFF00FF41)),
              ),
              onTap: () {
                Navigator.pop(context);
                _showMembersList();
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Color(0xFF00FF41)),
              title: const Text(
                'Archive Chat',
                style: TextStyle(color: Color(0xFF00FF41)),
              ),
              onTap: () {
                Navigator.pop(context);
                _archiveChat();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMembersList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'Chat Members',
          style: TextStyle(color: Color(0xFF00FF41)),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _participants.length,
            itemBuilder: (context, index) {
              final participant = _participants[index];
              final user = participant.user;
              if (user == null) return const SizedBox.shrink();
              final role = participant.role;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  backgroundColor: const Color(0xFF00FF41).withValues(alpha: 0.2),
                  child: user['avatar_url'] == null
                      ? Text(
                          (user['display_name'] ?? user['username'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFF00FF41)),
                        )
                      : null,
                ),
                title: Text(
                  user['display_name'] ?? user['username'] ?? 'Unknown',
                  style: const TextStyle(color: Color(0xFF00FF41)),
                ),
                subtitle: Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: const Color(0xFF00FF41).withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _archiveChat() async {
    try {
      await MessagingService.archiveConversation(widget.conversationId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat archived'),
            backgroundColor: Color(0xFF00FF41),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error archiving chat: $e');
      }
    }
  }
}
