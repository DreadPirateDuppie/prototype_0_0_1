import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'supabase_service.dart';

class RewardedAdService extends ChangeNotifier {
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
    notifyListeners();
    
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
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isAdLoaded = false;
          _isLoading = false;
          _rewardedAd = null;
          notifyListeners();
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

  /// Show the rewarded ad and award points on launch (instant reward)
  Future<bool> showAd() async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('Rewarded ad not ready');
      return false;
    }

    final Completer<bool> completer = Completer<bool>();
    
    // Award points IMMEDIATELY on launch to ensure user gets them even if they "skip" or close the app
    try {
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        // Fire and forget/wait briefly to ensure it hits the network
        SupabaseService.awardPoints(
          user.id,
          4.2, // 4.2 points per ad
          'ad_watch',
          description: 'Watched rewarded video ad (Instant Award)',
        ).then((_) {
          debugPrint('Awarded 4.2 points for launching ad');
        }).catchError((e) {
          debugPrint('Error awarding points on launch: $e');
        });
      }
    } catch (e) {
      debugPrint('Pre-show award failed: $e');
    }

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('User earned reward callback triggered (already awarded on launch)');
      },
    );

    // Also handle ad dismissal & failures
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Rewarded ad showed full screen content.');
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Rewarded ad dismissed.');
        if (!completer.isCompleted) completer.complete(true); // Still true because awarded on launch
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: $error');
        if (!completer.isCompleted) completer.complete(false);
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        loadAd();
      },
    );

    return completer.future;
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    super.dispose();
  }
}
