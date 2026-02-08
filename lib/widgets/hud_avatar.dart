import 'package:flutter/material.dart';

class HudAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String? username;
  final double radius;
  final bool showScanline;
  final Color neonColor;
  final VoidCallback? onTap;

  const HudAvatar({
    super.key,
    this.avatarUrl,
    this.username,
    this.radius = 24,
    this.showScanline = true,
    this.neonColor = const Color(0xFF00FF41),
    this.onTap,
  });

  @override
  State<HudAvatar> createState() => _HudAvatarState();
}

class _HudAvatarState extends State<HudAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.showScanline) {
      _scanController.repeat();
    }
  }

  @override
  void didUpdateWidget(HudAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showScanline && !_scanController.isAnimating) {
      _scanController.repeat();
    } else if (!widget.showScanline && _scanController.isAnimating) {
      _scanController.stop();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    final outerSize = size + 16;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // HUD corner accents
          SizedBox(
            width: outerSize,
            height: outerSize,
            child: CustomPaint(
              painter: HudCornerPainter(color: widget.neonColor),
            ),
          ),
          // Avatar Container
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.neonColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: widget.radius,
                    backgroundColor: Colors.black,
                    backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
                    child: widget.avatarUrl == null
                        ? Text(
                            (widget.username?.isNotEmpty == true)
                                ? widget.username![0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: widget.neonColor,
                              fontSize: widget.radius * 0.8,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          )
                        : null,
                  ),
                  // Scan line animation
                  if (widget.showScanline)
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanController.value * size - 5,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1.5,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: widget.neonColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                              gradient: LinearGradient(
                                colors: [
                                  widget.neonColor.withValues(alpha: 0),
                                  widget.neonColor.withValues(alpha: 0.8),
                                  widget.neonColor.withValues(alpha: 0),
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
    );
  }
}

class HudCornerPainter extends CustomPainter {
  final Color color;
  HudCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final length = size.width * 0.15;
    
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
