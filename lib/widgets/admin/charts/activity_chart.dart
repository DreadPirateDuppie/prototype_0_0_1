import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:prototype_0_0_1/config/theme_config.dart';

class ActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> primaryData; // e.g. Post Stats
  final List<Map<String, dynamic>> secondaryData; // e.g. User Growth
  final String primaryLabel;
  final String secondaryLabel;
  final Color primaryColor;
  final Color secondaryColor;

  const ActivityChart({
    super.key,
    required this.primaryData,
    required this.secondaryData,
    this.primaryLabel = 'POSTS',
    this.secondaryLabel = 'USERS',
    this.primaryColor = ThemeColors.matrixGreen,
    this.secondaryColor = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVITY_LOG [30D]',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              Row(
                children: [
                  _LegendItem(color: primaryColor, label: primaryLabel),
                  const SizedBox(width: 16),
                  _LegendItem(color: secondaryColor, label: secondaryLabel),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 10,
                  verticalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            'D${value.toInt()}',
                            style: const TextStyle(
                              color: Colors.white24,
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.white24,
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.left,
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                minX: 0,
                maxX: 30,
                minY: 0,
                // Calculate nice MaxY based on data
                maxY: _calculateMaxY(),
                lineBarsData: [
                  _buildLine(primaryData, primaryColor),
                  _buildLine(secondaryData, secondaryColor),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black.withValues(alpha: 0.8),
                    tooltipBorder: BorderSide(color: Colors.white24),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final textStyle = TextStyle(
                          color: touchedSpot.bar.color,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        );
                        return LineTooltipItem(
                          '${touchedSpot.barIndex == 0 ? primaryLabel : secondaryLabel}: ${touchedSpot.y.toInt()}',
                          textStyle,
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMaxY() {
    double max = 10;
    for (var d in primaryData) {
      final val = (d['count'] as num?)?.toDouble() ?? 0;
      if (val > max) max = val;
    }
    for (var d in secondaryData) {
      final val = (d['count'] as num?)?.toDouble() ?? 0;
      if (val > max) max = val;
    }
    return (max * 1.2).ceilToDouble(); // Add 20% padding
  }

  LineChartBarData _buildLine(List<Map<String, dynamic>> data, Color color) {
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
        // Map data index 0-29 to X axis
        spots.add(FlSpot(i.toDouble(), (data[i]['count'] as num?)?.toDouble() ?? 0));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2, // Cyberpunk often has sharper lines, but smooth is nice for analytics
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
