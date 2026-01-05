import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype_0_0_1/config/theme_config.dart';
import '../../providers/admin_provider.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final provider = context.read<AdminProvider>();
    final settings = provider.appSettings;
    
    // Default values if settings not loaded yet
    final defaults = {
      'base_daily_points': '3.5',
      'streak_bonus_multiplier': '0.5',
      'first_login_bonus': '10.0',
      'post_xp': '100.0',
      'vote_xp': '1.0',
    };

    defaults.forEach((key, defaultValue) {
      final value = settings[key]?.toString() ?? defaultValue;
      _controllers[key] = TextEditingController(text: value);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AdminProvider>();
    final newConfig = <String, dynamic>{};

    _controllers.forEach((key, controller) {
      newConfig[key] = double.tryParse(controller.text) ?? 0.0;
    });

    try {
      await provider.updatePointsConfig(newConfig);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CONFIG_UPDATED: SUCCESS', style: TextStyle(fontFamily: 'monospace')),
            backgroundColor: ThemeColors.matrixGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SYSERR: $e', style: TextStyle(fontFamily: 'monospace')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('POINTS_SYSTEM', Icons.monetization_on_outlined, ThemeColors.matrixGreen),
            _buildTextField(
              'base_daily_points', 
              'Base Daily Points', 
              'The baseline points awarded for a daily login.'
            ),
            _buildTextField(
              'streak_bonus_multiplier', 
              'Streak Bonus Multiplier', 
              'Additional points awarded per day of streak.'
            ),
            _buildTextField(
              'first_login_bonus', 
              'First Login Bonus', 
              'One-time points awarded to new users.'
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('XP_PROTOCOL', Icons.trending_up, ThemeColors.matrixGreen),
            _buildTextField(
              'post_xp', 
              'XP per Post', 
              'XP awarded when a map spot is verified.'
            ),
            _buildTextField(
              'vote_xp', 
              'XP per Upvote', 
              'XP awarded to the author when their post is liked.'
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColors.matrixGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'COMMIT_CHANGES',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '>_$title',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'monospace',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String key, String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _controllers[key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: ThemeColors.matrixGreen, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (double.tryParse(value) == null) return 'Invalid number';
              return null;
            },
          ),
        ],
      ),
    );
  }
}
