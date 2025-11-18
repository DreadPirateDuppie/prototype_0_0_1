import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../screens/battle_detail_screen.dart';
import '../screens/create_battle_dialog.dart';

class VsTab extends StatefulWidget {
  const VsTab({super.key});

  @override
  State<VsTab> createState() => _VsTabState();
}

class _VsTabState extends State<VsTab> {
  List<Battle> _battles = [];
  bool _isLoading = true;
  final _currentUser = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadBattles();
  }

  Future<void> _loadBattles() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final battles = await BattleService.getActiveBattles(_currentUser.id);
      setState(() {
        _battles = battles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading battles: $e')),
        );
      }
    }
  }

  String _getGameModeDisplay(GameMode mode) {
    switch (mode) {
      case GameMode.skate:
        return 'SKATE';
      case GameMode.sk8:
        return 'SK8';
      case GameMode.custom:
        return 'Custom';
    }
  }

  Widget _buildBattleCard(Battle battle) {
    final isPlayer1 = battle.player1Id == _currentUser?.id;
    final opponentId = isPlayer1 ? battle.player2Id : battle.player1Id;
    final myLetters = isPlayer1 ? battle.player1Letters : battle.player2Letters;
    final opponentLetters = isPlayer1 ? battle.player2Letters : battle.player1Letters;
    final isMyTurn = battle.currentTurnPlayerId == _currentUser?.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMyTurn ? Colors.green : Colors.grey,
          child: Icon(
            isMyTurn ? Icons.play_arrow : Icons.pause,
            color: Colors.white,
          ),
        ),
        title: Text(_getGameModeDisplay(battle.gameMode)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('You: $myLetters / ${battle.getGameLetters()}'),
            Text('Opponent: $opponentLetters / ${battle.getGameLetters()}'),
            const SizedBox(height: 4),
            Text(
              isMyTurn ? 'Your turn' : "Opponent's turn",
              style: TextStyle(
                color: isMyTurn ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BattleDetailScreen(battle: battle),
            ),
          );
          _loadBattles(); // Refresh on return
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VS Battles'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _battles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_kabaddi,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No active battles',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a new battle to compete!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBattles,
                  child: ListView.builder(
                    itemCount: _battles.length,
                    itemBuilder: (context, index) {
                      return _buildBattleCard(_battles[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const CreateBattleDialog(),
          );
          if (result == true) {
            _loadBattles();
          }
        },
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add),
        label: const Text('New Battle'),
      ),
    );
  }
}
