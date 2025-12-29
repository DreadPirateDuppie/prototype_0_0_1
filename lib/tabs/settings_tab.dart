import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../providers/theme_provider.dart';
import '../screens/admin_dashboard.dart';
import '../utils/error_helper.dart';
import '../screens/premium_screen.dart';
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
  bool _isLoadingAdminStatus = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
    _checkAdminStatus();
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

  Future<void> _showFeedbackDialog() async {
    final feedbackController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Send Feedback'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('We would love to hear your thoughts!'),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type your feedback here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final text = feedbackController.text.trim();
                        if (text.isEmpty) return;

                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);

                        setState(() {
                          isSubmitting = true;
                        });

                        try {
                          await SupabaseService.submitFeedback(text);
                          if (mounted) {
                            navigator.pop();
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Thank you for your feedback!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              isSubmitting = false;
                            });
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
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
        backgroundColor: const Color(0xFF000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00FF41), width: 2),
        ),
        title: const Text(
          'Donate Crypto',
          style: TextStyle(
            color: Color(0xFF00FF41),
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Support the project with a Solana donation!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
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
              const Text(
                'Wallet Address:',
                style: TextStyle(color: Color(0xFF00FF41), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      walletAddress,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: walletAddress));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Address copied to clipboard'),
                            backgroundColor: Color(0xFF00FF41),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16, color: Color(0xFF00FF41)),
                      label: const Text(
                        'Copy Address',
                        style: TextStyle(color: Color(0xFF00FF41), fontSize: 12),
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
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
      children: [
        const SizedBox(height: 16),
        
        // Premium Banner
        Padding(
         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade600, Colors.amber.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade900.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Remove ads and unlock exclusive features',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PremiumScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Upgrade'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Preferences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Push notifications (Coming Soon)'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _saveNotificationPreference(value);
            },
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            value: context.watch<ThemeProvider>().isDarkMode,
            onChanged: (value) {
              context.read<ThemeProvider>().toggleDarkMode();
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Privacy Policy'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Privacy Policy\n\n'
                      'This app collects and stores:\n'
                      '• Your email address for authentication\n'
                      '• Location data for map posts\n'
                      '• Photos you upload\n'
                      '• Posts, ratings, and likes\n\n'
                      'Your data is stored securely on Supabase servers.\n\n'
                      'We do not sell or share your personal information with third parties.\n\n'
                      'You can delete your account and data at any time by contacting support.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Terms of Service'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Terms of Service\n\n'
                      'By using this app, you agree to:\n\n'
                      '1. Not post inappropriate, offensive, or illegal content\n'
                      '2. Respect other users and their posts\n'
                      '3. Not spam or abuse the platform\n'
                      '4. Take responsibility for the content you post\n'
                      '5. Respect intellectual property rights\n\n'
                      'We reserve the right to:\n'
                      '• Remove content that violates these terms\n'
                      '• Suspend or ban users who violate these terms\n'
                      '• Modify these terms at any time\n\n'
                      'Use of this app is at your own risk.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About'),
                  content: const SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location Sharing App',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Version: 1.0.0+1'),
                        SizedBox(height: 16),
                        Text(
                          'A social platform for discovering and sharing amazing locations with your community.',
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Features:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('• Interactive map with location pins'),
                        Text('• Photo sharing'),
                        Text('• Rating system'),
                        Text('• Social feed'),
                        Text('• User profiles'),
                        SizedBox(height: 16),
                        Text(
                          'Built with Flutter & Supabase',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Send Feedback'),
            subtitle: const Text('Report bugs or suggest features'),
            onTap: _showFeedbackDialog,
          ),
          ListTile(
            leading: const Icon(Icons.currency_bitcoin, color: Color(0xFF00FF41)),
            title: const Text('Donate Crypto'),
            subtitle: const Text('Support the developer'),
            onTap: _showDonationDialog,
          ),
          if (_isAdmin && !_isLoadingAdminStatus) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Administration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin Dashboard'),
              subtitle: const Text('Content moderation'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminDashboard(),
                  ),
                );
              },
            ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _handleSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
