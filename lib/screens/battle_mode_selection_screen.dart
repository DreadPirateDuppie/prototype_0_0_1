import 'package:flutter/material.dart';
import 'create_battle_screen.dart';
import 'quick_match_lobby_dialog.dart';
import 'skate_lobby_setup_screen.dart';
import '../config/theme_config.dart';

class BattleModeSelectionScreen extends StatelessWidget {
  const BattleModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          '> NEW BATTLE',
          style: TextStyle(
            color: ThemeColors.matrixGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: ThemeColors.backgroundDark,
        iconTheme: const IconThemeData(color: ThemeColors.matrixGreen),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
            height: 1,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            
            // Quick Match
            _buildModeButton(
              context,
              title: 'QUICK MATCH',
              description: 'Find a random opponent instantly.',
              icon: Icons.flash_on,
              color: Colors.redAccent,
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const QuickMatchLobbyDialog(),
                ).then((result) {
                  if (result == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                });
              },
            ),

            const SizedBox(height: 24),

            // Play vs Friends
            _buildModeButton(
              context,
              title: 'PLAY VS FRIENDS',
              description: 'Challenge a friend or follower.',
              icon: Icons.person_add,
              color: ThemeColors.matrixGreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateBattleScreen(),
                  ),
                ).then((result) {
                  if (result == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                });
              },
            ),

            const SizedBox(height: 24),

            // Local Game
            _buildModeButton(
              context,
              title: 'LOCAL GAME (IRL)',
              description: 'Play offline with friends nearby.',
              icon: Icons.people_outline,
              color: Colors.blueAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SkateLobbySetupScreen(),
                  ),
                );
              },
            ),
            
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
