import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class CreateBattleDialog extends StatefulWidget {
  final String? prefilledOpponentId;
  final bool isQuickMatch;

  const CreateBattleDialog({
    super.key,
    this.prefilledOpponentId,
    this.isQuickMatch = false,
  });

  @override
  State<CreateBattleDialog> createState() => _CreateBattleDialogState();
}

class _CreateBattleDialogState extends State<CreateBattleDialog> {
  final _formKey = GlobalKey<FormState>();
  GameMode _selectedMode = GameMode.skate;
  final _customLettersController = TextEditingController();
  final _opponentIdController = TextEditingController();
  final _wagerController = TextEditingController();
  bool _isLoading = false;
  int _userPoints = 0;
  int _opponentPoints = 0;
  double _betAmount = 0;
  bool _isQuickfire = false;
  List<Map<String, dynamic>> _mutualFollowers = [];
  bool _isLoadingFollowers = true;
  String? _selectedMutualFollowerId;

  @override
  void initState() {
    super.initState();
    _loadUserPoints();
    _loadMutualFollowers();
    
    if (widget.prefilledOpponentId != null) {
      _opponentIdController.text = widget.prefilledOpponentId!;
      // If quick match, default to quickfire for faster games
      if (widget.isQuickMatch) {
        _isQuickfire = true;
      }
    }
  }

