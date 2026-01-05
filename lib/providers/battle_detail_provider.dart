import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle.dart';
import '../services/battle_service.dart';
import '../services/supabase_service.dart';
import '../services/messaging_service.dart';
import 'dart:developer' as developer;

class BattleDetailProvider extends ChangeNotifier {
  Battle? _battle;
  bool _isLoading = true;
  bool _isTutorial = false;
  bool _isPlayer1 = false;
  bool _isMyTurn = false;
  bool _isRefreshing = false;
  
  String? _player1Name;
  String? _player1Avatar;
  String? _player2Name;
  String? _player2Avatar;
  
  Map<String, dynamic>? _player1Analytics;
  Map<String, dynamic>? _player2Analytics;
  
  RealtimeChannel? _battleSubscription;
  Timer? _refreshTimer;

  // Getters
  Battle? get battle => _battle;
  bool get isLoading => _isLoading;
  bool get isTutorial => _isTutorial;
  bool get isPlayer1 => _isPlayer1;
  bool get isMyTurn => _isMyTurn;
  bool get isRefreshing => _isRefreshing;
  
  String? get player1Name => _player1Name;
  String? get player1Avatar => _player1Avatar;
  String? get player2Name => _player2Name;
  String? get player2Avatar => _player2Avatar;
  
  Map<String, dynamic>? get player1Analytics => _player1Analytics;
  Map<String, dynamic>? get player2Analytics => _player2Analytics;

  void setTutorial(bool value) {
    _isTutorial = value;
    notifyListeners();
  }

  Future<void> initialize(String? battleId, Battle? initialBattle, {bool tutorialMode = false}) async {
    _isTutorial = tutorialMode;
    
    if (initialBattle != null) {
      _initBattle(initialBattle);
    } else if (battleId != null) {
      await loadBattle(battleId);
    }
    
    if (battleId != null) {
      _subscribeToBattle(battleId);
    }
    
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _battleSubscription?.unsubscribe();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners(); // Trigger rebuild for countdowns

      if (_battle != null && !_isLoading && !_isRefreshing) {
        try {
          final remaining = _battle!.getRemainingTime();
          if (remaining != null && remaining.inSeconds <= 0) {
            refreshBattle();
          }
        } catch (e) {
          developer.log('Error in refresh timer: $e');
        }
      }
    });
  }

  Future<void> refreshBattle() async {
    if (_battle == null || _isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await BattleService.checkExpiredTurns(userId);
      } catch (e) {
        developer.log('Error checking expired turns: $e');
      }
    }

    await loadBattle(_battle!.id!);
    _isRefreshing = false;
    notifyListeners();
  }

  void _subscribeToBattle(String battleId) {
    _battleSubscription?.unsubscribe();
    _battleSubscription = Supabase.instance.client
        .channel('public:battles:id=eq.$battleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'battles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: battleId,
          ),
          callback: (payload) {
            final updatedBattle = Battle.fromMap(payload.newRecord);
            _initBattle(updatedBattle);
          },
        )
        .subscribe();
  }

  Future<void> loadBattle(String battleId) async {
    try {
      final battle = await BattleService.getBattle(battleId);
      if (battle != null) {
        _initBattle(battle);
      }
    } catch (e) {
      developer.log('Error loading battle: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void _initBattle(Battle battle) {
    _battle = battle;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _isPlayer1 = _battle!.player1Id == userId;
    _isMyTurn = _battle!.currentTurnPlayerId == userId;
    _isLoading = false;
    notifyListeners();
    _loadPlayerProfiles();
  }

  Future<void> _loadPlayerProfiles() async {
    if (_battle == null) return;
    try {
      _player1Name = await SupabaseService.getUserUsername(_battle!.player1Id);
      _player1Avatar = await SupabaseService.getUserAvatarUrl(_battle!.player1Id);
      _player2Name = await SupabaseService.getUserUsername(_battle!.player2Id);
      _player2Avatar = await SupabaseService.getUserAvatarUrl(_battle!.player2Id);

      _player1Analytics = await BattleService.getUserAnalytics(_battle!.player1Id);
      _player2Analytics = await BattleService.getUserAnalytics(_battle!.player2Id);
      
      notifyListeners();
    } catch (e) {
      developer.log('Error loading player profiles: $e');
    }
  }

  Future<void> uploadSetTrick(File videoFile, String? trickName) async {
    if (_battle == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final videoUrl = await BattleService.uploadTrickVideo(
        videoFile,
        _battle!.id!,
        userId,
        'set',
      );

      final updatedBattle = await BattleService.uploadSetTrick(
        battleId: _battle!.id!,
        videoUrl: videoUrl,
        trickName: trickName,
      );

      if (updatedBattle != null) {
        _initBattle(updatedBattle);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> uploadAttempt(File videoFile) async {
    if (_battle == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final videoUrl = await BattleService.uploadTrickVideo(
        videoFile,
        _battle!.id!,
        userId,
        'attempt',
      );

      final updatedBattle = await BattleService.uploadAttempt(
        battleId: _battle!.id!,
        videoUrl: videoUrl,
      );

      if (updatedBattle != null) {
        _initBattle(updatedBattle);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> forfeitBattle() async {
    if (_battle == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await BattleService.forfeitBattle(
        battleId: _battle!.id!,
        forfeitingUserId: userId,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> forfeitTurn() async {
    if (_battle == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final updatedBattle = await BattleService.forfeitTurn(
        battleId: _battle!.id!,
        playerId: userId,
      );
      
      if (updatedBattle != null) {
        _initBattle(updatedBattle);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitVote(String vote) async {
    if (_battle == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await BattleService.submitVote(
        battleId: _battle!.id!,
        userId: userId,
        vote: vote,
      );
      
      await loadBattle(_battle!.id!);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitRpsMove(String move) async {
    if (_battle == null) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // Optimistic update
      if (_battle!.player1Id == userId) {
        _battle = _battle!.copyWith(player1RpsMove: move);
      } else {
        _battle = _battle!.copyWith(player2RpsMove: move);
      }
      notifyListeners();

      await BattleService.submitRpsMove(
        battleId: _battle!.id!,
        userId: userId,
        move: move,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> acceptBet() async {
    if (_battle == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await BattleService.acceptBet(
        battleId: _battle!.id!,
        opponentId: userId,
        betAmount: _battle!.betAmount,
      );
      await loadBattle(_battle!.id!);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> getOrCreateConversation() async {
    if (_battle == null) return null;
    return await MessagingService.getOrCreateBattleConversation(
      _battle!.id!,
      [_battle!.player1Id, _battle!.player2Id],
    );
  }
}
