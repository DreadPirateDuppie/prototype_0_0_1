import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/user_points.dart';
import '../widgets/wheel_spin.dart';
import '../widgets/ad_banner.dart';

class RewardsTab extends StatefulWidget {
  const RewardsTab({super.key});

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  UserPoints? _userPoints;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPoints();
  }

  Future<void> _loadUserPoints() async {
    final user = SupabaseService.getCurrentUser();
    if (user == null) return;

    try {
      final points = await SupabaseService.getUserPoints(user.id);
      setState(() {
        _userPoints = points;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSpinComplete(int pointsWon) async {
    final user = SupabaseService.getCurrentUser();
    if (user == null) return;

    try {
      final updatedPoints = await SupabaseService.updatePointsAfterSpin(
        user.id,
        pointsWon,
      );

      if (!mounted) return;

      setState(() {
        _userPoints = updatedPoints;
      });

      // Show congratulations dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Congratulations! 🎉'),
          content: Text('You won $pointsWon points!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Awesome!'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating points: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const AdBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                    Card(
                      color: Colors.amber.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Your Points',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userPoints?.points.toString() ?? '0',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Daily Wheel Spin',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_userPoints?.lastSpinDate != null &&
                        !_userPoints!.canSpinToday())
                      Text(
                        'Next spin available tomorrow!',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(height: 16),
                    WheelSpin(
                      onSpinComplete: _handleSpinComplete,
                      canSpin: _userPoints?.canSpinToday() ?? true,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Available Rewards',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        final pointCost = 500 + (index * 100);
                        final canAfford =
                            (_userPoints?.points ?? 0) >= pointCost;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.card_giftcard,
                              color: Colors.deepPurple.shade300,
                            ),
                            title: Text('Reward ${index + 1}'),
                            subtitle: Text('$pointCost points'),
                            trailing: ElevatedButton(
                              onPressed: canAfford ? () {} : null,
                              child: const Text('Redeem'),
                            ),
                          ),
                        );
                      },
                    ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
