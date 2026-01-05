import 'dart:ui';
import 'package:flutter/material.dart';
import 'nav_item.dart';

class PushinnNavBar extends StatelessWidget {
  final int currentIndex;
  final String? avatarUrl;
  final Function(int) onItemTapped;
  final List<Animation<double>> scaleAnimations;
  final List<Animation<double>> glowAnimations;

  const PushinnNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemTapped,
    required this.scaleAnimations,
    required this.glowAnimations,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final matrixGreen = colorScheme.primary;

    return SafeArea(
      child: Container(
        height: 85,
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Main Navigation Bar Background
            Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: matrixGreen.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0A0A0A).withValues(alpha: 0.9),
                                const Color(0xFF000000).withValues(alpha: 0.95),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.9),
                                const Color(0xFFF5F5F5).withValues(alpha: 0.95),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(
                        width: 1.5,
                        color: matrixGreen.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: PushinnNavItem(
                            icon: Icons.dashboard,
                            label: 'Feed',
                            index: 0,
                            currentIndex: currentIndex,
                            onTap: () => onItemTapped(0),
                            scaleAnimation: scaleAnimations[0],
                            glowAnimation: glowAnimations[0],
                          ),
                        ),
                        Expanded(
                          child: PushinnNavItem(
                            icon: Icons.sports_kabaddi,
                            label: 'VS',
                            index: 1,
                            currentIndex: currentIndex,
                            onTap: () => onItemTapped(1),
                            scaleAnimation: scaleAnimations[1],
                            glowAnimation: glowAnimations[1],
                          ),
                        ),
                        const Spacer(),
                        Expanded(
                          child: PushinnNavItem(
                            icon: Icons.emoji_events,
                            label: 'Rewards',
                            index: 3,
                            currentIndex: currentIndex,
                            onTap: () => onItemTapped(3),
                            scaleAnimation: scaleAnimations[3],
                            glowAnimation: glowAnimations[3],
                          ),
                        ),
                        Expanded(
                          child: PushinnNavItem(
                            icon: Icons.person,
                            label: 'Profile',
                            index: 4,
                            currentIndex: currentIndex,
                            onTap: () => onItemTapped(4),
                            scaleAnimation: scaleAnimations[4],
                            glowAnimation: glowAnimations[4],
                            avatarUrl: avatarUrl,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating Map Button (Diamond)
            Positioned(
              bottom: 10,
              child: PushinnCenterNavItem(
                icon: Icons.location_on,
                label: 'Map',
                index: 2,
                currentIndex: currentIndex,
                onTap: () => onItemTapped(2),
                scaleAnimation: scaleAnimations[2],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
