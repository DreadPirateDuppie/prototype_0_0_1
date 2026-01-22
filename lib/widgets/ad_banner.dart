import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  final int initialIndex;
  const AdBanner({super.key, this.initialIndex = 0});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _adSize;
  
  // Fallback banner state
  late int _currentAdIndex;
  Timer? _adTimer;

  // Test Ad Unit IDs
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-7811826984903792/5751991911'
      : 'ca-app-pub-3940256099942544/2934735716';

  final List<Map<String, dynamic>> _advertisements = [
    {
      'icon': Icons.star_rounded,
      'title': 'Remove Ads',
      'subtitle': 'Sign up to Premium to remove ads',
      'color': Colors.amber,
      'action': 'Upgrade',
    },
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  @override
  void initState() {
    super.initState();
    _currentAdIndex = widget.initialIndex % _advertisements.length;
    _startAdRotation();
  }

  void _startAdRotation() {
    _adTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentAdIndex = (_currentAdIndex + 1) % _advertisements.length;
        });
      }
    });
  }

  Future<void> _loadAd() async {
    // Get the screen width to create an adaptive banner
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) {
      // Fallback to standard banner if adaptive fails
      _createBannerAd(AdSize.banner);
      return;
    }

    _createBannerAd(size);
  }

  void _createBannerAd(AdSize size) {
    if (_bannerAd != null) {
      _bannerAd!.dispose();
    }

    setState(() {
      _adSize = size;
    });

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _adTimer?.cancel();
    super.dispose();
  }

  Widget _buildFallbackBanner() {
    final currentAd = _advertisements[_currentAdIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(_currentAdIndex),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              // ignore: deprecated_member_use
              (currentAd['color'] as Color).withValues(alpha: 0.1),
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]!
                  : Colors.grey[200]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]!
                  : Colors.grey[300]!,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ad tapped: ${currentAd['title']}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    currentAd['icon'] as IconData,
                    size: 28,
                    color: currentAd['color'] as Color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentAd['title'] as String,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentAd['subtitle'] as String,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (currentAd['color'] as Color).withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentAd['color'] as Color,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      currentAd['action'] as String,
                      style: TextStyle(
                        color: currentAd['color'] as Color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null && _adSize != null) {
      return SizedBox(
        width: _adSize!.width.toDouble(),
        height: _adSize!.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    
    // Show fallback banner while loading or if failed
    return _buildFallbackBanner();
  }
}
