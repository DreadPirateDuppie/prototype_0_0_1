import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';
import '../services/image_service.dart';
import '../utils/error_helper.dart';

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
  final _tagsController = TextEditingController();
  String _selectedCategory = 'Other';
  final List<String> _categories = ['Street', 'Park', 'DIY', 'Shop', 'Other'];
  bool _isLoading = false;
  bool _isPickingImage = false;
  final List<File> _selectedImages = [];
  double _rating = 0.0; // Star rating (0-5)

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    print('DEBUG: _pickImages called, _isPickingImage: $_isPickingImage');

    // Add extra check and force reset if needed
    if (_isPickingImage) {
      print('DEBUG: Image picker already active, forcing reset and ignoring');
      setState(() {
        _isPickingImage = false;
      });
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    try {
      print('DEBUG: Creating ImagePicker instance');
      final ImagePicker picker = ImagePicker();

      print('DEBUG: Calling pickMultiImage');
      final List<XFile> images = await picker.pickMultiImage();

      print('DEBUG: Picked ${images.length} images');

      if (images.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Adding ${images.length} image(s)...')),
          );
        }

        for (int i = 0; i < images.length; i++) {
          final image = images[i];
          print('DEBUG: Processing image $i: ${image.path}');

          try {
            // Try compression first
            final compressedImage = await ImageService.compressImage(File(image.path));
            print('DEBUG: Compression result for image $i: ${compressedImage?.path ?? "null"}');

            if (compressedImage != null) {
              if (mounted) {
                setState(() {
                  _selectedImages.add(compressedImage);
                  print('DEBUG: Added compressed image $i. Total images: ${_selectedImages.length}');
                });
              }
            } else {
              print('DEBUG: Compression returned null for image $i, trying original');
              // If compression fails, use original
              if (mounted) {
                setState(() {
                  _selectedImages.add(File(image.path));
                  print('DEBUG: Added original image $i. Total images: ${_selectedImages.length}');
                });
              }
            }
          } catch (imageError) {
            print('DEBUG: Error processing image $i: $imageError');
            // Try to add original as fallback
            if (mounted) {
              setState(() {
                _selectedImages.add(File(image.path));
                print('DEBUG: Added original image as fallback. Total images: ${_selectedImages.length}');
              });
            }
          }
        }

        print('DEBUG: Final image count: ${_selectedImages.length}');

        if (mounted && _selectedImages.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${_selectedImages.length} image(s)')),
          );
        }
      } else {
        print('DEBUG: No images selected');
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error in _pickImages: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        // Don't show error for "already_active" - just silently handle it
        if (!e.toString().contains('already_active')) {
          ErrorHelper.showError(context, 'Error picking images: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
        print('DEBUG: _pickImages completed, _isPickingImage set to false');
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ErrorHelper.showError(context, 'Please fill in both title and description fields.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      // Get user's display name
      final userName = await SupabaseService.getCurrentUserDisplayName();

      List<String> photoUrls = [];
      print('DEBUG: Starting image uploads for ${_selectedImages.length} images');
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        print('DEBUG: Uploading image $i: ${image.path}');
        
        try {
          final url = await SupabaseService.uploadPostImage(image, user.id);
          if (url != null && url.isNotEmpty) {
            photoUrls.add(url);
            print('DEBUG: Successfully uploaded image $i, URL: $url');
          } else {
            print('DEBUG: Failed to upload image $i: null or empty URL');
          }
        } catch (uploadError) {
          print('DEBUG: Error uploading image $i: $uploadError');
          // Continue with other images even if one fails
        }
      }
      
      print('DEBUG: Uploaded ${photoUrls.length} out of ${_selectedImages.length} images');

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      print('DEBUG: Creating post with ${photoUrls.length} images');
      final post = await SupabaseService.createMapPost(
        userId: user.id,
        userName: userName ?? 'Anonymous',
        userEmail: user.email ?? 'No Email',
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        photoUrls: photoUrls,
        category: _selectedCategory,
        tags: tags,
        rating: _rating,
      );

      print('DEBUG: Post created successfully: ${post?.id}');

      if (mounted) {
        widget.onPostAdded();
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error in _createPost: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ErrorHelper.showError(context, 'Error creating post: $e');
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
    
    return AlertDialog(
      backgroundColor: matrixBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: matrixGreen, width: 2),
      ),
      title: const Text(
        'ADD PIN/POST',
        style: TextStyle(
          color: matrixGreen,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Location: ${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}',
              style: TextStyle(
                color: matrixGreen.withValues(alpha: 0.6),
                fontSize: 12,
                fontFamily: 'monospace',
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
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: matrixBlack,
              style: const TextStyle(color: matrixGreen),
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              style: const TextStyle(color: matrixGreen),
              decoration: InputDecoration(
                labelText: 'Tags',
                labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                hintText: 'stairs, ledge, covered (comma separated)',
                hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: matrixGreen),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                hintText: 'Enter post description',
                hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // Star Rating Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spot Quality Rating',
                  style: TextStyle(
                    color: matrixGreen.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1.0;
                    return GestureDetector(
                      onTap: _isLoading ? null : () {
                        setState(() {
                          _rating = starValue;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          _rating >= starValue 
                              ? Icons.star 
                              : Icons.star_border,
                          color: _rating >= starValue 
                              ? const Color(0xFFFFD700) // Gold color
                              : matrixGreen.withValues(alpha: 0.3),
                          size: 36,
                          shadows: _rating >= starValue ? [
                            Shadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ] : null,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _rating > 0 
                        ? '${_rating.toInt()} / 5 stars' 
                        : 'Tap to rate',
                    style: TextStyle(
                      color: matrixGreen.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Image List
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _selectedImages.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImages[index],
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
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
              ),
            
            const SizedBox(height: 12),
            

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _isPickingImage) ? null : _pickImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: matrixBlack,
                  foregroundColor: matrixGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                icon: Icon(
                  _selectedImages.isEmpty ? Icons.add_photo_alternate : Icons.photo_library,
                  color: matrixGreen,
                ),
                label: Text(
                  _selectedImages.isEmpty ? 'Add Multiple Photos' : 'Add More Photos (${_selectedImages.length} selected)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
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
            onPressed: _isLoading ? null : _createPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: matrixBlack,
              foregroundColor: matrixGreen,
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: matrixGreen,
                    ),
                  )
                : const Text(
                    'CREATE POST',
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
