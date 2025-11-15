import 'dart:async';
import 'package:flutter/material.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  int _currentAdIndex = 0;
  Timer? _adTimer;

  final List<Map<String, dynamic>> _advertisements = [
    {
      'icon': Icons.local_offer,
      'title': 'Special Offer!',
      'subtitle': 'Discover amazing spots in your area',
      'color': Colors.deepPurple,
      'action': 'Learn More',
    },
    {
      'icon': Icons.star,
      'title': 'Premium Features',
      'subtitle': 'Unlock exclusive content and rewards',
      'color': Colors.amber,
      'action': 'Upgrade',
    },
    {
      'icon': Icons.explore,
      'title': 'Explore More',
      'subtitle': 'Find hidden gems near you',
      'color': Colors.teal,
      'action': 'Discover',
    },
    {
      'icon': Icons.people,
      'title': 'Join Community',
      'subtitle': 'Connect with local explorers',
      'color': Colors.blue,
      'action': 'Connect',
    },
    {
      'icon': Icons.trending_up,
      'title': 'Popular Today',
      'subtitle': 'Check out trending locations',
      'color': Colors.orange,
      'action': 'View',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAdRotation();
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
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
              (currentAd['color'] as Color).withOpacity(0.1),
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
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
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
                      color: (currentAd['color'] as Color).withOpacity(0.2),
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
                  const SizedBox(width: 8),
                  // Indicator dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _advertisements.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentAdIndex
                              ? currentAd['color'] as Color
                              : Colors.grey[400],
                        ),
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
}
