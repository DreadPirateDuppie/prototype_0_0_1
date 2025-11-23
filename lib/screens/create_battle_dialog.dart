import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';

class CreateBattleDialog extends StatefulWidget {
  const CreateBattleDialog({super.key});

  @override
  State<CreateBattleDialog> createState() => _CreateBattleDialogState();
}

class _CreateBattleDialogState extends State<CreateBattleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _opponentIdController = TextEditingController();
  final _customLettersController = TextEditingController();
  final _wagerController = TextEditingController();
  GameMode _selectedMode = GameMode.skate;
  bool _isLoading = false;
  int _userBalance = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserBalance();
  }

  Future<void> _fetchUserBalance() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final balance = await SupabaseService.getUserPoints(user.id);
      if (mounted) {
        setState(() {
          _userBalance = balance;
        });
      }
    }
  }

  @override
  void dispose() {
    _opponentIdController.dispose();
    _customLettersController.dispose();
    _wagerController.dispose();
    super.dispose();
  }

  Future<void> _createBattle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final customLetters = _selectedMode == GameMode.custom
          ? _customLettersController.text.toUpperCase()
          : '';

      final wagerAmount = int.tryParse(_wagerController.text) ?? 0;

      await BattleService.createBattle(
        player1Id: currentUser.id,
        player2Id: _opponentIdController.text.trim(),
        gameMode: _selectedMode,
        customLetters: customLetters,
        wagerAmount: wagerAmount,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Battle created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating battle: $e')));
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
    return AlertDialog(
      title: const Text('Create New Battle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Game Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<GameMode>(
                initialValue: _selectedMode,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
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
                  decoration: const InputDecoration(
                    labelText: 'Custom Letters',
                    hintText: 'e.g., TRICK',
                    border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Opponent User ID',
                  hintText: 'Enter opponent\'s user ID',
                  border: OutlineInputBorder(),
                  helperText: 'You need to know your opponent\'s user ID',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter opponent user ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Wager Input
              Text(
                'Wager Points (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _wagerController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0',
                  border: const OutlineInputBorder(),
                  suffixText: 'Points',
                  helperText: 'Available: $_userBalance Points',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final amount = int.tryParse(value);
                  if (amount == null) return 'Invalid number';
                  if (amount < 0) return 'Cannot be negative';
                  if (amount > _userBalance) return 'Insufficient points';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Winner takes all! (2x Wager)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: In a future update, you\'ll be able to search for opponents by username.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createBattle,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
