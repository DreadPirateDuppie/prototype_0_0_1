import 'package:flutter/material.dart';
import '../verified_badge.dart';
import '../../services/supabase_service.dart';
import '../../screens/edit_username_dialog.dart';
import '../../providers/profile_provider.dart';
import 'package:provider/provider.dart';

class ProfileHeader extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final bool isCurrentUser;

  const ProfileHeader({
    super.key,
    required this.profileData,
    this.isCurrentUser = false,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.profileData['avatar_url'];
    final username = widget.profileData['username'] ?? 'User';
    final bio = widget.profileData['bio'];
    final isVerified = widget.profileData['is_verified'] == true;
    const neonGreen = Color(0xFF00FF41);

    return Column(
      children: [
        // HUD Avatar Frame
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer HUD Ring
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: neonGreen.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            // Technical Corner Accents (Custom Painter or stacked containers)
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: HeaderHudPainter(color: neonGreen),
              ),
            ),
            // Avatar Container
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: neonGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.black,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person, size: 54, color: neonGreen)
                          : null,
                    ),
                    // Scan line animation
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanController.value * 120 - 10,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: neonGreen.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                              gradient: LinearGradient(
                                colors: [
                                  neonGreen.withValues(alpha: 0),
                                  neonGreen.withValues(alpha: 0.8),
                                  neonGreen.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Username & Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '@$username'.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(
                    color: neonGreen,
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        if (widget.isCurrentUser) ...[
          const SizedBox(height: 16),
          _buildTerminalButton(
            label: 'CMD: EDIT_PROFILE',
            onTap: () async {
              final user = widget.profileData['id'];
              if (user == null) return;
              
              await showDialog(
                context: context,
                builder: (context) => EditUsernameDialog(
                  currentUsername: widget.profileData['username'] ?? '',
                  currentBio: widget.profileData['bio'],
                  onSave: (newUsername, newBio) {
                    // Profile updated in DB by dialog, now refresh provider
                    if (mounted) {
                      context.read<ProfileProvider>().loadProfile(user);
                    }
                  },
                ),
              );
            },
          ),
        ],
        
        // Bio with HUD Prefix
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 1,
                      width: 20,
                      color: neonGreen.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'STATUS // ACTIVE',
                      style: TextStyle(
                        color: neonGreen.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 1,
                      width: 20,
                      color: neonGreen.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTerminalButton({required String label, required VoidCallback onTap}) {
    const neonGreen = Color(0xFF00FF41);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: neonGreen.withValues(alpha: 0.5)),
          color: neonGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: neonGreen,
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class HeaderHudPainter extends CustomPainter {
  final Color color;
  HeaderHudPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const length = 15.0;
    
    // Top Left
    canvas.drawLine(Offset.zero, const Offset(length, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, length), paint);

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
