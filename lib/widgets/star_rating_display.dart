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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: index < rating ? color : Colors.grey[300],
                size: 18,
              );
            }),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              rating.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
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
