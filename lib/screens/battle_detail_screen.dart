import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/battle_detail_provider.dart';
import '../widgets/battle/battle_header.dart';
import '../widgets/battle/battle_video_section.dart';
import '../widgets/battle/battle_player_vs_section.dart';
import '../widgets/battle/battle_action_panel.dart';
import '../widgets/battle/battle_history_carousel.dart';
import '../config/theme_config.dart';
import '../models/battle.dart';
import '../widgets/battle/rps_selection_grid.dart';
import '../services/supabase_service.dart';

class BattleDetailScreen extends StatefulWidget {
  final String? battleId;
  final Battle? battle;
  final bool tutorialMode;
  final String? tutorialUserId;

  const BattleDetailScreen({
    super.key, 
    this.battleId,
    this.battle,
    this.tutorialMode = false,
    this.tutorialUserId,
  });

  @override
  State<BattleDetailScreen> createState() => _BattleDetailScreenState();
}

class _BattleDetailScreenState extends State<BattleDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BattleDetailProvider>(context, listen: false);
      provider.initialize(
        widget.battleId, 
        widget.battle, 
        tutorialMode: widget.tutorialMode
      );
      provider.addListener(_onProviderUpdate);
    });
  }

  @override
  void dispose() {
    // We don't dispose the provider here as it's provided at a higher level
    // but we should remove the listener.
    final provider = Provider.of<BattleDetailProvider>(context, listen: false);
    provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    final provider = Provider.of<BattleDetailProvider>(context, listen: false);
    final battle = provider.battle;
    if (battle == null) return;

    // Handle Winner Dialog
    if (battle.winnerId != null) {
      _showWinnerDialog(battle.winnerId!);
    }

    // Handle Tie SnackBar
    // (This logic might need a "previousBattle" state in the provider to detect transitions)
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BattleDetailProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Scaffold(
            backgroundColor: ThemeColors.backgroundDark,
            body: const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen)),
          );
        }

        final battle = provider.battle;
        if (battle == null) {
          return Scaffold(
            backgroundColor: ThemeColors.backgroundDark,
            body: const Center(child: Text('Battle not found', style: TextStyle(color: Colors.white))),
          );
        }

        // RPS Screen (No setter yet)
        if (battle.setterId == null) {
          return Scaffold(
            backgroundColor: ThemeColors.backgroundDark,
            appBar: const BattleHeader(),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: RpsSelectionGrid(
                  battle: battle,
                  onMoveSelected: provider.submitRpsMove,
                  onForfeit: provider.forfeitBattle,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: ThemeColors.backgroundDark,
          appBar: const BattleHeader(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.isTutorial) ...[
                  _buildTutorialBanner(provider),
                  const SizedBox(height: AppSpacing.md),
                ],
                const BattleInfoSection(),
                const SizedBox(height: AppSpacing.lg),
                const BattleVideoSection(),
                const SizedBox(height: AppSpacing.lg),
                const BattlePlayerVsSection(),
                const SizedBox(height: AppSpacing.lg),
                const BattleActionPanel(),
                const SizedBox(height: 24),
                BattleHistoryCarousel(battleId: battle.id!),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTutorialBanner(BattleDetailProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Welcome to Battle Mode! Follow the steps to play.',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.white),
            onPressed: () => provider.setTutorial(false),
          ),
        ],
      ),
    );
  }

  void _showWinnerDialog(String winnerId) async {
    // Get winner profile
    String? avatarUrl;
    String winnerName = 'Winner';
    
    try {
      final profile = await SupabaseService.getUserProfile(winnerId);
      if (profile != null) {
        avatarUrl = profile['avatar_url'];
        winnerName = profile['username'] ?? 'Winner';
      }
    } catch (e) {
      // Ignore error, just show default
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: ThemeColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: ThemeColors.matrixGreen,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  color: ThemeColors.matrixGreen,
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ThemeColors.matrixGreen,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person,
                            size: 50,
                            color: ThemeColors.matrixGreen,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 50,
                          color: ThemeColors.matrixGreen,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                winnerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'WINS THE BATTLE!',
                style: TextStyle(
                  color: ThemeColors.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close battle screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColors.matrixGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'BACK TO LOBBY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
