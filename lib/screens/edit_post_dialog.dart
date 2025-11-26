import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class EditPostDialog extends StatefulWidget {
  final MapPost post;
  final VoidCallback onPostUpdated;

  const EditPostDialog({
    super.key,
    required this.post,
    required this.onPostUpdated,
  });

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;
  String _selectedCategory = 'Street';
  final List<String> _categories = ['Street', 'Park', 'DIY', 'Shop', 'Other'];
  File? _selectedImage;
  bool _isLoading = false;
  
  // Ratings
  late double _popularityRating;
  late double _securityRating;
  late double _qualityRating;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _descriptionController = TextEditingController(text: widget.post.description);
    _tagsController = TextEditingController(text: widget.post.tags.join(', '));
    _selectedCategory = widget.post.category;
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'Other';
    }
    
    _popularityRating = widget.post.popularityRating;
    _securityRating = widget.post.securityRating;
    _qualityRating = widget.post.qualityRating;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error picking image: $e');
      }
    }
  }

  Future<void> _updatePost() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ErrorHelper.showError(context, 'Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? photoUrl = widget.post.photoUrl;
      if (_selectedImage != null) {
        // Upload new image
        final user = SupabaseService.getCurrentUser();
        if (user != null) {
          photoUrl = await SupabaseService.uploadPostImage(_selectedImage!, user.id);
        }
      }

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await SupabaseService.updateMapPost(
        postId: widget.post.id!,
        title: _titleController.text,
        description: _descriptionController.text,
        photoUrl: photoUrl,
        category: _selectedCategory,
        tags: tags,
        popularityRating: _popularityRating,
        securityRating: _securityRating,
        qualityRating: _qualityRating,
      );

      if (mounted) {
        widget.onPostUpdated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error updating post: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    
    return Dialog(
      backgroundColor: matrixBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: matrixGreen, width: 2),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'EDIT POST',
                style: TextStyle(
                  color: matrixGreen,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: matrixGreen),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                  hintText: 'Enter post title',
                  hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.3)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen, width: 2),
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                  ),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter post description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: 'Tags (comma separated)',
                  hintText: 'stairs, ledge, rail',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Image section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (widget.post.photoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.post.photoUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('No image selected'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Change Photo'),
                    onPressed: _pickImage,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Ratings section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ratings',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    label: 'Popularity',
                    value: _popularityRating,
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.orange,
                    onChanged: (val) => setState(() => _popularityRating = val),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    label: 'Security',
                    value: _securityRating,
                    icon: Icons.shield_rounded,
                    color: Colors.blue,
                    onChanged: (val) => setState(() => _securityRating = val),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    label: 'Quality',
                    value: _qualityRating,
                    icon: Icons.star_rounded,
                    color: Colors.green,
                    onChanged: (val) => setState(() => _qualityRating = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        color: matrixGreen.withValues(alpha: 0.7),
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
                          color: matrixGreen.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updatePost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: matrixBlack,
                        foregroundColor: matrixGreen,
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: matrixGreen,
                              ),
                            )
                          : const Text(
                              'UPDATE',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSlider({
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            final isSelected = starValue <= value;
            
            return GestureDetector(
              onTap: () => onChanged(starValue.toDouble()),
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isSelected ? color : Colors.grey[300],
                  size: 28,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
