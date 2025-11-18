import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/user_points.dart';
import '../widgets/wheel_spin.dart';
import '../providers/error_provider.dart';
import 'dart:math' as math;

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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D3E),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required String type,
    required int amount,
    required bool isPositive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPositive
                  ? Colors.green.withAlpha((255 * 0.2).round())
                  : Colors.red.withAlpha((255 * 0.2).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.arrow_downward : Icons.arrow_upward,
              color: isPositive ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateTime.now().hour}:${DateTime.now().minute} • Today',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'}$amount PTS',
            style: GoogleFonts.poppins(
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
          backgroundColor: const Color(0xFF1E1E2E),
          title: Text(
            'Congratulations! 🎉',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          content: Text(
            'You won $pointsWon points!',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Awesome!',
                style: TextStyle(color: Color(0xFF6C63FF)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Provider.of<ErrorProvider>(
        context,
        listen: false,
      ).showError('Error updating points: $e');
    }
  }

  DateTime? _computeNextSpinAt(DateTime? lastSpinDate) {
    if (lastSpinDate == null) return null;
    final base = DateTime(
      lastSpinDate.year,
      lastSpinDate.month,
      lastSpinDate.day,
    );
    return base.add(const Duration(days: 1));
  }

  void _showWheelSpinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Spin to Earn',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              WheelSpin(
                onSpinComplete: _handleSpinComplete,
                canSpin: _userPoints?.canSpinToday() ?? true,
                nextSpinAt: _computeNextSpinAt(_userPoints?.lastSpinDate),
              ),
              const SizedBox(height: 10),
              if (_userPoints?.lastSpinDate != null &&
                  !_userPoints!.canSpinToday())
                Text(
                  'Next spin available tomorrow!',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Background gradient
                Container(
                  width: double.infinity,
                  height: size.height * 0.3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF6C63FF).withAlpha((255 * 0.8).round()),
                        const Color(0xFF0F0F1E).withAlpha((255 * 0.1).round()),
                      ],
                    ),
                  ),
                ),

                // Main content
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header with balance
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 30),
                            // Balance card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2E),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      (255 * 0.2).round(),
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'TOTAL BALANCE',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${_userPoints?.points.toString() ?? '0'} PTS',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Action buttons
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.refresh,
                                        label: 'Spin',
                                        onTap: _showWheelSpinDialog,
                                      ),
                                      _buildActionButton(
                                        icon: Icons.arrow_upward,
                                        label: 'Send',
                                        onTap: () {},
                                      ),
                                      _buildActionButton(
                                        icon: Icons.arrow_downward,
                                        label: 'Receive',
                                        onTap: () {},
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Recent transactions header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Activity',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'See All',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF6C63FF),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Recent transactions list
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 5,
                          itemBuilder: (context, index) {
                            final types = ['Received', 'Sent', 'Earned'];
                            final random = math.Random();
                            final type = types[random.nextInt(types.length)];
                            final amount = random.nextInt(1000) + 10;

                            return _buildTransactionItem(
                              type: type,
                              amount: amount,
                              isPositive: type != 'Sent',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
