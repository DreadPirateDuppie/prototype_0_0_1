import 'package:flutter/material.dart';

class RewardsStreakCard extends StatelessWidget {
  final int streak;
  final bool hasCheckedInToday;
  final bool isLoading;
  final VoidCallback onCheckIn;

  const RewardsStreakCard({
    super.key,
    required this.streak,
    required this.hasCheckedInToday,
    required this.isLoading,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Streak',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00FF41),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep the fire burning!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF41).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Color(0xFF00FF41), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '$streak Days',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00FF41),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Check In Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasCheckedInToday ? null : onCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: hasCheckedInToday ? 0 : 4,
                shadowColor: const Color(0xFF00FF41).withValues(alpha: 0.4),
              ),
              child: isLoading 
                  ? const SizedBox(
                      height: 20, 
                      width: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(hasCheckedInToday ? Icons.check_circle : Icons.touch_app),
                        const SizedBox(width: 8),
                        Text(
                          hasCheckedInToday ? 'CHECKED IN TODAY' : 'CHECK IN NOW',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final activeCount = streak == 0 ? 0 : ((streak - 1) % 7) + 1;
              final isActive = index < activeCount;
              
              const matrixGreen = Color(0xFF00FF41);
              
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive 
                          ? matrixGreen.withValues(alpha: 0.2)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? matrixGreen : matrixGreen.withValues(alpha: 0.2),
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: matrixGreen.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ] : null,
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      size: 20,
                      color: isActive ? matrixGreen : matrixGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Day ${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? matrixGreen : matrixGreen.withValues(alpha: 0.5),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
