import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class RatePostDialog extends StatefulWidget {
  final MapPost post;
  final VoidCallback onRatingSubmitted;

  const RatePostDialog({
    super.key,
    required this.post,
    required this.onRatingSubmitted,
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
    // Initialize with existing ratings if available
    _popularityRating = widget.post.popularityRating;
    _securityRating = widget.post.securityRating;
    _qualityRating = widget.post.qualityRating;
  }

  Future<void> _submitRating() async {
    if (_popularityRating == 0 || _securityRating == 0 || _qualityRating == 0) {
      ErrorHelper.showError(context, 'Please rate all categories');
      return;
    }

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
        widget.onRatingSubmitted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error submitting rating: $e');
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
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    
    return AlertDialog(
      backgroundColor: matrixBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: matrixGreen, width: 2),
      ),
      title: Center(
        child: Text(
          widget.post.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: matrixGreen,
            fontFamily: 'monospace',
            letterSpacing: 1.2,
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
            'CANCEL',
            style: TextStyle(
              color: matrixGreen.withOpacity(0.7),
              fontFamily: 'monospace',
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: matrixGreen, width: 2),
            boxShadow: [
              BoxShadow(
                color: matrixGreen.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitRating,
            style: ElevatedButton.styleFrom(
              backgroundColor: matrixBlack,
              foregroundColor: matrixGreen,
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: matrixGreen,
                    ),
                  )
                : const Text(
                    'SUBMIT RATING',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
