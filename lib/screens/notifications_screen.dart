import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadNotifications() {
    setState(() {
      _notificationsFuture = SupabaseService.getNotifications();
    });
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    if (!notification['is_read']) {
      await SupabaseService.markNotificationRead(notification['id']);
      _loadNotifications();
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupNotificationsByDate(List<Map<String, dynamic>> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(const Duration(days: 7));

    Map<String, List<Map<String, dynamic>>> grouped = {
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    for (var notification in notifications) {
      final date = DateTime.parse(notification['created_at']).toLocal();
      final notificationDay = DateTime(date.year, date.month, date.day);

      if (notificationDay == today) {
        grouped['Today']!.add(notification);
      } else if (notificationDay == yesterday) {
        grouped['Yesterday']!.add(notification);
      } else if (notificationDay.isAfter(thisWeek)) {
        grouped['This Week']!.add(notification);
      } else {
        grouped['Earlier']!.add(notification);
      }
    }

    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: matrixGreen),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: matrixGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: matrixGreen),
            onPressed: () async {
              // Mark all as read functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Marked all as read'),
                  backgroundColor: matrixGreen,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: matrixGreen,
                strokeWidth: 2,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: matrixGreen.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load notifications',
                    style: TextStyle(color: matrixGreen.withValues(alpha: 0.7), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 80,
                    color: matrixGreen.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: matrixGreen.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When you get notifications, they\'ll show up here',
                    style: TextStyle(
                      fontSize: 14,
                      color: matrixGreen.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final groupedNotifications = _groupNotificationsByDate(notifications);

          return RefreshIndicator(
            onRefresh: () async {
              _loadNotifications();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: matrixGreen,
            backgroundColor: Colors.black,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8),
              itemCount: groupedNotifications.length,
              itemBuilder: (context, groupIndex) {
                final groupKey = groupedNotifications.keys.elementAt(groupIndex);
                final groupNotifications = groupedNotifications[groupKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        groupKey,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: matrixGreen.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Notifications in this group
                    ...groupNotifications.asMap().entries.map((entry) {
                      final index = entry.key;
                      final notification = entry.value;
                      return _buildNotificationTile(notification, index);
                    }),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification, int index) {
    const matrixGreen = Color(0xFF00FF41);
    final isRead = notification['is_read'] as bool;
    final type = notification['type'] as String;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.05,
            (index * 0.05) + 0.3,
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              index * 0.05,
              (index * 0.05) + 0.3,
              curve: Curves.easeOut,
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isRead 
                ? Colors.transparent 
                : matrixGreen.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead 
                  ? Colors.transparent 
                  : matrixGreen.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleNotificationTap(notification),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HUD Icon Wrapper
                    Container(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Small HUD Brackets
                          CustomPaint(
                            size: const Size(48, 48),
                            painter: HudCornerPainter(color: _getColorForType(type)),
                          ),
                          Icon(
                            _getIconForType(type),
                            color: _getColorForType(type),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                              color: matrixGreen,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification['body'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: matrixGreen.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatTime(notification['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: matrixGreen.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Unread indicator
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6, left: 8),
                        decoration: const BoxDecoration(
                          color: matrixGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'like':
      case 'upvote':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'battle_invite':
        return Icons.sports_kabaddi;
      case 'battle_result':
        return Icons.emoji_events;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    const matrixGreen = Color(0xFF00FF41);
    switch (type) {
      case 'like':
      case 'upvote':
        return Colors.red.shade400;
      case 'follow':
        return Colors.blue.shade400;
      case 'battle_invite':
        return Colors.orange.shade400;
      case 'battle_result':
        return Colors.amber.shade400;
      default:
        return matrixGreen;
    }
  }

  String _formatTime(String timestamp) {
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class HudCornerPainter extends CustomPainter {
  final Color color;
  HudCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final length = size.width * 0.2;
    
    // Top Left
    canvas.drawLine(Offset.zero, Offset(length, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, length), paint);

    // Top Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
