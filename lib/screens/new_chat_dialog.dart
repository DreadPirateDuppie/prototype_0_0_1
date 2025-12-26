import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../services/messaging_service.dart';
import '../utils/error_helper.dart';

class NewChatDialog extends StatefulWidget {
  final Function(String? conversationId) onChatCreated;

  const NewChatDialog({
    super.key,
    required this.onChatCreated,
  });

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  List<Map<String, dynamic>> _mutualFollowers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMutualFollowers();
  }

  Future<void> _loadMutualFollowers() async {
    try {
      final followers = await MessagingService.getMutualFollowersForMessaging();
      if (mounted) {
        setState(() {
          _mutualFollowers = followers;
          _searchResults = followers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ErrorHelper.showError(context, 'Error loading friends: $e');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = _mutualFollowers;
      });
    } else {
      setState(() {
        _searchResults = _mutualFollowers.where((user) {
          final displayName = user['display_name'] as String? ?? '';
          final username = user['username'] as String? ?? '';
          return displayName.toLowerCase().contains(query.toLowerCase()) ||
                 username.toLowerCase().contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  Future<void> _startChatWithUser(Map<String, dynamic> user) async {
    try {
      final conversationId = await MessagingService.getOrCreateDirectConversation(user['id']);
      widget.onChatCreated(conversationId);
    } catch (e) {
      ErrorHelper.showError(context, 'Error starting chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);

    return AlertDialog(
      backgroundColor: Colors.black,
      title: const Text(
        'New Chat',
        style: TextStyle(
          color: matrixGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
              ),
              child: TextField(
                style: const TextStyle(color: matrixGreen),
                decoration: const InputDecoration(
                  hintText: 'Search friends...',
                  hintStyle: TextStyle(color: matrixGreen),
                  prefixIcon: Icon(Icons.search, color: matrixGreen),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 16),
            // Friends list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: matrixGreen),
                    )
                  : _buildFriendsList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildFriendsList() {
    const matrixGreen = Color(0xFF00FF41);

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 48,
              color: matrixGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                  ? 'No friends to chat with'
                  : 'No friends found',
              style: TextStyle(
                color: matrixGreen.withValues(alpha: 0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildFriendTile(user);
      },
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> user) {
    const matrixGreen = Color(0xFF00FF41);
    final displayName = user['display_name'] as String? ?? 'Unknown';
    final username = user['username'] as String? ?? 'unknown';
    final avatarUrl = user['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: () => _startChatWithUser(user),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: matrixGreen.withValues(alpha: 0.2),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase(),
                  style: const TextStyle(
                    color: matrixGreen,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: matrixGreen,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '@$username',
          style: TextStyle(
            color: matrixGreen.withValues(alpha: 0.7),
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chat_bubble_outline,
          color: matrixGreen.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
