import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isPublic = true;
  String _sharingMode = 'off';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) return;

      final isPrivate = await SupabaseService.isUserPrivate(userId);
      final locationSettings = await SupabaseService.getLocationPrivacySettings();
      
      if (mounted) {
        setState(() {
          _isPublic = !isPrivate;
          _sharingMode = locationSettings['sharing_mode'] as String? ?? 'off';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHelper.showError(context, 'Error loading privacy settings: $e');
      }
    }
  }

  Future<void> _updateProfilePrivacy(bool isPublic) async {
    try {
      await SupabaseService.setPrivacy(!isPublic);
      setState(() => _isPublic = isPublic);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error updating profile privacy: $e');
      }
    }
  }

  Future<void> _updateSharingMode(String mode) async {
    try {
      await SupabaseService.updateLocationSharingMode(mode);
      setState(() => _sharingMode = mode);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error updating sharing mode: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: matrixGreen),
        title: const Text(
          'PRIVACY_CONTROLS',
          style: TextStyle(
            color: matrixGreen,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: matrixGreen))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader('PROFILE PRIVACY'),
                _buildSwitchTile(
                    'Public Profile',
                    'Allow others to see your posts and profile',
                    _isPublic,
                    (val) => _updateProfilePrivacy(val)),
                const SizedBox(height: 32),
                _buildSectionHeader('LOCATION SHARING'),
                _buildModeTile('Public', 'Everyone can see your approximate location when active', 'public'),
                _buildModeTile('Friends Only', 'Only mutual followers can see you', 'friends'),
                _buildModeTile('Ghost Mode', 'Your location is hidden from everyone', 'off'),
                const SizedBox(height: 48),
                const Text(
                  '// NOTE: Location sharing automatically disables after 1 hour of inactivity to protect your privacy.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00FF41),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF00FF41),
        ),
      ),
    );
  }

  Widget _buildModeTile(String title, String subtitle, String mode) {
    final isSelected = _sharingMode == mode;
    return GestureDetector(
      onTap: () => _updateSharingMode(mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FF41).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FF41) : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getIconForMode(mode),
              color: isSelected ? const Color(0xFF00FF41) : Colors.white24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00FF41) : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF00FF41), size: 18),
          ],
        ),
      ),
    );
  }

  IconData _getIconForMode(String mode) {
    switch (mode) {
      case 'public':
        return Icons.public;
      case 'friends':
        return Icons.people;
      case 'off':
        return Icons.visibility_off;
      default:
        return Icons.help_outline;
    }
  }
}