  @override
  void dispose() {
    _customLettersController.dispose();
    _opponentIdController.dispose();
    _wagerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPoints() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final points = await SupabaseService.getUserPoints(userId);
      if (mounted) {
        setState(() {
          _userPoints = points.toInt();
        });
      }
    }
  }

  Future<void> _loadOpponentPoints(String opponentId) async {
    try {
      final points = await SupabaseService.getUserPoints(opponentId);
      if (mounted) {
        setState(() {
          _opponentPoints = points.toInt();
          // Reset bet if it exceeds new limit
          final maxBet = _getMaxBet();
          if (_betAmount > maxBet) {
            _betAmount = maxBet.toDouble();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _opponentPoints = 0;
          _betAmount = 0;
        });
      }
    }
  }

  int _getMaxBet() {
    if (_opponentPoints > 0 && _userPoints > 0) {
      return _userPoints < _opponentPoints ? _userPoints : _opponentPoints;
    }
    return _userPoints;
  }

  Future<void> _loadMutualFollowers() async {
    try {
      final followers = await SupabaseService.getMutualFollowers();
      if (mounted) {
        setState(() {
          _mutualFollowers = followers;
          _isLoadingFollowers = false;
          
          // If prefilled ID matches a mutual follower, select it in dropdown
          if (widget.prefilledOpponentId != null) {
            final match = followers.where((f) => f['id'] == widget.prefilledOpponentId);
            if (match.isNotEmpty) {
              _selectedMutualFollowerId = widget.prefilledOpponentId;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFollowers = false;
        });
      }
    }
  }

  Future<void> _createBattle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      // Use selected mutual follower ID if available, otherwise use text input
      final opponentId = _selectedMutualFollowerId ?? _opponentIdController.text.trim();
      final wagerAmount = int.tryParse(_wagerController.text) ?? 0;

      await BattleService.createBattle(
        player1Id: userId,
        player2Id: opponentId,
        gameMode: _selectedMode,
        customLetters: _selectedMode == GameMode.custom
            ? _customLettersController.text.toUpperCase()
            : null,
        wagerAmount: wagerAmount,
        betAmount: _betAmount.toInt(),
        isQuickfire: _isQuickfire,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Battle created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error creating battle: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    
    return AlertDialog(
      backgroundColor: matrixBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: matrixGreen, width: 2),
      ),
      title: Text(
        widget.isQuickMatch ? 'QUICK MATCH FOUND!' : 'CREATE NEW BATTLE',
        style: TextStyle(
          color: matrixGreen,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: widget.isQuickMatch ? 18 : 20,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isQuickMatch) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Opponent found! Configure your game settings below.',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Text(
                'Game Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: matrixGreen.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<GameMode>(
                initialValue: _selectedMode,
                dropdownColor: matrixBlack,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(color: matrixGreen),
                items: const [
                  DropdownMenuItem(
                    value: GameMode.skate,
                    child: Text('SKATE (S-K-A-T-E)'),
                  ),
                  DropdownMenuItem(
                    value: GameMode.sk8,
                    child: Text('SK8 (S-K-8)'),
                  ),
                  DropdownMenuItem(
                    value: GameMode.custom,
                    child: Text('Custom Letters'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMode = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_selectedMode == GameMode.custom) ...[
                TextFormField(
                  controller: _customLettersController,
                  style: const TextStyle(color: matrixGreen),
                  decoration: InputDecoration(
                    labelText: 'Custom Letters',
                    labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                    hintText: 'e.g., TRICK',
                    hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.3)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen, width: 2),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter custom letters';
                    }
                    if (value.length < 2 || value.length > 10) {
                      return 'Letters must be 2-10 characters';
                    }
                    if (!RegExp(r'^[A-Za-z]+$').hasMatch(value)) {
                      return 'Only letters allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Opponent Selection
              if (_mutualFollowers.isNotEmpty && !widget.isQuickMatch) ...[
                Text(
                  'Select Opponent',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: matrixGreen.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedMutualFollowerId,
                  dropdownColor: matrixBlack,
                  decoration: InputDecoration(
                    labelText: 'Mutual Followers',
                    labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: matrixGreen),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Enter User ID manually...'),
                    ),
                    ..._mutualFollowers.map((user) {
                      final name = user['display_name'] ?? user['username'] ?? 'User';
                      return DropdownMenuItem<String>(
                        value: user['id'] as String,
                        child: Text(name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMutualFollowerId = value;
                      if (value != null) {
                        _opponentIdController.text = value;
                        _loadOpponentPoints(value);
                      } else {
                        _opponentIdController.clear();
                        _opponentPoints = 0;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Manual ID Entry (only show if no mutual follower selected)
              if (_selectedMutualFollowerId == null || widget.isQuickMatch)
                TextFormField(
                  controller: _opponentIdController,
                  style: const TextStyle(color: matrixGreen),
                  readOnly: widget.isQuickMatch, // Lock if quick match
                  decoration: InputDecoration(
                    labelText: 'Opponent User ID',
                    labelStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.7)),
                    hintText: 'Enter opponent\'s user ID',
                    hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.3)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen, width: 2),
                    ),
                    helperText: widget.isQuickMatch 
                        ? 'Opponent automatically selected'
                        : 'You need to know your opponent\'s user ID',
                    helperStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.5)),
                    suffixIcon: widget.isQuickMatch 
                        ? const Icon(Icons.lock, color: matrixGreen, size: 16)
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter opponent user ID';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 16),
              
              // Points balance display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: matrixGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Balance',
                      style: TextStyle(
                        color: matrixGreen.withValues(alpha: 0.7),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$_userPoints PTS',
                      style: const TextStyle(
                        color: matrixGreen,
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Bet amount slider
              Text(
                'Bet Amount: ${_betAmount.toInt()} PTS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: matrixGreen.withValues(alpha: 0.8),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: matrixGreen,
                  inactiveTrackColor: matrixGreen.withValues(alpha: 0.2),
                  thumbColor: matrixGreen,
                  overlayColor: matrixGreen.withValues(alpha: 0.2),
                  valueIndicatorColor: matrixGreen,
                  valueIndicatorTextStyle: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Slider(
                  value: _betAmount,
                  min: 0,
                  max: _getMaxBet().toDouble(),
                  divisions: _getMaxBet() > 0 ? _getMaxBet() : 1,
                  label: _betAmount.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      _betAmount = value;
                    });
                  },
                ),
              ),
              Text(
                _betAmount > 0 
                    ? 'Winner gets ${_betAmount.toInt()} PTS back'
                    : 'No bet - just for fun!',
                style: TextStyle(
                  fontSize: 11,
                  color: matrixGreen.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Quick-fire mode toggle
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isQuickfire 
                      ? matrixGreen.withValues(alpha: 0.15)
                      : matrixGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isQuickfire 
                        ? matrixGreen 
                        : matrixGreen.withValues(alpha: 0.2),
                    width: _isQuickfire ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flash_on,
                      color: _isQuickfire 
                          ? matrixGreen 
                          : matrixGreen.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick-Fire Mode',
                            style: TextStyle(
                              color: matrixGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isQuickfire 
                                ? '4:20 timer per turn'
                                : '24 hour timer per turn',
                            style: TextStyle(
                              color: matrixGreen.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isQuickfire,
                      activeThumbColor: matrixGreen,
                      activeTrackColor: matrixGreen.withValues(alpha: 0.5),
                      inactiveThumbColor: matrixGreen.withValues(alpha: 0.5),
                      inactiveTrackColor: matrixGreen.withValues(alpha: 0.2),
                      onChanged: (value) {
                        setState(() {
                          _isQuickfire = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (!widget.isQuickMatch)
                Text(
                  'Note: In a future update, you\'ll be able to search for opponents by username.',
                  style: TextStyle(
                    fontSize: 12,
                    color: matrixGreen.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: matrixGreen.withValues(alpha: 0.7),
              fontFamily: 'monospace',
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: matrixGreen, width: 2),
            boxShadow: [
              BoxShadow(
                color: matrixGreen.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createBattle,
            style: ElevatedButton.styleFrom(
              backgroundColor: matrixBlack,
              foregroundColor: matrixGreen,
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: matrixGreen,
                    ),
                  )
                : const Text(
                    'CREATE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
