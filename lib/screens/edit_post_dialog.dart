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
  
  // Multi-image support
  final List<File> _newImages = []; // Newly selected images
  List<String> _existingPhotoUrls = []; // Existing photos from the post
  bool _isLoading = false;
  bool _isPickingImage = false;
  
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
    
    // Initialize with existing photos
    _existingPhotoUrls = List.from(widget.post.photoUrls);
    
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

  Future<void> _pickImages() async {
    if (_isPickingImage) return;
    
    setState(() {
      _isPickingImage = true;
    });
    
    final picker = ImagePicker();
    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (var file in pickedFiles) {
            _newImages.add(File(file.path));
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${pickedFiles.length} image(s)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error picking images: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }
  
  void _removeExistingImage(int index) {
    setState(() {
      _existingPhotoUrls.removeAt(index);
    });
  }
  
  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
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
      final user = SupabaseService.getCurrentUser();
      if (user == null) throw Exception('User not logged in');
      
      // Upload new images
      List<String> newPhotoUrls = [];
      for (var image in _newImages) {
        try {
          final url = await SupabaseService.uploadPostImage(image, user.id);
          if (url.isNotEmpty) {
            newPhotoUrls.add(url);
          }
        } catch (e) {
          print('DEBUG: Failed to upload image: $e');
        }
      }
      
      // Combine existing URLs with newly uploaded URLs
      final allPhotoUrls = [..._existingPhotoUrls, ...newPhotoUrls];

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await SupabaseService.updateMapPost(
        postId: widget.post.id!,
        title: _titleController.text,
        description: _descriptionController.text,
        photoUrls: allPhotoUrls,
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
                    'Photos',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  
                  // Display existing and new images
                  if (_existingPhotoUrls.isNotEmpty || _newImages.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingPhotoUrls.length + _newImages.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final isExisting = index < _existingPhotoUrls.length;
                          
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isExisting
                                    ? Image.network(
                                        _existingPhotoUrls[index],
                                        height: 120,
                                        width: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 120,
                                            width: 120,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image_not_supported),
                                          );
                                        },
                                      )
                                    : Image.file(
                                        _newImages[index - _existingPhotoUrls.length],
                                        height: 120,
                                        width: 120,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    if (isExisting) {
                                      _removeExistingImage(index);
                                    } else {
                                      _removeNewImage(index - _existingPhotoUrls.length);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                        child: Text('No images selected'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(
                        (_existingPhotoUrls.isEmpty && _newImages.isEmpty)
                            ? 'Add Photos'
                            : 'Add More Photos (${_existingPhotoUrls.length + _newImages.length} total)',
                      ),
                      onPressed: (_isLoading || _isPickingImage) ? null : _pickImages,
                    ),
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
