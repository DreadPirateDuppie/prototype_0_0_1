import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';
import '../services/image_service.dart';
import '../utils/error_helper.dart';

class AddPostDialog extends StatefulWidget {
  final LatLng? location;
  final Function() onPostAdded;

  const AddPostDialog({
    super.key,
    this.location,
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
        latitude: widget.location?.latitude ?? 0,
        longitude: widget.location?.longitude ?? 0,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        photoUrls: photoUrls,
        videoUrl: videoUrl,
        category: widget.location != null ? _selectedCategory : 'Other',
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

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    const backgroundBlack = Color(0xFF0A0A0A);
    final user = SupabaseService.getCurrentUser();
    
    return Scaffold(
      backgroundColor: backgroundBlack,
      appBar: _buildModernAppBar(context, matrixGreen),
      body: Stack(
        children: [
          // Background Texture (Grid)
          _buildBackgroundGrid(matrixGreen),
          
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                   // Feed Post Preview-style Card
                   Container(
                     decoration: BoxDecoration(
                       color: Colors.black,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(
                         color: matrixGreen.withValues(alpha: 0.4),
                         width: 1.5,
                       ),
                       boxShadow: [
                         BoxShadow(
                           color: matrixGreen.withValues(alpha: 0.1),
                           blurRadius: 20,
                           spreadRadius: 2,
                         ),
                       ],
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                         // Header
                         Padding(
                           padding: const EdgeInsets.all(16.0),
                           child: Row(
                             children: [
                               Container(
                                 padding: const EdgeInsets.all(2),
                                 decoration: BoxDecoration(
                                   shape: BoxShape.circle,
                                   border: Border.all(color: matrixGreen, width: 1),
                                 ),
                                 child: CircleAvatar(
                                   radius: 18,
                                   backgroundColor: matrixGreen.withValues(alpha: 0.1),
                                   child: Text(
                                     (user?.email ?? 'U')[0].toUpperCase(),
                                     style: const TextStyle(
                                       color: matrixGreen,
                                       fontWeight: FontWeight.bold,
                                       fontSize: 14,
                                     ),
                                   ),
                                 ),
                               ),
                               const SizedBox(width: 12),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       'SOURCE_USER: ${user?.email?.split('@')[0].toUpperCase() ?? 'ANONYMOUS'}',
                                       style: const TextStyle(
                                         fontSize: 10,
                                         color: matrixGreen,
                                         fontFamily: 'monospace',
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                     const SizedBox(height: 4),
                                     _buildModernTitleInput(matrixGreen),
                                   ],
                                 ),
                               ),
                             ],
                           ),
                         ),
                         
                         // Media Section
                         _buildHeroMediaSection(matrixGreen),
                         
                         // Description
                         Padding(
                           padding: const EdgeInsets.all(16.0),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               _buildModernDescriptionInput(matrixGreen),
                               const SizedBox(height: 20),
                               if (widget.location != null) ...[
                                 _buildLocationPill(matrixGreen),
                                 const SizedBox(height: 20),
                                 _buildCategoryChips(matrixGreen),
                                 const SizedBox(height: 24),
                                 const Text(
                                   '// SYSTEM_SENSORS_DATA_INPUT',
                                   style: TextStyle(
                                     color: matrixGreen,
                                     fontFamily: 'monospace',
                                     fontSize: 10,
                                     fontWeight: FontWeight.w900,
                                     letterSpacing: 1,
                                   ),
                                 ),
                                 const SizedBox(height: 20),
                                 _buildGlowingRatingSection('SPOT QUALITY', _rating, (val) => setState(() => _rating = val), Colors.amber),
                                 _buildGlowingRatingSection('SECURITY RISK', _securityRating, (val) => setState(() => _securityRating = val), Colors.redAccent),
                                 _buildGlowingRatingSection('POPULARITY', _popularityRating, (val) => setState(() => _popularityRating = val), Colors.blueAccent),
                               ],
                               const Divider(color: Colors.white24, height: 40),
                               _buildModernTagsInput(matrixGreen),
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 24),
                   
                   // Post Tips / Filling Empty Space
                   _buildPostTips(matrixGreen),
                   
                   const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            _buildCyberLoadingOverlay(matrixGreen),
        ],
      ),
    );
  }

  Widget _buildBackgroundGrid(Color matrixGreen) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.05,
        child: CustomPaint(
          painter: GridPainter(color: matrixGreen),
        ),
      ),
    );
  }

  Widget _buildPostTips(Color matrixGreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: matrixGreen, size: 16),
              const SizedBox(width: 8),
              const Text(
                'COMMUNITY_GUIDELINES',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('Respect others & keep it civil.'),
          _buildTipItem('Only post high-quality photos/videos.'),
          _buildTipItem('Tag spots accurately for the community.'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('>', style: TextStyle(color: Color(0xFF00FF41), fontSize: 10)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }


  PreferredSizeWidget _buildModernAppBar(BuildContext context, Color matrixGreen) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white70),
        onPressed: () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      title: Text(
        widget.location != null ? 'NEW_SPOT' : 'NEW_POST',
        style: TextStyle(
          color: matrixGreen,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _createPost,
          child: Text(
            'POST',
            style: TextStyle(
              color: matrixGreen,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: matrixGreen.withValues(alpha: 0.1), height: 1),
      ),
    );
  }

  Widget _buildHeroMediaSection(Color matrixGreen) {
    if (_selectedImages.isEmpty && _selectedVideo == null) {
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: matrixGreen.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_rounded, color: matrixGreen, size: 40),
              const SizedBox(height: 16),
              const Text(
                'UPLOAD_MEDIA_ASSETS',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Photos or videos (Max 5)',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSlimMediaButton('ADD_PHOTOS', Icons.photo_library_outlined, _pickImages, matrixGreen),
                  const SizedBox(width: 12),
                  _buildSlimMediaButton('ADD_VIDEO', Icons.videocam_outlined, _pickVideo, Colors.orangeAccent),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 220, // Match PostCard carousel height
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _selectedImages.length + (_selectedVideo != null ? 1 : 0),
        itemBuilder: (context, index) {
          final isVideo = _selectedVideo != null && index == _selectedImages.length;
          final file = isVideo ? _selectedVideo! : _selectedImages[index];
          return SizedBox(
            width: MediaQuery.of(context).size.width - 32, // Full width inside the card padding
            child: _buildPremiumMediaPreview(
              file: file,
              isVideo: isVideo,
              onRemove: () => setState(() {
                if (isVideo) {
                  _selectedVideo = null;
                } else {
                  _selectedImages.removeAt(index);
                }
              }),
              matrixGreen: matrixGreen,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlimMediaButton(String label, IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumMediaPreview({required File file, bool isVideo = false, required VoidCallback onRemove, required Color matrixGreen}) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF111111),
      child: Stack(
        fit: StackFit.expand,
        children: [
          isVideo
              ? Container(color: const Color(0xFF1A1A1A), child: const Icon(Icons.videocam, color: Colors.white, size: 60))
              : Image.file(file, fit: BoxFit.cover),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
          if (isVideo)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationPill(Color matrixGreen) {
    return Row(
      children: [
        Icon(Icons.location_on, color: matrixGreen, size: 16),
        const SizedBox(width: 8),
        Text(
          'LAT/LNG: ${widget.location?.latitude.toStringAsFixed(4)} / ${widget.location?.longitude.toStringAsFixed(4)}',
          style: TextStyle(
            color: matrixGreen.withValues(alpha: 0.7),
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTitleInput(Color matrixGreen) {
    return TextField(
      controller: _titleController,
      style: TextStyle(
        fontSize: 20,
        color: matrixGreen,
      ),
      decoration: const InputDecoration(
        hintText: 'TITLE_REQUIRED...',
        hintStyle: TextStyle(color: Colors.white38, fontSize: 20),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildModernDescriptionInput(Color matrixGreen) {
    return TextField(
      controller: _descriptionController,
      style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5),
      maxLines: null,
      decoration: const InputDecoration(
        hintText: 'Tell the community about this spot or session...',
        hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildCategoryChips(Color matrixGreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SITE_CATEGORY',
          style: TextStyle(color: Colors.white24, fontFamily: 'monospace', fontSize: 10, letterSpacing: 2),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((category) {
              final selected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? matrixGreen.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? matrixGreen : Colors.white12,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: selected ? matrixGreen : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTagsInput(Color matrixGreen) {
    return TextField(
      controller: _tagsController,
      style: TextStyle(color: matrixGreen, fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        icon: Icon(Icons.tag, color: matrixGreen.withValues(alpha: 0.4), size: 18),
        hintText: 'comma, separated, tags',
        hintStyle: const TextStyle(color: Colors.white10),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildGlowingRatingSection(String label, double rating, Function(double) onChanged, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              Text('${rating.toInt()}/5', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final active = index < rating;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged((index + 1).toDouble()),
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: active ? color : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: active ? [
                        BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 1),
                      ] : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberLoadingOverlay(Color matrixGreen) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: matrixGreen, strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              'INITIALIZING_UPLOAD_SEQUENCE...',
              style: TextStyle(
                color: matrixGreen,
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    for (var i = 0.0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (var i = 0.0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
