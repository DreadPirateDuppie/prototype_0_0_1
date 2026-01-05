import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_helper.dart';

class TrickSubmissionDialog extends StatefulWidget {
  final String spotId;
  final VoidCallback onTrickSubmitted;

  const TrickSubmissionDialog({
    super.key,
    required this.spotId,
    required this.onTrickSubmitted,
  });

  @override
  State<TrickSubmissionDialog> createState() => _TrickSubmissionDialogState();
}

class _TrickSubmissionDialogState extends State<TrickSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _skaterNameController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _skaterNameController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAbsolutePath) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  Future<void> _submitVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final tags = _tagsController.text.trim().isEmpty 
          ? [] 
          : _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      await Supabase.instance.client.from('spot_videos').insert({
        'spot_id': widget.spotId,
        'user_id': user.id, // Keep user_id for RLS/FK, but ensure we also use trick_name
        'trick_name': _skaterNameController.text.trim(),
        'url': _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'tags': tags,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        widget.onTrickSubmitted();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trick submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'SUBMIT TRICK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: matrixGreen,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: matrixGreen),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Trick Description/Name Field  
                TextFormField(
                  controller: _skaterNameController,
                  decoration: const InputDecoration(
                    labelText: 'Trick Name *',
                    hintText: 'e.g., Kickflip, 360 Flip',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter trick name';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                
                // URL Field (optional)
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Video URL (optional)',
                    hintText: 'https://youtube.com/...',
                    border: OutlineInputBorder(),
                    helperText: 'You can add a video link later',
                    helperMaxLines: 2,
                  ),
                  validator: _validateUrl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                
                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g., Down 10 stair, first try',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                
                // Tags Field
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    hintText: 'e.g., flatground, technical, ledge',
                    border: OutlineInputBorder(),
                    helperText: 'Separate tags with commas',
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),
                
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: matrixGreen.withValues(alpha: 0.7),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                        onPressed: _isSubmitting ? null : _submitVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matrixBlack,
                          foregroundColor: matrixGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: matrixGreen,
                                ),
                              )
                            : const Text(
                                'SUBMIT TRICK',
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
      ),
    );
  }
}
