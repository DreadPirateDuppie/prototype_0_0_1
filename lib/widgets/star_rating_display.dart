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

  Widget _buildStarRating(double rating, String label) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 18,
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          '${rating.toStringAsFixed(1)}/5.0',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Spot Ratings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStarRating(popularityRating, 'Popularity'),
              _buildStarRating(securityRating, 'Security'),
              _buildStarRating(qualityRating, 'Quality'),
            ],
          ),
        ],
      ),
    );
  }
}
