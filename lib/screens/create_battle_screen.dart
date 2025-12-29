import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../config/theme_config.dart';
import '../utils/error_helper.dart';

class CreateBattleScreen extends StatefulWidget {
  final String? prefilledOpponentId;

  const CreateBattleScreen({
    super.key,
    this.prefilledOpponentId,
  });

  @override
  State<CreateBattleScreen> createState() => _CreateBattleScreenState();
}

class _CreateBattleScreenState extends State<CreateBattleScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final _formKey = GlobalKey<FormState>();
  
  GameMode _selectedMode = GameMode.skate;
  final _customLettersController = TextEditingController();
  final _opponentIdController = TextEditingController();
  final _wagerController = TextEditingController();
  
  bool _isLoading = false;
  int _userPoints = 0;
  int _opponentPoints = 0;
  int _betAmount = 0;
  bool _isQuickfire = false;
  
  List<Map<String, dynamic>> _mutualFollowers = [];
  String? _selectedMutualFollowerId;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _selectedUserId;
  
  final String _myUserId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadUserPoints();
    _loadMutualFollowers();
    
    if (widget.prefilledOpponentId != null) {
      _opponentIdController.text = widget.prefilledOpponentId!;
      _selectedUserId = widget.prefilledOpponentId;
      _loadOpponentPoints(widget.prefilledOpponentId!);
    }
    
    _opponentIdController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _customLettersController.dispose();
    _opponentIdController.removeListener(_onUsernameChanged);
    _opponentIdController.dispose();
    _wagerController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() async {
    final query = _opponentIdController.text.trim();
    
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _selectedUserId = null;
          _isSearching = false;
        });
      }
      return;
    }
    
    // Debounce
    await Future.delayed(const Duration(milliseconds: 500));
    if (query != _opponentIdController.text.trim()) return;
    
    if (!mounted) return;
    
    setState(() => _isSearching = true);
    
    try {
      final searchQuery = query.startsWith('@') ? query.substring(1) : query;
      final results = await SupabaseService.searchUsers(searchQuery);
      
      if (mounted) {
        setState(() {
          _searchResults = results.where((u) => u['id'] != _myUserId).toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _loadUserPoints() async {
    try {
      final points = await SupabaseService.getUserPoints(_myUserId);
      if (mounted) {
        setState(() => _userPoints = points.toInt());
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _loadOpponentPoints(String opponentId) async {
    try {
      final points = await SupabaseService.getUserPoints(opponentId);
      if (mounted) {
        setState(() {
          _opponentPoints = points.toInt();
          final maxBet = _getMaxBet();
          if (_betAmount > maxBet) _betAmount = maxBet;
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
          if (widget.prefilledOpponentId != null) {
            final match = followers.where((f) => f['id'] == widget.prefilledOpponentId);
            if (match.isNotEmpty) {
              _selectedMutualFollowerId = widget.prefilledOpponentId;
            }
          }
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _createBattle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null && _selectedMutualFollowerId == null) {
      ErrorHelper.showError(context, 'Please select an opponent from the list');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final opponentId = _selectedMutualFollowerId ?? _selectedUserId!;
      final wagerAmount = int.tryParse(_wagerController.text) ?? 0;

      await BattleService.createBattle(
        player1Id: _myUserId,
        player2Id: opponentId,
        gameMode: _selectedMode,
        customLetters: _selectedMode == GameMode.custom
            ? _customLettersController.text.toUpperCase()
            : null,
        wagerAmount: wagerAmount,
        betAmount: _betAmount,
        isQuickfire: _isQuickfire,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Error creating battle: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.backgroundDark,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background Grid
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(color: ThemeColors.matrixGreen.withValues(alpha: 0.03)),
            ),
          ),
          
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),

          Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(),
                        const SizedBox(height: 32),
                        
                        _buildSectionLabel('BATTLE CONFIGURATION'),
                        const SizedBox(height: 12),
                        _buildGlassRow(
                          icon: Icons.sports_esports,
                          label: 'Game Mode',
                          trailing: _buildGameModeDropdown(),
                        ),
                        if (_selectedMode == GameMode.custom) ...[
                          const SizedBox(height: 12),
                          _buildGlassField(
                            controller: _customLettersController,
                            label: 'Custom Letters',
                            hint: 'e.g., TRICK',
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        _buildSectionLabel('OPPONENT'),
                        const SizedBox(height: 12),
                        if (_mutualFollowers.isNotEmpty) ...[
                          _buildGlassRow(
                            icon: Icons.people,
                            label: 'Mutual Friend',
                            trailing: _buildMutualFollowerDropdown(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildSearchField(),
                        if (_searchResults.isNotEmpty) _buildSearchResults(),
                        
                        const SizedBox(height: 24),
                        _buildSectionLabel('STAKES & RULES'),
                        const SizedBox(height: 12),
                        _buildBetCard(),
                        const SizedBox(height: 12),
                        _buildGlassRow(
                          icon: Icons.flash_on,
                          label: 'Quick-Fire Mode',
                          subtitle: _isQuickfire ? '4:20 per turn' : '24h per turn',
                          trailing: Switch.adaptive(
                            value: _isQuickfire,
                            activeThumbColor: ThemeColors.matrixGreen,
                            activeTrackColor: ThemeColors.matrixGreen.withValues(alpha: 0.3),
                            onChanged: (v) => setState(() => _isQuickfire = v),
                          ),
                        ),
                        
                        const SizedBox(height: 120), // Space for bottom actions
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Bottom Actions with Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ThemeColors.matrixGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '> BATTLE_INITIATION',
          style: TextStyle(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ThemeColors.matrixGreen.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: ThemeColors.matrixGreen.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.security, color: ThemeColors.matrixGreen, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'ESTABLISH CONNECTION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildGlassRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required Widget trailing,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(icon, color: ThemeColors.matrixGreen.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    if (subtitle != null)
                      Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace'),
            validator: validator,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1), fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameModeDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<GameMode>(
        value: _selectedMode,
        dropdownColor: ThemeColors.surfaceDark,
        icon: const Icon(Icons.keyboard_arrow_down, color: ThemeColors.matrixGreen, size: 20),
        style: const TextStyle(color: ThemeColors.matrixGreen, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        items: [
          DropdownMenuItem(value: GameMode.skate, child: const Text('SKATE')),
          DropdownMenuItem(value: GameMode.sk8, child: const Text('SK8')),
          DropdownMenuItem(value: GameMode.custom, child: const Text('CUSTOM')),
        ],
        onChanged: (value) => setState(() => _selectedMode = value!),
      ),
    );
  }

  Widget _buildMutualFollowerDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedMutualFollowerId,
        dropdownColor: ThemeColors.surfaceDark,
        hint: const Text('Select Friend', style: TextStyle(color: Colors.white24, fontSize: 12)),
        icon: const Icon(Icons.keyboard_arrow_down, color: ThemeColors.matrixGreen, size: 20),
        style: const TextStyle(color: ThemeColors.matrixGreen, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        items: [
          const DropdownMenuItem(value: null, child: Text('NONE')),
          ..._mutualFollowers.map((user) {
            return DropdownMenuItem(
              value: user['id'] as String,
              child: Text((user['display_name'] ?? user['username'] ?? 'User').toString().toUpperCase()),
            );
          }),
        ],
        onChanged: (value) {
          setState(() {
            _selectedMutualFollowerId = value;
            if (value != null) {
              _opponentIdController.text = _mutualFollowers.firstWhere((f) => f['id'] == value)['username'] ?? '';
              _selectedUserId = value;
              _loadOpponentPoints(value);
            }
          });
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return _buildGlassField(
      controller: _opponentIdController,
      label: 'Search Opponent',
      hint: 'Enter username...',
      suffixIcon: _isSearching 
          ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: ThemeColors.matrixGreen)))
          : const Icon(Icons.search, color: ThemeColors.matrixGreen, size: 20),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeColors.matrixGreen.withValues(alpha: 0.1)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          return ListTile(
            dense: true,
            title: Text('@${user['username']}', style: const TextStyle(color: ThemeColors.matrixGreen, fontWeight: FontWeight.bold)),
            subtitle: Text(user['display_name'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            onTap: () {
              setState(() {
                _opponentIdController.text = user['username'];
                _selectedUserId = user['id'];
                _searchResults = [];
                _loadOpponentPoints(user['id']);
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildBetCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Wager Points', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('$_betAmount PTS', style: const TextStyle(color: ThemeColors.matrixGreen, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  activeTrackColor: ThemeColors.matrixGreen,
                  inactiveTrackColor: Colors.white10,
                  thumbColor: ThemeColors.matrixGreen,
                  overlayColor: ThemeColors.matrixGreen.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: _betAmount.toDouble(),
                  min: 0,
                  max: _getMaxBet().toDouble() > 1000 ? 1000 : _getMaxBet().toDouble(),
                  divisions: 10,
                  onChanged: (value) => setState(() => _betAmount = value.toInt()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Balance: $_userPoints', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                  Text('Opponent: $_opponentPoints', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ThemeColors.backgroundDark.withValues(alpha: 0.0),
            ThemeColors.backgroundDark.withValues(alpha: 0.9),
            ThemeColors.backgroundDark,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCreateButton(),
          const SizedBox(height: 12),
          _buildCancelButton(),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
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
            color: ThemeColors.matrixGreen.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _createBattle,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                : const Text(
                    'INITIATE BATTLE',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      fontSize: 16,
                      letterSpacing: 2,
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
      height: 50,
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          'ABORT MISSION',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1,
            fontSize: 12,
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
    final paint = Paint()..color = color..strokeWidth = 1;
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
