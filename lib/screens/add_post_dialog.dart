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
  File? _selectedVideo;
  double _rating = 0.0; // Star rating (0-5)
  double _securityRating = 0.0;
  double _popularityRating = 0.0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_isPickingImage) return;

    setState(() {
      _isPickingImage = true; // Reusing flag to prevent concurrent picks
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video selected!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error picking video: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {

    // Add extra check and force reset if needed
    if (_isPickingImage) {
      setState(() {
        _isPickingImage = false;
      });
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    try {
      final ImagePicker picker = ImagePicker();

      final List<XFile> images = await picker.pickMultiImage();


      if (images.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Adding ${images.length} image(s)...')),
          );
        }

        for (int i = 0; i < images.length; i++) {
          final image = images[i];

          try {
            // Try compression first
            final compressedImage = await ImageService.compressImage(File(image.path));

            if (compressedImage != null) {
              if (mounted) {
                setState(() {
                  _selectedImages.add(compressedImage);
                });
              }
            } else {
              // If compression fails, use original
              if (mounted) {
                setState(() {
                  _selectedImages.add(File(image.path));
                });
              }
            }
          } catch (imageError) {
            // Try to add original as fallback
            if (mounted) {
              setState(() {
                _selectedImages.add(File(image.path));
              });
            }
          }
        }


        if (mounted && _selectedImages.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${_selectedImages.length} image(s)')),
          );
        }
      } else {
      }
    } catch (e) {
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
      }
    }
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
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        
        try {
          final url = await SupabaseService.uploadPostImage(image, user.id);
          if (url.isNotEmpty) {
            photoUrls.add(url);
          } else {
          }
        } catch (uploadError) {
          // Continue with other images even if one fails
        }
      }
      

      if (_selectedImages.isNotEmpty && photoUrls.isEmpty) {
        throw Exception('Failed to upload any images. Please check your connection and try again.');
      }

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Upload video if selected
      String? videoUrl;
      if (_selectedVideo != null) {
        try {
          videoUrl = await SupabaseService.uploadPostVideo(_selectedVideo!, user.id);
        } catch (videoError) {
          // Decide if we should fail the whole post or just skip the video
          // For now, let's fail and tell the user
          throw Exception('Failed to upload video: $videoError');
        }
      }

      await SupabaseService.createMapPost(
        userId: user.id,
        userName: userName ?? 'Anonymous',
        userEmail: user.email ?? 'No Email',
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        photoUrls: photoUrls,
        videoUrl: videoUrl,
        category: _selectedCategory,
        tags: tags,
        qualityRating: _rating,
        securityRating: _securityRating,
        popularityRating: _popularityRating,
      );


      if (mounted) {
        widget.onPostAdded();
        Navigator.of(context).pop();
      }
    } catch (e) {
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

  Widget _buildRatingSection(String title, double rating, Function(double) onRatingChanged, Color activeColor) {
    const matrixGreen = Color(0xFF00FF41);
    
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? matrixGreen;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
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
                onRatingChanged(starValue);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  rating >= starValue 
                      ? Icons.star 
                      : Icons.star_border,
                  color: rating >= starValue 
                      ? activeColor
                      : textColor.withValues(alpha: 0.3),
                  size: 32,
                  shadows: rating >= starValue ? [
                    Shadow(
                      color: activeColor.withValues(alpha: 0.5),
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
            rating > 0 
                ? '${rating.toInt()} / 5 stars' 
                : 'Tap to rate',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.5),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final matrixGreen = colorScheme.primary;
    final matrixBlack = colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? matrixGreen;
    
    return AlertDialog(
      backgroundColor: matrixBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: matrixGreen, width: 2),
      ),
      title: Text(
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
                color: textColor.withValues(alpha: 0.6),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                hintText: 'Enter post title',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: matrixBlack,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
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
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Tags',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                hintText: 'stairs, ledge, covered (comma separated)',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                hintText: 'Enter post description',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // Star Rating Sections
            _buildRatingSection(
              'Spot Quality Rating', 
              _rating, 
              (val) => setState(() => _rating = val),
              const Color(0xFFFFD700), // Gold
            ),
            _buildRatingSection(
              'Security Rating (Low = Safe)', 
              _securityRating, 
              (val) => setState(() => _securityRating = val),
              Colors.redAccent, 
            ),
            _buildRatingSection(
              'Popularity Rating', 
              _popularityRating, 
              (val) => setState(() => _popularityRating = val),
              Colors.blueAccent, 
            ),
            
            const SizedBox(height: 12),
            
            
            // Image List - Simplified for better rebuilding
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedImages.length} photo(s) selected',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  width: 100,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.error, color: Colors.red),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            

            // Video Preview
            if (_selectedVideo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: matrixGreen.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.videocam, color: matrixGreen, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Video selected',
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedVideo = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
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
                      _selectedImages.isEmpty ? 'Photos' : 'Photos (${_selectedImages.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _isPickingImage || _selectedVideo != null) ? null : _pickVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: matrixBlack,
                      foregroundColor: matrixGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    icon: Icon(
                      Icons.videocam,
                      color: matrixGreen,
                    ),
                    label: const Text(
                      'Video',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
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
              color: textColor.withValues(alpha: 0.7),
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
              backgroundColor: isDark ? Colors.black : matrixGreen,
              foregroundColor: isDark ? matrixGreen : Colors.black,
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
