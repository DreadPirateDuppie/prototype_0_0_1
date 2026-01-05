import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onMyLocationPressed;
  final VoidCallback onZoomInPressed;
  final VoidCallback onZoomOutPressed;

  const MapControls({
    super.key,
    required this.onMyLocationPressed,
    required this.onZoomInPressed,
    required this.onZoomOutPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // My Location Button (Bottom Left)
        Positioned(
          bottom: 80,
          left: 16,
          child: _buildVerticalMapButton(
            icon: Icons.my_location,
            onPressed: onMyLocationPressed,
          ),
        ),

        // Zoom Controls (Bottom Right)
        Positioned(
          bottom: 80,
          right: 16,
          child: Column(
            children: [
              _buildVerticalMapButton(
                icon: Icons.add,
                onPressed: onZoomInPressed,
              ),
              const SizedBox(height: 12),
              _buildVerticalMapButton(
                icon: Icons.remove,
                onPressed: onZoomOutPressed,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    const matrixGreen = Color(0xFF00FF41);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: matrixGreen.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: matrixGreen,
            size: 24,
          ),
        ),
      ),
    );
  }
}
