import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For ImageFilter
import '../services/supabase_service.dart';
import '../providers/theme_provider.dart';
import '../screens/admin_dashboard.dart';
import '../utils/error_helper.dart';
import '../screens/premium_screen.dart';
import '../config/theme_config.dart'; // For ThemeColors
import '../screens/edit_username_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _notificationsEnabled = true;
  bool _isAdmin = false;
  bool _isPrivate = false;
  bool _isLoadingAdminStatus = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
    _loadPrivacySettings();
    _checkAdminStatus();
  }

  Future<void> _loadPrivacySettings() async {
    final user = SupabaseService.getCurrentUser();
    if (user != null) {
      final isPrivate = await SupabaseService.isUserPrivate(user.id);
      if (mounted) {
        setState(() {
          _isPrivate = isPrivate;
        });
      }
    }
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await SupabaseService.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isLoadingAdminStatus = false;
        });

        // Show welcome message if user is admin
        if (isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hello Admin :)'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _isLoadingAdminStatus = false;
        });
      }
    }
  }

  Future<void> _loadNotificationPreference() async {
    // Load saved preference (would need shared_preferences package)
    // For now, just set default
    setState(() {
      _notificationsEnabled = true;
    });
  }

  Future<void> _saveNotificationPreference(bool value) async {
    // Save preference (would need shared_preferences package)
    // For now, just show message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Notifications enabled (Push notifications will be available in a future update)'
                : 'Notifications disabled',
          ),
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await SupabaseService.signOut();
      if (mounted) {
        // Pop all routes to return to the root AuthWrapper
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(context, 'Sign out error: $error');
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final profile = await SupabaseService.getUserProfile(user.id);
      if (mounted) {
        setState(() => _isLoading = false);
        if (profile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not retrieve profile data.')),
          );
          return;
        }
        showDialog(
          context: context,
          builder: (context) => EditUsernameDialog(
            currentUsername: profile['username'] ?? '',
            currentBio: profile['bio'],
            onSave: (newUsername, newBio) {
              // Profile is updated in the database by the dialog itself
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully.'),
                  backgroundColor: ThemeColors.matrixGreen,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showFeedbackDialog() async {
    final feedbackController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: ThemeColors.matrixGreen, width: 1),
            ),
            title: Text(
              '>_FEEDBACK_PROTO',
              style: TextStyle(
                color: ThemeColors.matrixGreen,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transmit your thoughts to the collective.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter data pulse here...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: ThemeColors.matrixGreen.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: ThemeColors.matrixGreen),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('ABORT', style: TextStyle(color: Colors.white54, fontFamily: 'monospace')),
              ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final text = feedbackController.text.trim();
                        if (text.isEmpty) return;

                        setState(() => isSubmitting = true);

                        try {
                          await SupabaseService.submitFeedback(text);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Feedback transmitted successfully.'),
                                backgroundColor: ThemeColors.matrixGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeColors.matrixGreen))
                    : Text('TRANSMIT', style: TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDonationDialog() async {
    const String walletAddress = '8ALU6TcNWshAK9Ah6vYN6TKfTV8U5Dj9UEgGq78UUeZ9LD5AiN5Gu9D8Q15dMKDo1p5aKkSRTtypaiN17bKrgnbVTV5gmjw';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ThemeColors.matrixGreen, width: 1),
        ),
        title: Text(
          '>_SUPPORT_PROTOCOL',
          style: TextStyle(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Support the architecture with a Solana donation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: walletAddress,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '[SOL_WALLET_ADDRESS]',
                style: TextStyle(color: ThemeColors.matrixGreen.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThemeColors.matrixGreen.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Text(
                      walletAddress,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: walletAddress));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Address copied to system clipboard.'),
                            backgroundColor: ThemeColors.matrixGreen,
                          ),
                        );
                      },
                      icon: Icon(Icons.copy, size: 14, color: ThemeColors.matrixGreen),
                      label: Text(
                        'COPY_STRING',
                        style: TextStyle(color: ThemeColors.matrixGreen, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DISMISS', style: TextStyle(color: Colors.white54, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final neonGreen = ThemeColors.matrixGreen;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: neonGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '>_SYSTEM_CONFIG',
          style: TextStyle(
            color: neonGreen,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),
          
          // Premium Banner
          _buildPremiumBanner(),
          
          const SizedBox(height: 24),
          
          _buildSectionHeader('PROTOCOL_PREFERENCES'),
          _buildGlassCard(
            child: Column(
              children: [
                _buildSwitchItem(
                  'Notifications',
                  'Push notifications [STATUS: PENDING]',
                  _notificationsEnabled,
                  (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveNotificationPreference(value);
                  },
                ),
                _buildDivider(),
                _buildSwitchItem(
                  'Private Account',
                  'Only followers can see your posts & pins',
                  _isPrivate,
                  (value) async {
                    setState(() => _isPrivate = value);
                    try {
                      await SupabaseService.setPrivacy(value);
                    } catch (e) {
                      if (mounted) {
                         setState(() => _isPrivate = !value); // Revert on error
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Error updating privacy: $e')),
                         );
                      }
                    }
                  },
                ),
                _buildDivider(),
                _buildSwitchItem(
                  'Dark Mode',
                  'Enable dark theme encryption',
                  context.watch<ThemeProvider>().isDarkMode,
                  (value) => context.read<ThemeProvider>().toggleDarkMode(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          
          _buildSectionHeader('USER_ACCOUNT'),
          _buildGlassCard(
            child: Column(
              children: [
                _buildSettingsItem(
                  'Edit Profile',
                  Icons.person_outline,
                  onTap: _showEditProfileDialog,
                ),
                _buildDivider(),
                _buildSettingsItem(
                  'Privacy Policy',
                  Icons.privacy_tip_outlined,
                  onTap: () => _showPolicyDialog('Privacy Policy', 'This app collects and stores:\n• Your email address for authentication\n• Location data for map posts\n• Photos you upload\n• Posts, ratings, and likes\n\nYour data is stored securely on Supabase servers.\n\nWe do not sell or share your personal information with third parties.'),
                ),
                _buildDivider(),
                _buildSettingsItem(
                  'Terms of Service',
                  Icons.description_outlined,
                  onTap: () => _showPolicyDialog('Terms of Service', 'By using this app, you agree to:\n1. Not post inappropriate, offensive, or illegal content\n2. Respect other users and their posts\n3. Not spam or abuse the platform\n4. Take responsibility for the content you post\n5. Respect intellectual property rights'),
                ),
                _buildDivider(),
                _buildSettingsItem(
                  'About System',
                  Icons.info_outline,
                  onTap: () => _showAboutDialog(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          
          _buildSectionHeader('SUPPORT_CHANNELS'),
          _buildGlassCard(
            child: Column(
              children: [
                _buildSettingsItem(
                  'Send Feedback',
                  Icons.feedback_outlined,
                  onTap: _showFeedbackDialog,
                ),
                _buildDivider(),
                _buildSettingsItem(
                  'Donate Crypto',
                  Icons.currency_bitcoin,
                  iconColor: neonGreen,
                  onTap: _showDonationDialog,
                ),
              ],
            ),
          ),

          if (_isAdmin && !_isLoadingAdminStatus) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('ADMINISTRATION_LEVEL_0'),
            _buildGlassCard(
              child: _buildSettingsItem(
                'Admin Dashboard',
                Icons.admin_panel_settings_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminDashboard()),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 32),
          
          // Sign Out Button
          Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              color: Colors.redAccent.withValues(alpha: 0.1),
            ),
            child: InkWell(
              onTap: _handleSignOut,
              borderRadius: BorderRadius.circular(8),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'TERMINATE_SESSION',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner() {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.3),
            Colors.amber.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.amber.withValues(alpha: 0.2), size: 40),
                    const Icon(Icons.bolt, color: Colors.amber, size: 24),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PREMIUM_ACCESS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unlock all protocols & remove data interceptors.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PremiumScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: Colors.amber, width: 1),
                    ),
                  ),
                  child: const Text(
                    'UPGRADE',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        '[$title]',
        style: TextStyle(
          color: ThemeColors.matrixGreen.withValues(alpha: 0.7),
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, {VoidCallback? onTap, Color? iconColor}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor ?? Colors.white70, size: 20),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'monospace',
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
      dense: true,
    );
  }

  Widget _buildSwitchItem(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: ThemeColors.matrixGreen,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
      ),
      dense: true,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.white.withValues(alpha: 0.05), indent: 50);
  }

  void _showPolicyDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ThemeColors.matrixGreen, width: 1),
        ),
        title: Text(
          '>_$title',
          style: const TextStyle(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('DISMISS', style: TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ThemeColors.matrixGreen, width: 1),
        ),
        title: Text(
          '>_SYSTEM_INFO',
          style: TextStyle(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PUSHINN_PROTOCOL',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'v1.0.0_stable_build',
              style: TextStyle(color: ThemeColors.matrixGreen.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            Text(
              'A decentralized geographic intelligence network for the community.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ACKNOWLEDGE', style: TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
