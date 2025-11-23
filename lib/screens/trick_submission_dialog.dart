import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class TrickSubmissionDialog extends StatefulWidget {
  final String spotId;

  const TrickSubmissionDialog({super.key, required this.spotId});

  @override
  State<TrickSubmissionDialog> createState() => _TrickSubmissionDialogState();
}

class _TrickSubmissionDialogState extends State<TrickSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _skaterNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _urlController.dispose();
    _skaterNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    // URL is optional now
    if (value == null || value.isEmpty) {
      return null; // Allow empty for tricks without videos
    }
    
    final lowerValue = value.toLowerCase();
    final supportedPlatforms = [
      'youtube.com',
      'youtu.be',
      'instagram.com',
      'tiktok.com',
      'vimeo.com',
    ];
    
    if (!supportedPlatforms.any((platform) => lowerValue.contains(platform))) {
      return 'URL must be from YouTube, Instagram, TikTok, or Vimeo';
    }
    
    return null;
  }

  Future<void> _submitVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await SupabaseService.submitSpotVideo(
        spotId: widget.spotId,
        url: _urlController.text.trim(),
        skaterName: _skaterNameController.text.trim().isEmpty 
            ? null 
            : _skaterNameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Video submitted for review!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      'Submit Trick',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
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
                const SizedBox(height: 24),
                
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitVideo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit Trick'),
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
