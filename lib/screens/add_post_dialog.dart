import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/supabase_service.dart';
import '../providers/error_provider.dart';

class AddPostDialog extends StatefulWidget {
  final LatLng location;
  final Function() onPostAdded;

  const AddPostDialog({
    super.key,
    required this.location,
    required this.onPostAdded,
  });

  @override
  State<AddPostDialog> createState() => _AddPostDialogState();
}

class _AddPostDialogState extends State<AddPostDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
  int _popularityRating = 3;
  int _securityRating = 3;
  int _qualityRating = 3;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        context.read<ErrorProvider>().showError('Error picking image: $e');
      }
    }
  }

  Future<void> _createPost() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      context.read<ErrorProvider>().showError('Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        String? photoUrl;
        if (_selectedImage != null) {
          photoUrl = await SupabaseService.uploadPostImage(
            _selectedImage!,
            user.id,
          );
        }

        // Get the display name from the user_profiles table
        final displayName = await SupabaseService.getUserDisplayName(user.id);

        final post = await SupabaseService.createMapPost(
          userId: user.id,
          userName: displayName,
          userEmail: user.email,
          latitude: widget.location.latitude,
          longitude: widget.location.longitude,
          title: _titleController.text,
          description: _descriptionController.text,
          photoUrl: photoUrl,
        );

        // Add initial rating for the post
        if (post != null && post.id != null) {
          await SupabaseService.rateMapPost(
            postId: post.id!,
            popularityRating: _popularityRating,
            securityRating: _securityRating,
            qualityRating: _qualityRating,
          );
        }

        if (mounted) {
          widget.onPostAdded();
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        context.read<ErrorProvider>().showError('Error creating post: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRatingRow(String label, int currentRating, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < currentRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 24,
                  ),
                  onPressed: () => onChanged(index + 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                );
              }),
            ),
            const SizedBox(width: 8),
            Text('$currentRating/5'),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Pin/Post'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              'Location: ${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter post title',
                border: OutlineInputBorder(),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter post description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImage,
              icon: const Icon(Icons.image),
              label: Text(_selectedImage != null ? 'Change Photo' : 'Add Photo'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Initial Rating (you can change this later):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRatingRow('Rating', _popularityRating, (value) {
              setState(() => _popularityRating = value);
            }),
            const SizedBox(height: 8),
            _buildRatingRow('Security', _securityRating, (value) {
              setState(() => _securityRating = value);
            }),
            const SizedBox(height: 8),
            _buildRatingRow('Quality', _qualityRating, (value) {
              setState(() => _qualityRating = value);
            }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createPost,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Post'),
        ),
      ],
    );
  }
}
