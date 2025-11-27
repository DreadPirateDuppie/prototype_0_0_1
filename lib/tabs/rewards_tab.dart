import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/rewarded_ad_service.dart';
import '../widgets/ad_banner.dart';

class RewardsTab extends StatefulWidget {
  const RewardsTab({super.key});

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  double _points = 0.0;
  int _streak = 0;
  DateTime? _lastLoginDate;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final points = await SupabaseService.getUserPoints(user.id);
      final streakData = await SupabaseService.getUserStreak(user.id);
      final transactions = await SupabaseService.getPointTransactions(user.id);

      if (mounted) {
        setState(() {
          _points = points;
          _transactions = transactions;
          
          // Calculate effective streak
          final dbStreak = streakData['current_streak'] as int;
          final lastLoginStr = streakData['last_login_date'] as String?;
          _lastLoginDate = lastLoginStr != null ? DateTime.parse(lastLoginStr) : null;
          
          if (_lastLoginDate == null) {
            _streak = 0;
          } else {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final lastLogin = DateTime(_lastLoginDate!.year, _lastLoginDate!.month, _lastLoginDate!.day);
            final difference = today.difference(lastLogin).inDays;
            
            if (difference > 1) {
              // Streak is broken (missed more than 1 day)
              _streak = 0;
            } else if (difference == 0) {
              // Last login was today - verify we have a transaction
              final hasTransaction = transactions.any((tx) {
                final txDate = DateTime.parse(tx['created_at'] as String).toLocal();
                final txDay = DateTime(txDate.year, txDate.month, txDate.day);
                return tx['transaction_type'] == 'daily_login' && txDay.isAtSameMomentAs(today);
              });
              _streak = hasTransaction ? dbStreak : 0;
            } else {
              // Last login was yesterday - show previous streak until check-in
              _streak = dbStreak;
            }
          }
          
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Rewards',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const AdBanner(),
                    _buildHeroSection(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildStreakSection(),
                          const SizedBox(height: 24),
                          _buildEarnSection(context),
                          const SizedBox(height: 24),
                          _buildCryptoTeaser(),
                          const SizedBox(height: 24),
                          _buildTransactionHistory(context),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF000000), // Matrix Black
            const Color(0xFF0D0D0D), // Matrix Surface
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0.0, 0.7, 0.7],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            children: [
              // Wallet Card
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF000000), // Matrix Black
                      Color(0xFF003300), // Dark Green
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF00FF41), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF41).withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'PUSHINN WALLET',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.nfc, color: Colors.white.withValues(alpha: 0.3), size: 32),
                            ],
                          ),
                          
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Balance',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _points.toStringAsFixed(2),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PTS',
                                    style: TextStyle(
                                      color: Color(0xFF00FF41),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Streak',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00FF41),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep the fire burning!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Color(0xFF00FF41), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '$_streak Days',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00FF41),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Check In Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _hasCheckedInToday() ? null : _checkDailyLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _hasCheckedInToday() ? 0 : 4,
                shadowColor: const Color(0xFF00FF41).withValues(alpha: 0.4),
              ),
              child: _isLoading 
                  ? const SizedBox(
                      height: 20, 
                      width: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_hasCheckedInToday() ? Icons.check_circle : Icons.touch_app),
                        const SizedBox(width: 8),
                        Text(
                          _hasCheckedInToday() ? 'CHECKED IN TODAY' : 'CHECK IN NOW',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              // Calculate how many days are active in the current 7-day cycle
              // Streak 0 -> 0 active
              // Streak 1 -> 1 active
              // Streak 7 -> 7 active
              // Streak 8 -> 1 active
              final activeCount = _streak == 0 ? 0 : ((_streak - 1) % 7) + 1;
              final isActive = index < activeCount;
              
              // Is this the specific day we just checked in for?
              // (Only relevant if we want to animate or highlight the "current" one differently)
              final isToday = index == (activeCount - 1) && _streak > 0;
              
              const matrixGreen = Color(0xFF00FF41);
              
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive 
                          ? matrixGreen.withValues(alpha: 0.2)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? matrixGreen : matrixGreen.withValues(alpha: 0.2),
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ] : null,
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      size: 20,
                      color: isActive ? matrixGreen : matrixGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Day ${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? matrixGreen : matrixGreen.withValues(alpha: 0.5),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  bool _hasCheckedInToday() {
    if (_lastLoginDate == null) return false;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastLogin = DateTime(_lastLoginDate!.year, _lastLoginDate!.month, _lastLoginDate!.day);
    
    // Check if last login was today
    if (!lastLogin.isAtSameMomentAs(today)) {
      return false;
    }

    // If logged in today, verify we have a transaction (to handle failed awards)
    final hasTransaction = _transactions.any((tx) {
      final txDate = DateTime.parse(tx['created_at'] as String).toLocal();
      final txDay = DateTime(txDate.year, txDate.month, txDate.day);
      return tx['transaction_type'] == 'daily_login' && txDay.isAtSameMomentAs(today);
    });

    return hasTransaction;
  }

  Widget _buildEarnSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ways to Earn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00FF41),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _buildEarnCard(
                icon: Icons.add_location_alt,
                color: const Color(0xFF00FF41),
                title: 'Create Spot',
                points: '+3.5',
              ),
              const SizedBox(width: 12),
              _buildWatchAdCard(),
              const SizedBox(width: 12),
              /* 
              // Removed redundant Daily Login card as it is now a main button
              _buildEarnCard(
                icon: Icons.login,
                color: const Color(0xFF00FF41),
                title: 'Daily Login',
                points: '+10+',
                onTap: _checkDailyLogin,
              ),
              const SizedBox(width: 12),
              */
              _buildEarnCard(
                icon: Icons.sports_kabaddi,
                color: const Color(0xFF00FF41),
                title: 'Win Battle',
                points: 'Win Pot',
              ),
              const SizedBox(width: 12),
              _buildBettingCard(context),
              const SizedBox(width: 12),
              _buildWatchAdCard(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _checkDailyLogin() async {
    setState(() => _isLoading = true);
    
    try {
      final points = await SupabaseService.checkDailyStreak();
      await _loadData(); // Reload to show new streak/points
      
      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking in: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildEarnCard({
    required IconData icon,
    required Color color,
    required String title,
    required String points,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              points,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBettingCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to VS tab (index 2 in bottom navigation)
        DefaultTabController.of(context).animateTo(2);
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00FF41), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF41).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.casino,
              color: Color(0xFF00FF41),
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bet Points',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
              const Text(
                'Win 2x',
                style: TextStyle(
                  color: Color(0xFF00FF41),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoTeaser() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF41), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF41).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.currency_bitcoin, color: Color(0xFF00FF41), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'WEB3',
                      style: TextStyle(
                        color: Color(0xFF00FF41),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'READY',
                      style: TextStyle(
                        color: Color(0xFFFF0000),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                      ),
                      child: const Text(
                        'COMING SOON',
                        style: TextStyle(
                          color: Color(0xFF00FF41),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Crypto Conversion',
                  style: TextStyle(
                    color: Color(0xFF00FF41),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your points will be convertible to tokens for real value, rewards, and DAO governance.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ledger History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF41),
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Full transaction history coming soon!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              final amount = (tx['amount'] as num).toDouble();
              final isPositive = amount > 0;
              final date = DateTime.parse(tx['created_at'] as String);
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isPositive ? const Color(0xFF00FF41) : Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx['description'] ?? tx['transaction_type'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.month}/${date.day} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}$amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isPositive ? const Color(0xFF00FF41) : Colors.red.shade700,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildWatchAdCard() {
    final adService = RewardedAdService.instance;
    final bool isReady = adService.isAdReady;
    final bool isLoading = adService.isLoading;

    return GestureDetector(
      onTap: isReady ? _showRewardedAd : null,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isReady ? const Color(0xFF00FF41) : Theme.of(context).dividerColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00FF41),
                      ),
                    )
                  : Icon(
                      Icons.play_circle_filled,
                      color: isReady ? const Color(0xFF00FF41) : Colors.grey,
                      size: 24,
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Watch Ad',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '+4.2',
              style: TextStyle(
                color: isReady ? const Color(0xFF00FF41) : Colors.grey,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRewardedAd() async {
    final adService = RewardedAdService.instance;
    
    if (!adService.isAdReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad not ready yet, please wait...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await adService.showAd();
    
    // Reload data to show new points
    await _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Earned 4 points!'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
