import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditUsernameDialog extends StatefulWidget {
  final String currentUsername;
  final String? currentBio;
  final Function(String username, String? bio) onSave;

  const EditUsernameDialog({
    super.key,
    required this.currentUsername,
    this.currentBio,
    required this.onSave,
  });

  @override
  State<EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<EditUsernameDialog> {
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrlPreview;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.currentUsername.isNotEmpty ? widget.currentUsername : '');
    _bioController = TextEditingController(text: widget.currentBio ?? '');
    _loadCurrentAvatar();
  }

  Future<void> _loadCurrentAvatar() async {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      final url = await SupabaseService.getUserAvatarUrl(user.id);
      if (mounted) {
        setState(() {
          _avatarUrlPreview = url;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null && mounted) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Username cannot be empty';
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _errorMessage = 'Username must be at least 3 characters';
      });
      return;
    }

    if (username.length > 20) {
      setState(() {
        _errorMessage = 'Username must be 20 characters or less';
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
      setState(() {
        _errorMessage = 'Username can only contain letters, numbers, dashes, and underscores';
      });
      return;
    }

    // Check if username is the same as current (only if current username exists)
    if (widget.currentUsername.isNotEmpty && 
        username.toLowerCase() == widget.currentUsername.toLowerCase()) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        // 1. Check if username changed and is available
        if (username.toLowerCase() != widget.currentUsername.toLowerCase()) {
          final isAvailable = await SupabaseService.isUsernameAvailableForUser(username, user.id);
          if (!isAvailable) {
            setState(() {
              _errorMessage = 'Username is already taken';
              _isLoading = false;
            });
            return;
          }
        }

        // 2. Upload avatar if changed
        String? finalAvatarUrl;
        if (_imageFile != null) {
          finalAvatarUrl = await SupabaseService.uploadProfileImage(user.id, _imageFile!);
        }

        // 3. Save all changes (Bio, Username, Avatar)
        await SupabaseService.saveUserUsername(user.id, username);
        await SupabaseService.saveUserBio(user.id, _bioController.text.trim());
        
        if (mounted) {
          setState(() {
            _successMessage = 'Profile updated!';
            _isLoading = false;
          });

          // Call callback and close after a short delay
          widget.onSave(username, _bioController.text.trim().isEmpty ? null : _bioController.text.trim());
          
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error saving profile: $e';
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
        'EDIT PROFILE',
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
            // Avatar Selector
            GestureDetector(
              onTap: _isLoading ? null : _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: matrixGreen, width: 2),
                      image: _imageFile != null
                          ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                          : (_avatarUrlPreview != null
                              ? DecorationImage(image: NetworkImage(_avatarUrlPreview!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: (_imageFile == null && _avatarUrlPreview == null)
                        ? const Icon(Icons.person, size: 50, color: matrixGreen)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: matrixGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: matrixBlack),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: matrixGreen),
              decoration: InputDecoration(
                hintText: 'Enter your username',
                hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.3)),
                helperText: '3-20 characters, letters, numbers, dashes, underscores',
                helperStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.5), fontSize: 11),
                helperMaxLines: 2,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
                enabled: !_isLoading,
              ),
              maxLength: 20,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              style: const TextStyle(color: matrixGreen),
              decoration: InputDecoration(
                hintText: 'Enter your bio (optional)',
                hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.3)),
                helperText: 'Tell others about yourself',
                helperStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.5), fontSize: 11),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
                enabled: !_isLoading,
              ),
              maxLines: 3,
              maxLength: 150,
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[900], fontSize: 12),
                ),
              ),
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _successMessage!,
                  style: TextStyle(color: Colors.green[900], fontSize: 12),
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
            onPressed: _isLoading ? null : _saveUsername,
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
                    'SAVE',
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
