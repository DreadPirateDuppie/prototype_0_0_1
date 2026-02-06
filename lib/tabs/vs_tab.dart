import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme_config.dart';
import '../providers/vs_tab_provider.dart';
import '../screens/battle_mode_selection_screen.dart';
import '../widgets/vs/vs_battle_card.dart';
import '../widgets/vs/vs_leaderboard_section.dart';
import '../widgets/vs/empty_battle_state.dart';

class VsTab extends StatelessWidget {
  const VsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VsTabProvider(),
      child: const _VsTabContent(),
    );
  }
}

class _VsTabContent extends StatefulWidget {
  const _VsTabContent();

  @override
  State<_VsTabContent> createState() => _VsTabContentState();
}

class _VsTabContentState extends State<_VsTabContent> {
  final _currentUser = Supabase.instance.client.auth.currentUser;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      // Initial load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<VsTabProvider>().loadData(_currentUser.id);
      });
      _startRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Check for expired battles to trigger refresh
        final provider = context.read<VsTabProvider>();
        final battles = provider.activeBattles;
        bool shouldRefresh = false;
        
        for (final battle in battles) {
          final remaining = battle.getRemainingTime();
          if (remaining != null && remaining.inSeconds <= 0) {
             shouldRefresh = true;
             break;
          }
        }

        if (shouldRefresh && !provider.isLoading && _currentUser != null) {
           provider.refresh(_currentUser.id);
        }

        // Trigger rebuild for countdowns
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VsTabProvider>(
      builder: (context, provider, child) {
        final battles = provider.activeBattles;
        final leaderboard = provider.leaderboard;
        final isLoading = provider.isLoading;

        return Scaffold(
          backgroundColor: Colors.transparent, // Show global Matrix
          appBar: AppBar(
            title: const Text(
              '> PUSHINN_',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ThemeColors.matrixGreen,
                letterSpacing: 2,
                fontSize: 20,
                fontFamily: 'monospace',
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent, // Transparent AppBar
            foregroundColor: ThemeColors.matrixGreen,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                height: 1,
              ),
            ),
          ),
          body: isLoading && battles.isEmpty && leaderboard.isEmpty
              ? const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen))
              : RefreshIndicator(
                  color: ThemeColors.matrixGreen,
                  backgroundColor: ThemeColors.backgroundDark,
                  onRefresh: () async {
                    if (_currentUser != null) {
                      await provider.refresh(_currentUser.id);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: battles.length + 2, // +1 for leaderboard, +1 for create button
                    itemBuilder: (context, index) {
                      // 1. Leaderboard Section
                      if (index == 0) {
                        return VsLeaderboardSection(
                          leaderboard: leaderboard,
                          isLoading: isLoading && leaderboard.isEmpty,
                          currentUserId: _currentUser?.id,
                        );
                      }

                      // 2. Battle List
                      if (index <= battles.length) {
                        final battle = battles[index - 1];
                        return VsBattleCard(
                          battle: battle,
                          onRefresh: () {
                            if (_currentUser != null) {
                              provider.refresh(_currentUser.id);
                            }
                          },
                        );
                      }

                      // 3. Create Battle Button (and Empty State if needed)
                      return Column(
                        children: [
                          if (battles.isEmpty) const EmptyBattleState(),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const BattleModeSelectionScreen(),
                                  ),
                                );
                                if ((result != null || mounted) && _currentUser != null) {
                                  provider.refresh(_currentUser.id);
                                }
                              },
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('CREATE NEW BATTLE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeColors.matrixGreen,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                                ),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
