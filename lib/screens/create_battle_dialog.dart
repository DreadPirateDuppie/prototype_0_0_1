import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

class CreateBattleDialog extends StatefulWidget {
  const CreateBattleDialog({super.key});

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
  double _betAmount = 0;
  bool _isQuickfire = false;

  @override
  void initState() {
    super.initState();
    _loadUserPoints();
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

  Future<void> _createBattle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final opponentId = _opponentIdController.text.trim();
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
      title: const Text(
        'CREATE NEW BATTLE',
        style: TextStyle(
          color: matrixGreen,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Game Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: matrixGreen.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<GameMode>(
                initialValue: _selectedMode,
                dropdownColor: matrixBlack,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen.withOpacity(0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen.withOpacity(0.5)),
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
                    labelStyle: TextStyle(color: matrixGreen.withOpacity(0.7)),
                    hintText: 'e.g., TRICK',
                    hintStyle: TextStyle(color: matrixGreen.withOpacity(0.3)),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen.withOpacity(0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: matrixGreen.withOpacity(0.5)),
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

              TextFormField(
                controller: _opponentIdController,
                style: const TextStyle(color: matrixGreen),
                decoration: InputDecoration(
                  labelText: 'Opponent User ID',
                  labelStyle: TextStyle(color: matrixGreen.withOpacity(0.7)),
                  hintText: 'Enter opponent\'s user ID',
                  hintStyle: TextStyle(color: matrixGreen.withOpacity(0.3)),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen.withOpacity(0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: matrixGreen, width: 2),
                  ),
                  helperText: 'You need to know your opponent\'s user ID',
                  helperStyle: TextStyle(color: matrixGreen.withOpacity(0.5)),
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
                  color: matrixGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: matrixGreen.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Balance',
                      style: TextStyle(
                        color: matrixGreen.withOpacity(0.7),
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
                  color: matrixGreen.withOpacity(0.8),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: matrixGreen,
                  inactiveTrackColor: matrixGreen.withOpacity(0.2),
                  thumbColor: matrixGreen,
                  overlayColor: matrixGreen.withOpacity(0.2),
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
                  max: _userPoints.toDouble(),
                  divisions: _userPoints > 0 ? _userPoints : 1,
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
                    ? 'Winner takes ${(_betAmount * 2).toInt()} PTS (both players bet ${_betAmount.toInt()} PTS)'
                    : 'No bet - just for fun!',
                style: TextStyle(
                  fontSize: 11,
                  color: matrixGreen.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Quick-fire mode toggle
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isQuickfire 
                      ? matrixGreen.withOpacity(0.15)
                      : matrixGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isQuickfire 
                        ? matrixGreen 
                        : matrixGreen.withOpacity(0.2),
                    width: _isQuickfire ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flash_on,
                      color: _isQuickfire 
                          ? matrixGreen 
                          : matrixGreen.withOpacity(0.5),
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
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isQuickfire 
                                ? '4:20 timer per turn'
                                : '24 hour timer per turn',
                            style: TextStyle(
                              color: matrixGreen.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isQuickfire,
                      activeColor: matrixGreen,
                      activeTrackColor: matrixGreen.withOpacity(0.5),
                      inactiveThumbColor: matrixGreen.withOpacity(0.5),
                      inactiveTrackColor: matrixGreen.withOpacity(0.2),
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
              Text(
                'Note: In a future update, you\'ll be able to search for opponents by username.',
                style: TextStyle(
                  fontSize: 12,
                  color: matrixGreen.withOpacity(0.5),
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
              color: matrixGreen.withOpacity(0.7),
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
                color: matrixGreen.withOpacity(0.3),
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
