import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';

class RatePostDialog extends StatefulWidget {
  final MapPost post;
  final Function() onRated;

  const RatePostDialog({
    super.key,
    required this.post,
    required this.onRated,
  });

  @override
  State<RatePostDialog> createState() => _RatePostDialogState();
}

class _RatePostDialogState extends State<RatePostDialog> {
  double _popularityRating = 0;
  double _securityRating = 0;
  double _qualityRating = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _popularityRating = widget.post.popularityRating;
    _securityRating = widget.post.securityRating;
    _qualityRating = widget.post.qualityRating;
  }

  Future<void> _submitRating() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseService.rateMapPost(
        postId: widget.post.id!,
        popularityRating: _popularityRating,
        securityRating: _securityRating,
        qualityRating: _qualityRating,
      );

      if (mounted) {
        widget.onRated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting rating: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInteractiveRating({
    required String label,
    required String description,
    required double value,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = starValue <= value;
              
              return GestureDetector(
                onTap: _isLoading ? null : () => onChanged(starValue.toDouble()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected ? color : Colors.grey[300],
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            value > 0 ? value.toStringAsFixed(0) : 'Tap to rate',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: value > 0 ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Center(
        child: Text(
          widget.post.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInteractiveRating(
              label: 'Popularity',
              description: 'How busy or popular is this spot?',
              value: _popularityRating,
              icon: Icons.local_fire_department_rounded,
              color: Colors.orange,
              onChanged: (val) => setState(() => _popularityRating = val),
            ),
            _buildInteractiveRating(
              label: 'Security',
              description: 'How safe does this spot feel?',
              value: _securityRating,
              icon: Icons.shield_rounded,
              color: Colors.blue,
              onChanged: (val) => setState(() => _securityRating = val),
            ),
            _buildInteractiveRating(
              label: 'Quality',
              description: 'Overall quality of the spot/view.',
              value: _qualityRating,
              icon: Icons.star_rounded,
              color: Colors.green,
              onChanged: (val) => setState(() => _qualityRating = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitRating,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Submit Rating'),
        ),
      ],
    );
  }
}
