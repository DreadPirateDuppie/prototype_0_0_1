import 'package:flutter/material.dart';

class PushinnNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final String? avatarUrl;
  final VoidCallback onTap;
  final Animation<double> scaleAnimation;
  final Animation<double> glowAnimation;

  const PushinnNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.scaleAnimation,
    required this.glowAnimation,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final theme = Theme.of(context);
    final matrixGreen = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: matrixGreen.withValues(alpha: 0.2),
            highlightColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: glowAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: index == 4 ? const EdgeInsets.all(2) : const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? matrixGreen.withValues(alpha: 0.15)
                              : Colors.transparent,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: matrixGreen.withValues(alpha: 0.3),
                                    blurRadius: glowAnimation.value * 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: avatarUrl != null && index == 4
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: matrixGreen,
                                    width: 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: matrixGreen.withValues(alpha: 0.6),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundImage: NetworkImage(avatarUrl!),
                                  backgroundColor: Colors.transparent,
                                ),
                              )
                            : index == 1 // VS Tab
                                ? Text(
                                    'VS',
                                    style: TextStyle(
                                      color: isSelected ? matrixGreen : Colors.grey[600],
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      fontFamily: 'monospace',
                                      letterSpacing: -1,
                                    ),
                                  )
                                : Icon(
                                    icon,
                                    color: isSelected ? matrixGreen : Colors.grey[600],
                                    size: 24,
                                  ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class PushinnCenterNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final Animation<double> scaleAnimation;

  const PushinnCenterNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final matrixGreen = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            splashColor: matrixGreen.withValues(alpha: 0.3),
            child: Transform(
              transform: Matrix4.diagonal3Values(0.8, 1.0, 1.0),
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: 0.785398,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(12),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1A1A1A),
                              const Color(0xFF0F0F0F),
                            ]
                          : [
                              Colors.white,
                              const Color(0xFFF5F5F5),
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.grey.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      if (isSelected)
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.8),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                    ],
                    border: Border.all(
                      color: isSelected ? matrixGreen : matrixGreen.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Transform.rotate(
                    angle: -0.785398,
                    child: Transform(
                      transform: Matrix4.diagonal3Values(1.25, 1.0, 1.0),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        color: isSelected ? matrixGreen : Colors.grey[600],
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
