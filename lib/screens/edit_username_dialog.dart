import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class EditUsernameDialog extends StatefulWidget {
  final String currentUsername;
  final Function(String) onUsernameSaved;

  const EditUsernameDialog({
    super.key,
    required this.currentUsername,
    required this.onUsernameSaved,
  });

  @override
  State<EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<EditUsernameDialog> {
  late TextEditingController _usernameController;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.currentUsername.isNotEmpty ? widget.currentUsername : '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
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

    // Check if username is the same as current
    if (username.toLowerCase() == widget.currentUsername.toLowerCase()) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Check if username is available
      final isAvailable = await SupabaseService.isUsernameAvailable(username);
      
      if (!isAvailable) {
        setState(() {
          _errorMessage = 'Username is already taken';
          _isLoading = false;
        });
        return;
      }

      // Save username
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        await SupabaseService.saveUserUsername(user.id, username);
        
        if (mounted) {
          setState(() {
            _successMessage = 'Username saved!';
            _isLoading = false;
          });

          // Call callback and close after a short delay
          widget.onUsernameSaved(username);
          
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
          _errorMessage = 'Error saving username: $e';
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
        'EDIT USERNAME',
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
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: matrixGreen),
              decoration: InputDecoration(
                hintText: 'Enter your username',
                hintStyle: TextStyle(color: matrixGreen.withOpacity(0.3)),
                helperText: '3-20 characters, letters, numbers, dashes, underscores',
                helperStyle: TextStyle(color: matrixGreen.withOpacity(0.5), fontSize: 11),
                helperMaxLines: 2,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withOpacity(0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: matrixGreen, width: 2),
                ),
                enabled: !_isLoading,
              ),
              maxLength: 20,
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
              color: matrixGreen.withOpacity(0.7),
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
                color: matrixGreen.withOpacity(0.3),
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
