import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class UploadMediaDialog extends StatefulWidget {
  final Function() onMediaUploaded;

  const UploadMediaDialog({
    super.key,
    required this.onMediaUploaded,
  });

  @override
  State<UploadMediaDialog> createState() => _UploadMediaDialogState();
}

class _UploadMediaDialogState extends State<UploadMediaDialog> {
  final _captionController = TextEditingController();
  bool _isLoading = false;
  File? _selectedFile;
  String? _mediaType; // 'photo' or 'video'

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.gallery);

      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
          _mediaType = 'photo';
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error picking photo: $e');
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        setState(() {
          _selectedFile = File(video.path);
          _mediaType = 'video';
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error picking video: $e');
      }
    }
  }

  Future<void> _uploadMedia() async {
    if (_selectedFile == null || _mediaType == null) {
      ErrorHelper.showError(context, 'Please select a photo or video');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      // Upload file
      final mediaUrl = await SupabaseService.uploadProfileMedia(
        _selectedFile!,
        user.id,
        _mediaType!,
      );

      // Create database entry (no points awarded)
      await SupabaseService.createProfileMedia(
        userId: user.id,
        mediaUrl: mediaUrl,
        mediaType: _mediaType!,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
      );

      if (mounted) {
        widget.onMediaUploaded();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Media uploaded successfully!'),
            backgroundColor: Color(0xFF00FF41),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error uploading media: $e');
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
        'UPLOAD MEDIA',
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
            // Media preview
            if (_selectedFile != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: matrixGreen.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _mediaType == 'video' ? Icons.videocam : Icons.photo,
                      color: matrixGreen,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _mediaType == 'video' ? 'Video selected' : 'Photo selected',
                        style: const TextStyle(
                          color: matrixGreen,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedFile = null;
                          _mediaType = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Caption field
            TextField(
              controller: _captionController,
              style: const TextStyle(color: matrixGreen),
              decoration: InputDecoration(
                labelText: 'Caption (Optional)',
                labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                hintText: 'Add a caption...',
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

            // Select Photo/Video buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickPhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: matrixBlack,
                      foregroundColor: matrixGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.photo, color: matrixGreen),
                    label: const Text(
                      'Photo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: matrixBlack,
                      foregroundColor: matrixGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.videocam, color: matrixGreen),
                    label: const Text(
                      'Video',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
            onPressed: _isLoading ? null : _uploadMedia,
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
                    'UPLOAD',
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
