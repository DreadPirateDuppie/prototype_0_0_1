import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';
import '../services/image_service.dart';
import '../utils/error_helper.dart';

class CreateFeedPostDialog extends StatefulWidget {
  final Function() onPostAdded;

  const CreateFeedPostDialog({
    super.key,
    required this.onPostAdded,
  });

  @override
  State<CreateFeedPostDialog> createState() => _CreateFeedPostDialogState();
}

class _CreateFeedPostDialogState extends State<CreateFeedPostDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isLoading = false;
  bool _isPickingImage = false;
  final List<File> _selectedImages = [];
  File? _selectedVideo;

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
      _isPickingImage = true;
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
    if (_isPickingImage) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        final List<File> processedImages = [];
        for (final image in images) {
          try {
            final compressedImage = await ImageService.compressImage(File(image.path));
            processedImages.add(compressedImage ?? File(image.path));
          } catch (e) {
            processedImages.add(File(image.path));
          }
        }
        
        if (mounted) {
          setState(() {
            _selectedImages.addAll(processedImages);
          });
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

      List<String> photoUrls = [];
      
      for (final image in _selectedImages) {
        try {
          final url = await SupabaseService.uploadPostImage(image, user.id);
          if (url != null) photoUrls.add(url);
        } catch (e) {
          // Continue with other images
        }
      }

      if (_selectedImages.isNotEmpty && photoUrls.isEmpty) {
        throw Exception('Failed to upload images. Please try again.');
      }

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      String? videoUrl;
      if (_selectedVideo != null) {
        videoUrl = await SupabaseService.uploadPostVideo(_selectedVideo!, user.id);
      }

      await SupabaseService.createMapPost(
        userId: user.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        photoUrls: photoUrls,
        videoUrl: videoUrl,
        tags: tags,
        // No location, ratings, or category for feed posts
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Explicitly define colors to ensure visibility
    final matrixGreen = const Color(0xFF00FF41);
    final matrixBlack = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? matrixGreen : Colors.black;
    final borderColor = matrixGreen;
    
    return AlertDialog(
      backgroundColor: matrixBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 2),
      ),
      title: Text(
        'NEW FEED POST',
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite, // Use full available width
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            TextField(
              controller: _titleController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                hintText: 'Enter post title',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor, width: 2),
                ),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Tags',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                hintText: 'comma separated',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor, width: 2),
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
                  borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor, width: 2),
                ),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // Image List
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.separated(
                  key: ValueKey(_selectedImages.length), // Force rebuild on changes
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _selectedImages.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      key: ValueKey(_selectedImages[index].path), // Unique key per image
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
                          top: 0,
                          right: 0,
                          child: IconButton(
                            onPressed: () {
                              print('DEBUG: IconButton tapped for index $index');
                              _removeImage(index);
                            },
                            icon: Icon(
                              Icons.cancel,
                              color: Colors.red,
                              size: 24,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Video Preview
            if (_selectedVideo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.videocam, color: textColor, size: 32),
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
                      backgroundColor: isDark ? Colors.black : Colors.white,
                      foregroundColor: borderColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                    ),
                    icon: Icon(
                      _selectedImages.isEmpty ? Icons.add_photo_alternate : Icons.photo_library,
                      color: borderColor,
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
                      backgroundColor: isDark ? Colors.black : Colors.white,
                      foregroundColor: borderColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                    ),
                    icon: Icon(
                      Icons.videocam,
                      color: borderColor,
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
    ), // Closing parenthesis for ConstrainedBox
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
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.black : borderColor,
              foregroundColor: isDark ? borderColor : Colors.white,
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? borderColor : Colors.white,
                    ),
                  )
                : const Text(
                    'POST',
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
