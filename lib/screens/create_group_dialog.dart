import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../services/messaging_service.dart';
import '../utils/error_helper.dart';

class CreateGroupDialog extends StatefulWidget {
  final Function(String? conversationId) onGroupCreated;

  const CreateGroupDialog({
    super.key,
    required this.onGroupCreated,
  });

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _availableUsers = [];
  List<Map<String, dynamic>> _selectedUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await MessagingService.getMutualFollowersForMessaging();
      if (mounted) {
        setState(() {
          _availableUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ErrorHelper.showError(context, 'Error loading users: $e');
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _availableUsers;
      });
    } else {
      setState(() {
        _filteredUsers = _availableUsers.where((user) {
          final displayName = user['display_name'] as String? ?? '';
          final username = user['username'] as String? ?? '';
          return displayName.toLowerCase().contains(query) ||
                 username.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  void _toggleUserSelection(Map<String, dynamic> user) {
    setState(() {
      final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
      if (isSelected) {
        _selectedUsers.removeWhere((u) => u['id'] == user['id']);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ErrorHelper.showError(context, 'Group name is required');
      return;
    }

    try {
      final participantIds = _selectedUsers.map((u) => u['id'] as String).toList();
      
      final conversationId = await MessagingService.createGroupConversation(
        name: groupName,
        description: _groupDescriptionController.text.trim().isNotEmpty 
            ? _groupDescriptionController.text.trim() 
            : null,
        participantIds: participantIds,
      );

      widget.onGroupCreated(conversationId);
    } catch (e) {
      ErrorHelper.showError(context, 'Error creating group: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);

    return AlertDialog(
      backgroundColor: Colors.black,
      title: const Text(
        'Create Group',
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
            // Group name field
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _groupNameController,
                style: const TextStyle(color: matrixGreen),
                decoration: const InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: matrixGreen),
                  prefixIcon: Icon(Icons.group, color: matrixGreen),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Group description field (optional)
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _groupDescriptionController,
                style: const TextStyle(color: matrixGreen),
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(color: matrixGreen),
                  prefixIcon: Icon(Icons.description, color: matrixGreen),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Selected users count
            if (_selectedUsers.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: matrixGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${_selectedUsers.length} members selected',
                  style: const TextStyle(
                    color: matrixGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Search field
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: matrixGreen),
                decoration: const InputDecoration(
                  hintText: 'Search friends to add...',
                  hintStyle: TextStyle(color: matrixGreen),
                  prefixIcon: Icon(Icons.search, color: matrixGreen),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Users list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: matrixGreen),
                    )
                  : _buildUsersList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createGroup,
          style: ElevatedButton.styleFrom(
            backgroundColor: matrixGreen,
            foregroundColor: Colors.black,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    const matrixGreen = Color(0xFF00FF41);

    if (_filteredUsers.isEmpty) {
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
              'No friends found',
              style: TextStyle(
                color: matrixGreen.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
        return _buildUserTile(user, isSelected);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isSelected) {
    const matrixGreen = Color(0xFF00FF41);
    final displayName = user['display_name'] as String? ?? 'Unknown';
    final username = user['username'] as String? ?? 'unknown';
    final avatarUrl = user['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? matrixGreen.withValues(alpha: 0.2) : Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? matrixGreen : matrixGreen.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        onTap: () => _toggleUserSelection(user),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: matrixGreen.withValues(alpha: 0.2),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  (displayName[0] ?? 'U').toUpperCase(),
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
          isSelected ? Icons.check_circle : Icons.circle_outlined,
          color: matrixGreen,
        ),
      ),
    );
  }
}
