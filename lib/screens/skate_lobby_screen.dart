import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class SkateLobbyScreen extends StatefulWidget {
  final String lobbyId;

  const SkateLobbyScreen({
    super.key,
    required this.lobbyId,
  });

  @override
  State<SkateLobbyScreen> createState() => _SkateLobbyScreenState();
}

class _SkateLobbyScreenState extends State<SkateLobbyScreen> {
  static const Color matrixGreen = Color(0xFF00FF41);
  static const Color matrixBlack = Color(0xFF000000);
  static const Color matrixDark = Color(0xFF0A0A0A);

  Map<String, dynamic>? _lobby;
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _events = [];
  String? _currentUserId;
  StreamSubscription? _lobbySub;
  StreamSubscription? _playersSub;
  StreamSubscription? _eventsSub;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUserId = SupabaseService.getCurrentUser()?.id;
    _initStreams();
  }

  void _initStreams() {
    // Stream Lobby Details
    _lobbySub = SupabaseService.streamLobby(widget.lobbyId).listen((data) {
      if (mounted) setState(() => _lobby = data);
    });

    // Stream Players
    _playersSub = SupabaseService.streamLobbyPlayers(widget.lobbyId).listen((data) async {
      // Fetch profiles for these players
      if (data.isEmpty) return;
      
      // Note: In a real app we might want to optimize this to not fetch profiles every update
      // But for prototype it's fine.
      // We need to merge the 'letters' from lobby_players with profile data
      
      // For now, let's just use the IDs to fetch profiles if we can't do a join
      // Actually, let's just do a periodic fetch or fetch once on load and then just update letters?
      // Simpler: Just fetch all profiles for these IDs
      
      // We'll just display what we have for now, improving later if needed.
      // Wait, we need usernames.
      
      // Let's do a quick fetch of profiles
      // Let's do a quick fetch of profiles
      // We need a way to get profiles by IDs. 
      // SupabaseService doesn't have a direct method exposed for bulk fetch by IDs easily accessible here without custom query
      // Let's add a helper or just use what we have.
      
      // Hack: We'll just store the raw data and maybe fetch profiles one by one or rely on a future update
      // Actually, let's just use the stream data for now and maybe we can get display names from a separate call
      
      // BETTER: Let's just update the local state.
      if (mounted) {
        setState(() {
          _players = data;
        });
      }
    });

    // Stream Events
    _eventsSub = SupabaseService.streamLobbyEvents(widget.lobbyId).listen((data) {
      if (mounted) {
        setState(() {
          _events = data;
        });
        // Scroll to bottom of chat/log
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // Reverse list
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _lobbySub?.cancel();
    _playersSub?.cancel();
    _eventsSub?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _leaveLobby() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: matrixDark,
        title: const Text('Leave Lobby?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to leave this game?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.leaveLobby(widget.lobbyId);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _updateLetters(String letters) async {
    try {
      await SupabaseService.updatePlayerLetters(widget.lobbyId, letters);
    } catch (e) {
      if (mounted) ErrorHelper.showError(context, 'Failed to update score');
    }
  }

  Future<void> _sendEvent(String type, String data) async {
    try {
      await SupabaseService.sendLobbyEvent(widget.lobbyId, type, data);
    } catch (e) {
      // Ignore
    }
  }

  void _showSetTrickDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: matrixDark,
        title: const Text('Set Trick', style: TextStyle(color: matrixGreen)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Kickflip',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: matrixGreen)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _sendEvent('set', controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: matrixGreen, foregroundColor: matrixBlack),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lobby == null) {
      return const Scaffold(
        backgroundColor: matrixBlack,
        body: Center(child: CircularProgressIndicator(color: matrixGreen)),
      );
    }

    final code = _lobby!['code'];

    return Scaffold(
      backgroundColor: matrixBlack,
      appBar: AppBar(
        backgroundColor: matrixBlack,
        title: Text(
          'LOBBY: $code',
          style: const TextStyle(
            color: matrixGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: _leaveLobby,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: matrixGreen),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lobby code copied!')),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: matrixGreen.withValues(alpha: 0.3), height: 1),
        ),
      ),
      body: Column(
        children: [
          // Scoreboard
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _players.length,
              itemBuilder: (context, index) {
                final player = _players[index];
                final userId = player['user_id'];
                final isMe = userId == _currentUserId;
                final letters = player['letters'] as String? ?? '';
                
                return FutureBuilder<String?>(
                  future: SupabaseService.getUserDisplayName(userId),
                  builder: (context, snapshot) {
                    final name = snapshot.data ?? 'Loading...';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isMe ? matrixGreen.withValues(alpha: 0.1) : matrixDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMe ? matrixGreen : Colors.white10,
                          width: isMe ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: isMe ? matrixGreen : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (player['is_host'] == true) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSkateLetters(letters),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Event Log / Chat
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: matrixDark,
              border: Border(
                top: BorderSide(color: matrixGreen.withValues(alpha: 0.3)),
                bottom: BorderSide(color: matrixGreen.withValues(alpha: 0.3)),
              ),
            ),
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                final type = event['event_type'];
                final data = event['data'];
                
                return FutureBuilder<String?>(
                  future: SupabaseService.getUserDisplayName(event['user_id']),
                  builder: (context, snapshot) {
                    final name = snapshot.data ?? '...';
                    String message = '';
                    Color color = Colors.white70;

                    switch (type) {
                      case 'set':
                        message = 'set $data';
                        color = Colors.amber;
                        break;
                      case 'miss':
                        message = 'missed ($data)';
                        color = Colors.redAccent;
                        break;
                      case 'land':
                        message = 'landed it!';
                        color = matrixGreen;
                        break;
                      case 'join':
                        message = 'joined the lobby';
                        color = Colors.blueAccent;
                        break;
                      case 'leave':
                        message = 'left the lobby';
                        color = Colors.grey;
                        break;
                      default:
                        message = data;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          children: [
                            TextSpan(
                              text: '$name ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            TextSpan(
                              text: message,
                              style: TextStyle(color: color),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showSetTrickDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('SET TRICK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Add a letter
                      final myPlayer = _players.firstWhere((p) => p['user_id'] == _currentUserId);
                      String currentLetters = myPlayer['letters'] ?? '';
                      const fullWord = 'SKATE';
                      
                      if (currentLetters.length < fullWord.length) {
                        final nextLetter = fullWord[currentLetters.length];
                        final newLetters = currentLetters + nextLetter;
                        await _updateLetters(newLetters);
                        await _sendEvent('miss', nextLetter);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('MISS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendEvent('land', ''),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: matrixGreen,
                      foregroundColor: matrixBlack,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('LAND', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkateLetters(String currentLetters) {
    const word = 'SKATE';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(word.length, (index) {
        final letter = word[index];
        final hasLetter = index < currentLetters.length;
        
        return Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasLetter ? Colors.red.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(
              color: hasLetter ? Colors.red : Colors.white10,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            letter,
            style: TextStyle(
              color: hasLetter ? Colors.red : Colors.white10,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        );
      }),
    );
  }
}
