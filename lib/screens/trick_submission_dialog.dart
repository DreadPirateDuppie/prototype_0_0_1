import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/trick_definition.dart';
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
  final _trickNameController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skaterNameController = TextEditingController();
  
  bool _isSubmitting = false;
  bool _isOwnClip = true;
  String _selectedStance = 'regular';
  
  List<TrickDefinition> _suggestions = [];
  bool _isSearching = false;
  double _selectedDifficulty = 1.0;

  @override
  void dispose() {
    _trickNameController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    _skaterNameController.dispose();
    super.dispose();
  }

  Future<void> _onSearchTricks(String query) async {
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await SupabaseService.getTrickSuggestions(query);
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _submitVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await SupabaseService.submitTrick(
        spotId: widget.spotId,
        userId: user.id,
        url: _urlController.text.trim(),
        trickName: _trickNameController.text.trim(),
        skaterName: _isOwnClip ? null : _skaterNameController.text.trim(),
        description: _descriptionController.text.trim(),
        isOwnClip: _isOwnClip,
        stance: _selectedStance,
        difficultyMultiplier: _selectedDifficulty,
      );

      if (mounted) {
        widget.onTrickSubmitted();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trick submitted to archive!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error submitting trick: $e');
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
                const Text(
                  'LOG TO ARCHIVE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: matrixGreen,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Own Clip Toggle
                SwitchListTile(
                  title: const Text('Is this your clip?', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(
                    _isOwnClip ? 'Will contribute to your MVP score' : 'Archive for the community',
                    style: TextStyle(color: matrixGreen.withValues(alpha: 0.6), fontSize: 10),
                  ),
                  value: _isOwnClip,
                  onChanged: (val) => setState(() => _isOwnClip = val),
                  activeColor: matrixGreen,
                ),
                const SizedBox(height: 16),

                if (!_isOwnClip) ...[
                  TextFormField(
                    controller: _skaterNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Skater Name',
                      hintText: 'e.g., Nyjah Huston',
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Enter skater name' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Stance Selector
                const Text('Stance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['regular', 'fakie', 'nollie', 'switch'].map((stance) {
                    final isSelected = _selectedStance == stance;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedStance = stance),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? matrixGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: matrixGreen),
                        ),
                        child: Text(
                          stance.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.black : matrixGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                
                // Trick Name with Autocomplete
                TextFormField(
                  controller: _trickNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Trick Name *',
                    hintText: 'e.g., Kickflip',
                    suffixIcon: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: matrixGreen)) : null,
                  ),
                  onChanged: _onSearchTricks,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                
                // Suggestions List
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final s = _suggestions[index];
                        return ListTile(
                          title: Text(s.displayName, style: const TextStyle(color: matrixGreen, fontSize: 13)),
                          trailing: Text('LVL ${s.difficultyMultiplier}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          onTap: () {
                            setState(() {
                              _trickNameController.text = s.displayName;
                              _selectedDifficulty = s.difficultyMultiplier;
                              _suggestions = [];
                            });
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Video URL (optional)',
                    hintText: 'https://youtube.com/...',
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: matrixGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('SUBMIT TO ARCHIVE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
