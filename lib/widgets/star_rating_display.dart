import 'package:flutter/material.dart';

class StarRatingDisplay extends StatelessWidget {
  final double popularityRating;
  final double securityRating;
  final double qualityRating;

  const StarRatingDisplay({
    super.key,
    required this.popularityRating,
    required this.securityRating,
    required this.qualityRating,
  });

  Widget _buildRatingRow(
    BuildContext context,
    String label,
    double rating,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label.substring(0, 3), // Just first 3 letters
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: index < rating ? color : Colors.grey[300],
                size: 10,
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRatingRow(
            context,
            'Popularity',
            popularityRating,
            Icons.local_fire_department_rounded,
            Colors.orange,
          ),
          _buildRatingRow(
            context,
            'Security',
            securityRating,
            Icons.shield_rounded,
            Colors.blue,
          ),
          _buildRatingRow(
            context,
            'Quality',
            qualityRating,
            Icons.star_rounded,
            Colors.green,
          ),
        ],
      ),
    );
  }
}
