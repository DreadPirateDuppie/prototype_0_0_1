import 'package:flutter/material.dart';
import '../../screens/user_profile_screen.dart';
import '../verified_badge.dart';
import '../../config/theme_config.dart';
import '../../services/supabase_service.dart';

class UserSearchResults extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final Function(Map<String, dynamic>) onFollow;
  final Function(Map<String, dynamic>) onUnfollow;

  const UserSearchResults({
    super.key,
    required this.users,
    required this.onFollow,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'USERS',
            style: TextStyle(
              color: Color(0xFF00FF41),
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) => _buildUserCard(context, users[index]),
        ),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    const matrixGreen = ThemeColors.neonGreen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: matrixGreen.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FutureBuilder<bool>(
        future: SupabaseService.isFollowing(user['id']),
        builder: (context, snapshot) {
          final isFollowing = snapshot.data ?? false;

          return ListTile(
            leading: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: user['id'],
                      username: user['username'],
                      avatarUrl: user['avatar_url'],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: matrixGreen, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: matrixGreen.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: matrixGreen.withValues(alpha: 0.1),
                  backgroundImage: user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null
                      ? Text(
                          (user['display_name'] ?? user['username'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: matrixGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: user['id'],
                      username: user['username'],
                      avatarUrl: user['avatar_url'],
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Text(
                    user['display_name'] ?? user['username'] ?? 'Unknown User',
                    style: const TextStyle(
                      color: matrixGreen,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (user['is_verified'] == true) ...[
                    const SizedBox(width: 8),
                    const VerifiedBadge(),
                  ],
                ],
              ),
            ),
            subtitle: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: user['id'],
                      username: user['username'],
                      avatarUrl: user['avatar_url'],
                    ),
                  ),
                );
              },
              child: Text(
                '@${user['username'] ?? 'unknown'}',
                style: TextStyle(
                  color: matrixGreen.withValues(alpha: 0.7),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            trailing: SizedBox(
              width: 80,
              child: ElevatedButton(
                onPressed: () => isFollowing
                    ? onUnfollow(user)
                    : onFollow(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing
                      ? Colors.orange.withValues(alpha: 0.8)
                      : matrixGreen.withValues(alpha: 0.2),
                  foregroundColor: isFollowing ? Colors.white : matrixGreen,
                  side: BorderSide(
                    color: isFollowing ? Colors.orange : matrixGreen,
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(70, 32),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                child: Text(isFollowing ? 'UNFOLLOW' : 'FOLLOW'),
              ),
            ),
          );
        },
      ),
    );
  }
}
