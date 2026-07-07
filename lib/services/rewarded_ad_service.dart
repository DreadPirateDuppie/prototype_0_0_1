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

  // AdMob rewarded ad unit IDs. The compiled-in defaults are Google's public
  // TEST ad unit IDs (safe to ship — they never earn real revenue). To go
  // live, pass DPD's real production unit IDs at build time, e.g.:
  //   flutter build apk \
  //     --dart-define=ADMOB_REWARDED_AD_UNIT_ID_ANDROID=ca-app-pub-XXXXXXXX/YYYYYYYYYY \
  //     --dart-define=ADMOB_REWARDED_AD_UNIT_ID_IOS=ca-app-pub-XXXXXXXX/ZZZZZZZZZZ
  // Get the real values from: AdMob console -> Apps -> (Pushinn) -> Ad units
  // -> Rewarded -> copy the "Ad unit ID" for each platform.
  static const String _androidAdUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_AD_UNIT_ID_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917', // Google test ID
  );
  static const String _iosAdUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_AD_UNIT_ID_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313', // Google test ID
  );

  final String _adUnitId = Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId;

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

  /// Show the rewarded ad. Points are granted ONLY when [onUserEarnedReward]
  /// actually fires — i.e. the user watched through to the reward point.
  /// Per AdMob's Rewarded Ads policy, the reward must never be granted just
  /// because the ad launched, was shown, or was dismissed early; repeated
  /// violations risk AdMob account suspension. The returned future resolves
  /// to whether the reward was earned, which is not the same thing as
  /// whether the ad was merely shown or dismissed.
  Future<bool> showAd() async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('Rewarded ad not ready');
      return false;
    }

    final Completer<bool> completer = Completer<bool>();
    bool rewardEarned = false;

    // Handle ad show/dismissal/failure. The completer only resolves once the
    // ad is done (dismissed or failed) so its value reflects the *final*
    // outcome — whether the reward was actually earned before that point.
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Rewarded ad showed full screen content.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Rewarded ad dismissed (reward earned: $rewardEarned).');
        if (!completer.isCompleted) completer.complete(rewardEarned);
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

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');

        final user = SupabaseService.getCurrentUser();
        if (user != null) {
          // Fire-and-forget: the reward is real at this point, so this must
          // not block the ad SDK's dismissal flow.
          SupabaseService.awardPoints(
            user.id,
            4.2, // 4.2 points per ad
            'ad_watch',
            description: 'Watched rewarded video ad to completion',
          ).then((_) {
            debugPrint('Awarded 4.2 points for completed ad watch');
          }).catchError((e) {
            debugPrint('Error awarding points for ad watch: $e');
          });
        }
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
