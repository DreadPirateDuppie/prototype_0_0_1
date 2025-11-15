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

      if (!mounted) return;
      widget.onRated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted successfully!')),
      );
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

  Widget _buildRatingSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: 0,
                max: 5,
                divisions: 5,
                label: value.toStringAsFixed(1),
                onChanged: _isLoading ? null : onChanged,
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < value ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate this Spot'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.post.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRatingSlider(
              'Popularity',
              _popularityRating,
              (value) => setState(() => _popularityRating = value),
            ),
            _buildRatingSlider(
              'Security',
              _securityRating,
              (value) => setState(() => _securityRating = value),
            ),
            _buildRatingSlider(
              'Quality',
              _qualityRating,
              (value) => setState(() => _qualityRating = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitRating,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Rating'),
        ),
      ],
    );
  }
}
