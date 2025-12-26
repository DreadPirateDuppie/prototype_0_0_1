import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class LocationPrivacyDialog extends StatefulWidget {
  const LocationPrivacyDialog({super.key});

  @override
  State<LocationPrivacyDialog> createState() => _LocationPrivacyDialogState();
}

class _LocationPrivacyDialogState extends State<LocationPrivacyDialog> {
  String _sharingMode = 'off';
  List<String> _blacklist = [];
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Load current privacy settings
      final settings = await SupabaseService.getLocationPrivacySettings();
      
      // Load mutual followers (friends)
      final friends = await SupabaseService.getMutualFollowers();
      
      if (mounted) {
        setState(() {
          _sharingMode = settings['sharing_mode'] as String;
          _blacklist = settings['blacklist'] as List<String>;
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    try {
      await SupabaseService.updateLocationSharingMode(_sharingMode);
      await SupabaseService.updateLocationBlacklist(_blacklist);
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate settings were saved
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  void _toggleBlacklist(String userId) {
    setState(() {
      if (_blacklist.contains(userId)) {
        _blacklist.remove(userId);
      } else {
        _blacklist.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D0D),
              Color(0xFF000000),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00FF41).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF41).withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            const BoxShadow(
              color: Colors.black,
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF41)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.privacy_tip_outlined,
                          color: Color(0xFF00FF41),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'PRIVACY',
                        style: TextStyle(
                          color: Color(0xFF00FF41),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: () => Navigator.of(context).pop(false),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Privacy Mode Selection
                  const Text(
                    'VISIBILITY MODE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Radio Options as Cards
                  _buildModeCard(
                    value: 'off',
                    icon: Icons.visibility_off,
                    title: 'Off',
                    subtitle: 'No one can see your location',
                  ),
                  const SizedBox(height: 8),
                  _buildModeCard(
                    value: 'public',
                    icon: Icons.public,
                    title: 'Public',
                    subtitle: 'All users can see your location',
                  ),
                  const SizedBox(height: 8),
                  _buildModeCard(
                    value: 'friends',
                    icon: Icons.people,
                    title: 'Friends Only',
                    subtitle: 'Only mutual followers can see',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF00FF41).withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Blacklist Section
                  Row(
                    children: [
                      const Text(
                        'HIDE FROM',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF00FF41).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${_blacklist.length}',
                          style: const TextStyle(
                            color: Color(0xFF00FF41),
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: _friends.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, color: Colors.grey, size: 40),
                                  SizedBox(height: 8),
                                  Text(
                                    'No friends yet',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _friends.length,
                              itemBuilder: (context, index) {
                                final friend = _friends[index];
                                final friendId = friend['id'] as String;
                                final isBlacklisted = _blacklist.contains(friendId);
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: isBlacklisted
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CheckboxListTile(
                                    value: isBlacklisted,
                                    onChanged: (_) => _toggleBlacklist(friendId),
                                    title: Text(
                                      friend['username'] ?? friend['display_name'] ?? 'User',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                    activeColor: Colors.red,
                                    checkColor: Colors.white,
                                    dense: true,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF41),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: const Color(0xFF00FF41).withValues(alpha: 0.5),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(
                          Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'SAVE SETTINGS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.5,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildModeCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _sharingMode == value;
    
    return GestureDetector(
      onTap: () => setState(() => _sharingMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00FF41).withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00FF41)
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00FF41).withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00FF41) : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00FF41) : Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _sharingMode,
              onChanged: (val) => setState(() => _sharingMode = val!),
              activeColor: const Color(0xFF00FF41),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
