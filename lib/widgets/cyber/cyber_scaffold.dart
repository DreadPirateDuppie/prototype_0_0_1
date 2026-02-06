import 'dart:ui';
import 'package:flutter/material.dart';

class CyberScaffold extends StatefulWidget {
  final Widget child;
  final bool showGrid;
  final bool showScanlines;

  const CyberScaffold({
    super.key,
    required this.child,
    this.showGrid = true,
    this.showScanlines = true,
  });

  @override
  State<CyberScaffold> createState() => _CyberScaffoldState();
}

class _CyberScaffoldState extends State<CyberScaffold> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Subtle Radial Gradient Background
          Container(
            color: Colors.black,
          ),

          // 2. Animated Grid (Optional)
          if (widget.showGrid)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _GridPainter(
                    offset: _controller.value,
                    color: const Color(0xFF00FF41).withOpacity(0.03), // Fixed: withOpacity
                  ),
                );
              },
            ),

          // 3. Scanlines (Optional)
          if (widget.showScanlines)
            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black12,
                    ],
                    stops: [0.5, 0.5],
                    tileMode: TileMode.repeated,
                  ),
                ),
              ),
            ),

          // 4. Main Content
          SafeArea(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double offset;
  final Color color;

  _GridPainter({required this.offset, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final spacing = 40.0;
    final dy = (offset * spacing) % spacing;

    // Horizontal lines moving down
    for (double y = dy; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical lines (static)
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}
