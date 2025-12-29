import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class BattleLeaderboardScreen extends StatefulWidget {
  const BattleLeaderboardScreen({super.key});

  @override
  State<BattleLeaderboardScreen> createState() => _BattleLeaderboardScreenState();
}

class _BattleLeaderboardScreenState extends State<BattleLeaderboardScreen> {
  final _currentUser = Supabase.instance.client.auth.currentUser;
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  static const Color matrixGreen = Color(0xFF00FF41);
  static const Color matrixBlack = Color(0xFF000000);
  static const Color matrixDark = Color(0xFF0A0A0A);
  static const Color goldColor = Color(0xFFFFD700);
  static const Color silverColor = Color(0xFFC0C0C0);
  static const Color bronzeColor = Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      setState(() => _isLoading = true);
      final leaderboard = await SupabaseService.getTopBattlePlayers(limit: 50);
      if (mounted) {
        setState(() {
          _leaderboard = leaderboard;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: matrixBlack,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events,
              color: goldColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'LEADERBOARD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: matrixBlack,
        foregroundColor: goldColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  goldColor.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: matrixGreen,
                strokeWidth: 3,
              ),
            )
          : _leaderboard.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_kabaddi,
                        color: matrixGreen.withValues(alpha: 0.3),
                        size: 80,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No battles completed yet',
                        style: TextStyle(
                          color: matrixGreen.withValues(alpha: 0.5),
                          fontSize: 18,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Be the first to win!',
                        style: TextStyle(
                          color: matrixGreen.withValues(alpha: 0.3),
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: matrixGreen,
                  backgroundColor: matrixBlack,
                  onRefresh: _loadLeaderboard,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _leaderboard.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: matrixGreen.withValues(alpha: 0.1),
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final player = _leaderboard[index];
                      final rank = index + 1;
                      final isCurrentUser = player['user_id'] == _currentUser?.id;
                      
                      Color rankColor = matrixGreen;
                      if (rank == 1) {
                        rankColor = goldColor;
                      } else if (rank == 2) {
                        rankColor = silverColor;
                      } else if (rank == 3) {
                        rankColor = bronzeColor;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              matrixDark,
                              matrixBlack,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrentUser
                                ? matrixGreen
                                : matrixGreen.withValues(alpha: 0.2),
                            width: isCurrentUser ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Rank Badge
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: rank <= 3
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            rankColor.withValues(alpha: 0.3),
                                            rankColor.withValues(alpha: 0.1),
                                          ],
                                        )
                                      : null,
                                  color: rank > 3 ? rankColor.withValues(alpha: 0.2) : null,
                                  border: Border.all(
                                    color: rankColor,
                                    width: 2,
                                  ),
                                  boxShadow: rank <= 3
                                      ? [
                                          BoxShadow(
                                            color: rankColor.withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '$rank',
                                    style: TextStyle(
                                      color: rankColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Avatar
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: matrixGreen.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: player['avatar_url'] != null
                                      ? Image.network(
                                          player['avatar_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.person,
                                              color: matrixGreen.withValues(alpha: 0.5),
                                              size: 28,
                                            );
                                          },
                                        )
                                      : Icon(
                                          Icons.person,
                                          color: matrixGreen.withValues(alpha: 0.5),
                                          size: 28,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Player Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            player['username'] ?? 'Unknown',
                                            style: TextStyle(
                                              color: isCurrentUser ? matrixGreen : Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: matrixGreen.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: matrixGreen.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Text(
                                              'YOU',
                                              style: TextStyle(
                                                color: matrixGreen,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          '${player['total_battles']} battles',
                                          style: TextStyle(
                                            color: matrixGreen.withValues(alpha: 0.5),
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Stats
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${player['wins']}W-${player['losses']}L',
                                    style: const TextStyle(
                                      color: matrixGreen,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: matrixGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: matrixGreen.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${player['win_percentage'].toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: matrixGreen,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
