import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  final Color color;
  final EdgeInsets padding;

  const VerifiedBadge({
    super.key,
    this.size = 14.0,
    this.color = const Color(0xFFFFD700), // Gold
    this.padding = const EdgeInsets.only(left: 4.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Icon(
        Icons.verified_rounded,
        size: size,
        color: color,
      ),
    );
  }
}
