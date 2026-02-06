import 'package:flutter/material.dart';

class CyberButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double width;
  final double height;
  final IconData? icon;

  const CyberButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 56.0,
    this.icon,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matrixGreen = const Color(0xFF00FF41);
    final disabledColor = Colors.grey.withOpacity(0.3); // Fixed: withOpacity
    
    final borderColor = widget.onPressed == null ? disabledColor : matrixGreen;
    final textColor = widget.onPressed == null ? disabledColor : (widget.isPrimary ? Colors.black : matrixGreen);
    final backgroundColor = widget.isPrimary 
        ? (widget.onPressed == null ? disabledColor : matrixGreen) 
        : Colors.transparent;

    return Center(
      child: SizedBox(
        width: widget.width == double.infinity ? null : widget.width,
        height: widget.height,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            onTap: widget.isLoading ? null : widget.onPressed,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: ShapeDecoration(
                  color: backgroundColor.withOpacity(widget.isPrimary ? 1.0 : (_isHovered ? 0.1 : 0.0)), // Fixed
                  shape: BeveledRectangleBorder(
                    side: BorderSide(
                      color: borderColor, 
                      width: 1.5
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  shadows: [
                    if (widget.onPressed != null && widget.isPrimary)
                      BoxShadow(
                        color: matrixGreen.withOpacity(_isHovered ? 0.6 : 0.4), // Fixed
                        blurRadius: _isHovered ? 20 : 10,
                        spreadRadius: 0,
                      ),
                    if (widget.onPressed != null && !widget.isPrimary && _isHovered)
                      BoxShadow(
                        color: matrixGreen.withOpacity(0.3), // Fixed
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (widget.isLoading) ...[
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.isPrimary ? Colors.black : matrixGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (widget.icon != null && !widget.isLoading) ...[
                      Icon(widget.icon, color: textColor, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.isLoading ? "PROCESSING..." : widget.text.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
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
}
