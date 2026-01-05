import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme_config.dart';
import '../../screens/user_profile_screen.dart';

class OnlineFriendsList extends StatelessWidget {
  final List<Map<String, dynamic>> onlineFriends;
  final Function(LatLng) onNavigateToMap;

  const OnlineFriendsList({
    super.key,
    required this.onlineFriends,
    required this.onNavigateToMap,
  });

  @override
  Widget build(BuildContext context) {
    if (onlineFriends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Text(
                'ONLINE FRIENDS',
                style: TextStyle(
                  color: ThemeColors.neonGreen,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ThemeColors.neonGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ThemeColors.neonGreen.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${onlineFriends.length}',
                  style: const TextStyle(
                    color: ThemeColors.neonGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 80, // Reduced height for row-style cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: onlineFriends.length,
            itemBuilder: (context, index) => _buildHorizontalFriendCard(context, onlineFriends[index]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHorizontalFriendCard(BuildContext context, Map<String, dynamic> user) {
    const matrixGreen = ThemeColors.neonGreen;

    return Container(
      width: 240, // Much wider to fit text
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: matrixGreen.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: matrixGreen.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: matrixGreen, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 20,
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
          const SizedBox(width: 12),
          
          // Info Column
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['display_name'] ?? user['username'] ?? 'User',
                  style: const TextStyle(
                    color: matrixGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        user['location_name'] ?? 'Online',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),

          // Action Button
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: () {
                final lat = user['current_latitude'] as double?;
                final lng = user['current_longitude'] as double?;
                if (lat != null && lng != null) {
                  onNavigateToMap(LatLng(lat, lng));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: matrixGreen.withValues(alpha: 0.1),
                foregroundColor: matrixGreen,
                side: const BorderSide(color: matrixGreen, width: 1),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                minimumSize: const Size(0, 0),
              ),
              child: const Icon(Icons.location_on, size: 14, color: matrixGreen),
            ),
          ),
        ],
      ),
    );
  }
}
