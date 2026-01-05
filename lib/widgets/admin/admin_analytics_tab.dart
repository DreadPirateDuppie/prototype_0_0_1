import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype_0_0_1/config/theme_config.dart';
import '../../providers/admin_provider.dart';
import 'charts/activity_chart.dart';
import 'charts/retention_heatmap.dart';

class AdminAnalyticsTab extends StatelessWidget {
  const AdminAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.stats.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen));
        }

        return RefreshIndicator(
          onRefresh: provider.loadAllData,
          color: ThemeColors.matrixGreen,
          backgroundColor: Colors.black,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. High-Level KPI Cards
              Row(
                children: [
                  Expanded(
                    child: _TrendCard(
                      label: 'TOTAL NODES',
                      value: provider.stats['total_users']?.toString() ?? '0',
                      trend: _calculateTrend(provider.userGrowthStats),
                      icon: Icons.people_outline,
                      color: ThemeColors.matrixGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _TrendCard(
                      label: 'DATA FLOW',
                      value: provider.stats['total_posts']?.toString() ?? '0',
                      trend: _calculateTrend(provider.dailyPostStats),
                      icon: Icons.hub_outlined,
                      color: const Color(0xFF00E5FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TrendCard(
                      label: 'STICKINESS',
                      value: '${(provider.stickinessRatio['ratio'] as num).toStringAsFixed(1)}%',
                      trend: 0.0, // TODO: History for stickiness
                      icon: Icons.layers,
                      color: Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _TrendCard(
                      label: 'TTV [HOURS]',
                      value: provider.timeToValue.toStringAsFixed(1),
                      trend: 0.0,
                      icon: Icons.timer_outlined,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Activity Chart
              ActivityChart(
                primaryData: provider.dailyPostStats,
                secondaryData: provider.userGrowthStats,
              ),
              const SizedBox(height: 24),

              // 3. Retention Heatmap
              RetentionHeatmap(cohortData: provider.cohortRetention),
              const SizedBox(height: 24),

              // 4. At-Risk Users
              if (provider.atRiskUsers.isNotEmpty) ...[
                const Text(
                  'AT_RISK_NODES [>50% DROP]',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: provider.atRiskUsers.map((user) {
                      return ListTile(
                        leading: const Icon(Icons.warning, color: Colors.orange, size: 16),
                        title: Text(
                          user['username'] ?? 'UNKNOWN', 
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                        ),
                        trailing: Text(
                          '-${(user['drop_pct'] as num).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 5. Operational Metrics
              _CyberMetricCard(
                label: 'SECURITY_FLAGS',
                value: provider.stats['pending_reports']?.toString() ?? '0',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFF3D00), // Cyber Orange
                delay: 200,
              ),
              const SizedBox(height: 16),
              // Add more operational tiles here if needed like "Server Status", "API Latency" etc.
            ],
          ),
        );
      },
    );
  }

  double _calculateTrend(List<Map<String, dynamic>> stats) {
    if (stats.length < 2) return 0.0;
    // Compare last day (stats.last) with average of previous 7 days or just previous day
    // Let's do simple previous day check
    final current = (stats.last['count'] as num?)?.toDouble() ?? 0;
    final previous = (stats[stats.length - 2]['count'] as num?)?.toDouble() ?? 0;
    
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }
}

class _TrendCard extends StatelessWidget {
  final String label;
  final String value;
  final double trend;
  final IconData icon;
  final Color color;

  const _TrendCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = trend >= 0;
    final trendColor = isPositive ? ThemeColors.matrixGreen : Colors.redAccent;
    final trendIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color.withValues(alpha: 0.8), size: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(trendIcon, color: trendColor, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      '${trend.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: trendColor,
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberMetricCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int delay;

  const _CyberMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delay = 0,
  });

  @override
  State<_CyberMetricCard> createState() => _CyberMetricCardState();
}

class _CyberMetricCardState extends State<_CyberMetricCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * (1.0 - (widget.delay > 0 ? 0 : 1))), // Only slide if initial
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Background Grid
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(
                      color: widget.color.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                
                // Corner Hackers
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CyberCornerPainter(
                      color: widget.color,
                      opacity: _pulseAnimation.value,
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(
                                widget.icon, 
                                color: widget.color.withValues(alpha: 0.8), 
                                size: 16
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '> ${widget.label}',
                                style: TextStyle(
                                  color: widget.color,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.value,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: widget.color.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Decorative Right Side
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           _buildStatusLight(),
                           Icon(
                             Icons.qr_code_2, 
                             color: widget.color.withValues(alpha: 0.2), 
                             size: 40
                           ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusLight() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color,
            blurRadius: 5 * _pulseAnimation.value + 2,
            spreadRadius: 2 * _pulseAnimation.value,
          ),
        ],
      ),
    );
  }
}

class _CyberCornerPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _CyberCornerPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double cornerSize = 15.0;

    // Top Left
    canvas.drawLine(const Offset(0, 0), Offset(cornerSize, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerSize), paint);

    // Top Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerSize, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerSize), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerSize, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerSize), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerSize, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerSize), paint);
    
    // Scanline decorative (optional, keeps it subtle)
    final scanlinePaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
      
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.8, 0), scanlinePaint);
    canvas.drawLine(Offset(size.width * 0.7, size.height), Offset(size.width * 0.8, size.height), scanlinePaint);
  }

  @override
  bool shouldRepaint(covariant _CyberCornerPainter oldDelegate) {
    return opacity != oldDelegate.opacity || color != oldDelegate.color;
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const double gridSize = 20;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
