import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'supabase_service.dart';

class RewardedAdService {
  static RewardedAdService? _instance;
  static RewardedAdService get instance {
    _instance ??= RewardedAdService._();
    return _instance!;
  }

  RewardedAdService._();

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  // Test Ad Unit IDs for rewarded ads
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Android test ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS test ID

  bool get isAdReady => _isAdLoaded;
  bool get isLoading => _isLoading;

  /// Initialize and load the first rewarded ad
  Future<void> initialize() async {
    await loadAd();
  }

  /// Load a rewarded ad
  Future<void> loadAd() async {
    if (_isLoading) return;
    
    _isLoading = true;
    
    await RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded ad loaded.');
          _rewardedAd = ad;
          _isAdLoaded = true;
          _isLoading = false;
          _setupAdCallbacks();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isAdLoaded = false;
          _isLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  void _setupAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Rewarded ad showed full screen content.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Rewarded ad dismissed.');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        // Load the next ad
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadAd();
      },
    );
  }

  /// Show the rewarded ad and award points on completion
  Future<bool> showAd() async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('Rewarded ad not ready');
      return false;
    }

    bool rewardEarned = false;

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        rewardEarned = true;
        
        // Award points to the user
        try {
          final user = SupabaseService.getCurrentUser();
          if (user != null) {
            await SupabaseService.awardPoints(
              user.id,
              4.2, // 4.2 points per ad
              'ad_watch',
              description: 'Watched rewarded video ad',
            );
            debugPrint('Awarded 4.2 points for watching ad');
          }
        } catch (e) {
          debugPrint('Error awarding points: $e');
        }
      },
    );

    return rewardEarned;
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
  }
}
