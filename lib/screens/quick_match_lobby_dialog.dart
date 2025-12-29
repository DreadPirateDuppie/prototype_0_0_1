import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../config/theme_config.dart';
import '../utils/error_helper.dart';

class QuickMatchLobbyDialog extends StatefulWidget {
  const QuickMatchLobbyDialog({super.key});

  @override
  State<QuickMatchLobbyDialog> createState() => _QuickMatchLobbyDialogState();
}

class _QuickMatchLobbyDialogState extends State<QuickMatchLobbyDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  Timer? _timer;
  Timer? _matchmakingTimer;
  int _secondsWaiting = 0;
  bool _isSearching = true;
  bool _matchFound = false;
  bool _isSearchingStarted = false; // New state to track if search has started
  
  GameMode _selectedMode = GameMode.skate;
  bool _isQuickfire = true;
  int _betAmount = 0;
  int _userPoints = 0;
  double _myRankingScore = 500.0;
  int _playersInQueue = 0;
  
  RealtimeChannel? _queueSubscription;
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadUserData();
    // Removed immediate queue join and timer starts
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _matchmakingTimer?.cancel();
    if (_isSearchingStarted) {
      _leaveQueue();
    }
    _queueSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final points = await SupabaseService.getUserPoints(_userId);
      final scores = await BattleService.getUserScores(_userId);
      final count = await BattleService.getQueueCount();
      
      if (mounted) {
        setState(() {
          _userPoints = points.toInt();
          _myRankingScore = scores.rankingScore;
          _playersInQueue = count;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _startSearch() {
    setState(() {
      _isSearchingStarted = true;
      _secondsWaiting = 0;
    });
    _startTimers();
    _joinQueue();
    _subscribeToQueue();
  }

  void _startTimers() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsWaiting++;
        });
        
        // Timeout at 4:20 (260 seconds)
        if (_secondsWaiting >= 260) {
          _onTimeout();
        }
      }
    });

    // Matchmaking logic every 5 seconds
    _matchmakingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isSearching && !_matchFound) {
        _attemptMatchmaking();
      }
    });
  }

  Future<void> _joinQueue() async {
    try {
      await BattleService.joinMatchmakingQueue(
        gameMode: _selectedMode,
        isQuickfire: _isQuickfire,
        betAmount: _betAmount,
      );
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to join queue: $e');
        setState(() => _isSearchingStarted = false);
      }
    }
  }

  Future<void> _leaveQueue() async {
    if (!_matchFound) {
      await BattleService.leaveMatchmakingQueue();
    }
  }

  void _subscribeToQueue() {
    _queueSubscription = BattleService.subscribeToQueueUpdates(_userId, (payload) {
      if (mounted && payload['status'] == 'matched' && !_matchFound) {
        _onMatchFound(payload['matched_with'], payload['battle_id']);
      }
    });
  }

  Future<void> _attemptMatchmaking() async {
    // Expand range by 50 every 10 seconds, starting at 100
    final expandedRange = 100 + ((_secondsWaiting / 10).floor() * 50);
    
    final match = await BattleService.findMatch(
      myRankingScore: _myRankingScore,
      gameMode: _selectedMode.toString().split('.').last,
      isQuickfire: _isQuickfire,
      betAmount: _betAmount,
      expandedRange: expandedRange,
    );

    if (match != null && mounted) {
      _initiateMatch(match['user_id']);
    }
  }

  Future<void> _initiateMatch(String opponentId) async {
    setState(() {
      _isSearching = false;
      _matchFound = true;
    });

    try {
      final battle = await BattleService.createBattleFromMatch(
        opponentId: opponentId,
        gameMode: _selectedMode,
        isQuickfire: _isQuickfire,
        betAmount: _betAmount,
      );

      if (battle != null && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = true;
          _matchFound = false;
        });
        ErrorHelper.showError(context, 'Failed to create battle: $e');
      }
    }
  }

  void _onMatchFound(String? opponentId, String? battleId) {
    setState(() {
      _isSearching = false;
      _matchFound = true;
    });
    
    // Wait a moment for the battle to be fully ready
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  void _onTimeout() {
    _timer?.cancel();
    _matchmakingTimer?.cancel();
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: ThemeColors.surfaceDark,
          title: const Text('NO MATCH FOUND', style: TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace')),
          content: const Text('We couldn\'t find a similar skilled player right now. Try again or change your settings.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close alert
                _stopSearch(); // Go back to settings
              },
              child: const Text('BACK TO SETTINGS', style: TextStyle(color: ThemeColors.matrixGreen)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close alert
                setState(() {
                  _secondsWaiting = 0;
                  _startTimers();
                  _joinQueue();
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: ThemeColors.matrixGreen, foregroundColor: Colors.black),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _getRankTier(double score) {
    if (score < 300) return 'ROOKIE';
    if (score < 500) return 'AMATEUR';
    if (score < 700) return 'PRO';
    if (score < 900) return 'ELITE';
    return 'LEGEND';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: ThemeColors.backgroundDark,
      child: Stack(
        children: [
          // Background Grid
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                color: ThemeColors.matrixGreen.withValues(alpha: 0.03),
              ),
            ),
          ),
          
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    ThemeColors.matrixGreen.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        if (_isSearchingStarted) ...[
                          _buildSearchingAnimation(),
                          const SizedBox(height: 40),
                          _buildStatusInfo(),
                        ] else ...[
                          _buildSettingsHeader(),
                        ],
                        const SizedBox(height: 40),
                        _buildSettingsCard(),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomActions(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ThemeColors.matrixGreen.withValues(alpha: 0.1)),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text(
              '>',
              style: TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              _isSearchingStarted ? 'QUICK_MATCH_SEARCH' : 'QUICK_MATCH_SETUP',
              style: const TextStyle(
                color: ThemeColors.matrixGreen,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_isSearchingStarted)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ThemeColors.matrixGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: ThemeColors.matrixGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_playersInQueue ONLINE',
                        style: const TextStyle(
                          color: ThemeColors.matrixGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
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

  Widget _buildSettingsHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Animated outer ring
            RotationTransition(
              turns: _pulseController,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
            ),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ThemeColors.matrixGreen.withValues(alpha: 0.2),
                    ThemeColors.matrixGreen.withValues(alpha: 0.05),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.bolt, color: ThemeColors.matrixGreen, size: 35),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'CONFIGURE BATTLE',
          style: TextStyle(
            color: ThemeColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your preferences for the next match',
          style: TextStyle(
            color: ThemeColors.textSecondary.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingAnimation() {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Radar Rings
              ...List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final progress = (_pulseController.value + (index * 0.33)) % 1.0;
                    return Container(
                      width: 200 * progress,
                      height: 200 * progress,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ThemeColors.matrixGreen.withValues(alpha: (1.0 - progress) * 0.3),
                          width: 2,
                        ),
                      ),
                    );
                  },
                );
              }),
              
              // Scanning Line
              RotationTransition(
                turns: _pulseController,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        ThemeColors.matrixGreen.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Center Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThemeColors.backgroundDark,
                  border: Border.all(color: ThemeColors.matrixGreen, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _matchFound ? Icons.check_circle : Icons.radar,
                    color: ThemeColors.matrixGreen,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _matchFound ? 'MATCH FOUND!' : 'SCANNING FOR OPPONENTS...',
          style: const TextStyle(
            color: ThemeColors.matrixGreen,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: ThemeColors.matrixGreen.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeColors.matrixGreen.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('ELAPSED', _formatTime(_secondsWaiting), Icons.timer_outlined),
          Container(width: 1, height: 30, color: ThemeColors.matrixGreen.withValues(alpha: 0.1)),
          _buildStatItem('RANK', _getRankTier(_myRankingScore), Icons.military_tech),
          Container(width: 1, height: 30, color: ThemeColors.matrixGreen.withValues(alpha: 0.1)),
          _buildStatItem('SCORE', _myRankingScore.toInt().toString(), Icons.analytics_outlined),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: ThemeColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ThemeColors.matrixGreen, size: 14),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: ThemeColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ThemeColors.surfaceDark.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ThemeColors.matrixGreen.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: ThemeColors.matrixGreen.withValues(alpha: 0.7), size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'MATCH PARAMETERS',
                    style: TextStyle(
                      color: ThemeColors.matrixGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSettingRow(
                'Game Mode',
                'Select the battle format',
                DropdownButtonHideUnderline(
                  child: DropdownButton<GameMode>(
                    value: _selectedMode,
                    dropdownColor: ThemeColors.surfaceDark,
                    icon: const Icon(Icons.keyboard_arrow_down, color: ThemeColors.matrixGreen),
                    style: const TextStyle(color: ThemeColors.matrixGreen, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    items: GameMode.values.where((m) => m != GameMode.custom).map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(mode.toString().split('.').last.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (_matchFound || _isSearchingStarted) ? null : (value) {
                      setState(() => _selectedMode = value!);
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10, height: 1),
              ),
              _buildSettingRow(
                'Quick-Fire',
                'Fast-paced 4:20 turns',
                Switch.adaptive(
                  value: _isQuickfire,
                  activeThumbColor: ThemeColors.matrixGreen,
                  activeTrackColor: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                  onChanged: (_matchFound || _isSearchingStarted) ? null : (value) {
                    setState(() => _isQuickfire = value);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10, height: 1),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wager Amount',
                            style: TextStyle(color: ThemeColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Points at stake',
                            style: TextStyle(color: ThemeColors.textSecondary.withValues(alpha: 0.5), fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_betAmount PTS',
                          style: const TextStyle(
                            color: ThemeColors.matrixGreen,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      activeTrackColor: ThemeColors.matrixGreen,
                      inactiveTrackColor: ThemeColors.matrixGreen.withValues(alpha: 0.1),
                      thumbColor: ThemeColors.matrixGreen,
                      overlayColor: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      value: _betAmount.toDouble(),
                      min: 0,
                      max: _userPoints.toDouble() > 1000 ? 1000 : _userPoints.toDouble(),
                      divisions: 10,
                      onChanged: (_matchFound || _isSearchingStarted) ? null : (value) {
                        setState(() => _betAmount = value.toInt());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(String title, String subtitle, Widget trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: ThemeColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: ThemeColors.textSecondary.withValues(alpha: 0.5), fontSize: 12),
            ),
          ],
        ),
        trailing,
      ],
    );
  }

  void _stopSearch() {
    _timer?.cancel();
    _matchmakingTimer?.cancel();
    _leaveQueue();
    _queueSubscription?.unsubscribe();
    setState(() {
      _isSearchingStarted = false;
      _secondsWaiting = 0;
    });
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: ThemeColors.backgroundDark,
        border: Border(top: BorderSide(color: ThemeColors.matrixGreen.withValues(alpha: 0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isSearchingStarted) ...[
            _buildStartButton(),
            const SizedBox(height: 12),
          ],
          _buildCancelButton(),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [ThemeColors.matrixGreen, Color(0xFF00CC33)],
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _startSearch,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Text(
              'INITIATE SEARCH',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          if (_isSearchingStarted) {
            _stopSearch();
          } else {
            Navigator.pop(context);
          }
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: (_isSearchingStarted ? ThemeColors.error : ThemeColors.textSecondary).withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          _isSearchingStarted ? 'ABORT SEARCH' : 'DISMISS',
          style: TextStyle(
            color: _isSearchingStarted ? ThemeColors.error : ThemeColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;

  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 30.0;

    for (var i = 0.0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (var i = 0.0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
