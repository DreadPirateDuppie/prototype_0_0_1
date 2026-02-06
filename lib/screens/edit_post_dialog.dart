import '../utils/logger.dart';
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
  late bool _isSpot;

  static const matrixGreen = Color(0xFF00FF41);
  static const matrixBlack = Color(0xFF000000);

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
    _isSpot = widget.post.latitude != null && widget.post.longitude != null;
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
            SnackBar(
              content: Text('Added ${pickedFiles.length} image(s)'),
              backgroundColor: matrixGreen,
              behavior: SnackBarBehavior.floating,
            ),
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
          AppLogger.log('Failed to upload image', error: e, name: 'EditPostDialog');
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
          const SnackBar(
            content: Text('Post updated successfully!'),
            backgroundColor: matrixGreen,
            behavior: SnackBarBehavior.floating,
          ),
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

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: matrixBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: matrixGreen, width: 2),
        ),
        title: const Center(
          child: Text(
            'DELETE POST',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(
            color: matrixGreen.withValues(alpha: 0.7),
            fontSize: 14,
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: matrixGreen.withValues(alpha: 0.7),
                fontFamily: 'monospace',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await SupabaseService.deletePost(widget.post.id!);
        if (mounted) {
          Navigator.of(context).pop(true); // Close edit dialog and signal deletion
          widget.onPostUpdated(); // Trigger refresh
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted successfully'),
              backgroundColor: matrixGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ErrorHelper.showError(context, 'Error deleting post: $e');
        }
      }
    }
  }

  InputDecoration _buildMatrixInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7), fontFamily: 'monospace'),
      hintText: hint,
      hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.3), fontFamily: 'monospace'),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: matrixGreen, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: matrixBlack,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: matrixGreen, width: 2),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'EDIT POST',
                style: TextStyle(
                  color: matrixGreen,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 20,
                  shadows: [
                    Shadow(color: matrixGreen, blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: matrixGreen, fontFamily: 'monospace'),
                decoration: _buildMatrixInputDecoration('Title', 'Enter post title'),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: matrixGreen, fontFamily: 'monospace'),
                decoration: _buildMatrixInputDecoration('Description', 'Enter post description'),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              if (_isSpot) ...[
                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: matrixBlack,
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    style: const TextStyle(color: matrixGreen, fontFamily: 'monospace'),
                    decoration: _buildMatrixInputDecoration('Category', 'Select category'),
                    dropdownColor: matrixBlack,
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
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tagsController,
                  style: const TextStyle(color: matrixGreen, fontFamily: 'monospace'),
                  decoration: _buildMatrixInputDecoration('Tags', 'stairs, ledge, rail'),
                ),
                const SizedBox(height: 24),
              ],
              // Image section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PHOTOS',
                    style: TextStyle(
                      color: matrixGreen,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Display existing and new images
                  if (_existingPhotoUrls.isNotEmpty || _newImages.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingPhotoUrls.length + _newImages.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final isExisting = index < _existingPhotoUrls.length;
                          
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: matrixGreen.withValues(alpha: 0.5)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
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
                                              color: matrixGreen.withValues(alpha: 0.1),
                                              child: const Icon(Icons.image_not_supported, color: matrixGreen),
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
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.red,
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
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: matrixGreen.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: matrixGreen.withValues(alpha: 0.2), style: BorderStyle.solid),
                      ),
                      child: Center(
                        child: Text(
                          'NO IMAGES SELECTED',
                          style: TextStyle(
                            color: matrixGreen.withValues(alpha: 0.3),
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: matrixGreen, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.15),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate, color: matrixGreen),
                      label: Text(
                        (_existingPhotoUrls.isEmpty && _newImages.isEmpty)
                            ? 'ADD PHOTOS'
                            : 'ADD MORE PHOTOS (${_existingPhotoUrls.length + _newImages.length})',
                        style: const TextStyle(color: matrixGreen, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: matrixGreen.withValues(alpha: 0.05),
                      ),
                      onPressed: (_isLoading || _isPickingImage) ? null : _pickImages,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Ratings section
              if (_isSpot)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RATINGS',
                      style: TextStyle(
                        color: matrixGreen,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRatingSlider(
                      label: 'POPULARITY',
                      value: _popularityRating,
                      icon: Icons.local_fire_department_rounded,
                      color: Colors.orange,
                      onChanged: (val) => setState(() => _popularityRating = val),
                    ),
                    const SizedBox(height: 16),
                    _buildRatingSlider(
                      label: 'SECURITY',
                      value: _securityRating,
                      icon: Icons.shield_rounded,
                      color: Colors.blue,
                      onChanged: (val) => setState(() => _securityRating = val),
                    ),
                    const SizedBox(height: 16),
                    _buildRatingSlider(
                      label: 'QUALITY',
                      value: _qualityRating,
                      icon: Icons.star_rounded,
                      color: matrixGreen,
                      onChanged: (val) => setState(() => _qualityRating = val),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: matrixGreen.withValues(alpha: 0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: matrixBlack,
                        foregroundColor: matrixGreen.withValues(alpha: 0.7),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  if (!_isLoading)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: _deletePost,
                      tooltip: 'Delete Post',
                    ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: matrixGreen, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updatePost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: matrixBlack,
                        foregroundColor: matrixGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
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
                                fontSize: 16,
                                letterSpacing: 1.0,
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
              style: TextStyle(
                color: matrixGreen.withValues(alpha: 0.8),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'monospace',
                fontSize: 14,
                shadows: [
                  Shadow(color: color, blurRadius: 4),
                ],
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
                padding: const EdgeInsets.only(right: 12.0),
                child: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isSelected ? color : matrixGreen.withValues(alpha: 0.1),
                  size: 32,
                  shadows: isSelected ? [Shadow(color: color, blurRadius: 8)] : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
