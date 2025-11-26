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
  File? _selectedImage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Compressing image...')));
        }

        // Compress the image
        final compressedImage = await ImageService.compressImage(
          File(image.path),
        );

        if (compressedImage != null) {
          setState(() {
            _selectedImage = compressedImage;
          });

          if (!mounted) return;
          final sizeMB = await ImageService.getFileSizeMB(compressedImage);
          if (!mounted) return;

          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Image ready (${sizeMB.toStringAsFixed(2)} MB)'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error picking image: $e');
      }
    }
  }

  Future<void> _createPost() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Missing Information'),
          content: const Text(
            'Please fill in both title and description fields.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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

      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await SupabaseService.uploadPostImage(
          _selectedImage!,
          user.id,
        );
      }

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await SupabaseService.createMapPost(
        userId: user.id,
        userName: userName ?? 'Anonymous',
        userEmail: user.email ?? 'No Email',
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        title: _titleController.text,
        description: _descriptionController.text,
        photoUrl: photoUrl,
        category: _selectedCategory,
        tags: tags,
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
    const matrixBlack = Color(0xFF000000);
    
    return AlertDialog(
      backgroundColor: matrixBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: matrixGreen, width: 2),
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
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
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
                focusedBorder: OutlineInputBorder(
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
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: matrixGreen.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.file(
                    _selectedImage!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: matrixGreen.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: matrixBlack,
                  foregroundColor: matrixGreen,
                ),
                icon: const Icon(Icons.image),
                label: Text(
                  _selectedImage != null ? 'Change Photo' : 'Add Photo',
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
