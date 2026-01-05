import 'package:flutter/material.dart';
import '../../services/rewarded_ad_service.dart';

class RewardsEarnSection extends StatelessWidget {
  final VoidCallback onWatchAd;

  const RewardsEarnSection({
    super.key,
    required this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ways to Earn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00FF41),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _buildEarnCard(
                context,
                icon: Icons.add_location_alt,
                color: const Color(0xFF00FF41),
                title: 'Create Spot',
                points: '+3.5',
              ),
              const SizedBox(width: 12),
              _buildWatchAdCard(context),
              const SizedBox(width: 12),
              _buildEarnCard(
                context,
                icon: Icons.sports_kabaddi,
                color: const Color(0xFF00FF41),
                title: 'Win Battle',
                points: 'Win Pot',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEarnCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String points,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              points,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchAdCard(BuildContext context) {
    final adService = RewardedAdService.instance;
    final bool isReady = adService.isAdReady;
    final bool isLoading = adService.isLoading;

    return GestureDetector(
      onTap: isReady ? onWatchAd : null,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isReady ? const Color(0xFF00FF41) : Theme.of(context).dividerColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00FF41),
                      ),
                    )
                  : Icon(
                      Icons.play_circle_filled,
                      color: isReady ? const Color(0xFF00FF41) : Colors.grey,
                      size: 24,
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Watch Ad',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '+4.2',
              style: TextStyle(
                color: Color(0xFF00FF41),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
