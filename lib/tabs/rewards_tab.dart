import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rewards_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/ad_banner.dart';
import '../widgets/rewards/rewards_hero.dart';
import '../widgets/rewards/rewards_streak_card.dart';
import '../widgets/rewards/rewards_earn_section.dart';
import '../widgets/rewards/rewards_transaction_history.dart';
import '../screens/rewards/transaction_history_screen.dart';

class RewardsTab extends StatefulWidget {
  const RewardsTab({super.key});

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RewardsProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RewardsProvider>(
      builder: (context, rewardsProvider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent, // Show global Matrix
          appBar: AppBar(
            title: const Text(
              '> PUSHINN_',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF41),
                letterSpacing: 2,
                fontSize: 20,
                fontFamily: 'monospace',
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: rewardsProvider.loadData,
              ),
            ],
          ),
          body: rewardsProvider.isLoading && rewardsProvider.transactions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    await Future.wait<void>([
                      rewardsProvider.loadData(),
                      userProvider.refresh(),
                    ]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        const AdBanner(),
                        RewardsHero(points: rewardsProvider.points),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              RewardsStreakCard(
                                streak: rewardsProvider.streak,
                                hasCheckedInToday: rewardsProvider.hasCheckedInToday(),
                                isLoading: rewardsProvider.isLoading,
                                onCheckIn: () => _handleCheckIn(context, rewardsProvider),
                              ),
                              const SizedBox(height: 24),
                              RewardsEarnSection(
                                onWatchAd: () => _handleWatchAd(context, rewardsProvider),
                              ),
                              const SizedBox(height: 24),
                              RewardsTransactionHistory(
                                transactions: rewardsProvider.transactions,
                                onViewAll: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TransactionHistoryScreen(
                                        transactions: rewardsProvider.transactions,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _handleCheckIn(BuildContext context, RewardsProvider provider) async {
    try {
      final points = await provider.checkDailyLogin();
      if (!context.mounted) return;
      if (points > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Daily Check-in: Earned $points points!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Already checked in today! Come back tomorrow.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking in: $e')),
      );
    }
  }

  Future<void> _handleWatchAd(BuildContext context, RewardsProvider provider) async {
    await provider.showRewardedAd(
      onRewardEarned: (amount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Earned $amount points for watching!'),
              backgroundColor: const Color(0xFF00FF41),
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ad error: $error')),
          );
        }
      },
    );
  }
}
