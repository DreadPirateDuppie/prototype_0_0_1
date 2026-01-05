import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prototype_0_0_1/config/theme_config.dart';

class RetentionHeatmap extends StatelessWidget {
  final List<Map<String, dynamic>> cohortData;

  const RetentionHeatmap({super.key, required this.cohortData});

  @override
  Widget build(BuildContext context) {
    if (cohortData.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: const Text(
          'NO_COHORT_DATA',
          style: TextStyle(color: Colors.white24, fontFamily: 'monospace'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RETENTION_MATRIX [COHORTS]',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(50),
              children: [
                // Header Row
                TableRow(
                  children: [
                    const SizedBox(width: 80, child: Text('COHORT', style: TextStyle(color: Colors.white54, fontSize: 10))),
                    const SizedBox(width: 40, child: Text('SIZE', style: TextStyle(color: Colors.white54, fontSize: 10))),
                    ...List.generate(7, (i) => Center(child: Text('M$i', style: const TextStyle(color: Colors.white54, fontSize: 10)))),
                  ],
                ),
                const TableRow(children: [SizedBox(height: 8), SizedBox(), SizedBox(), SizedBox(), SizedBox(), SizedBox(), SizedBox(), SizedBox(), SizedBox()]),
                
                // Data Rows
                ...cohortData.map((cohort) {
                  final date = DateTime.parse(cohort['cohort_month'] as String);
                  final size = cohort['cohort_size'] as int;
                  final percentages = [
                    (cohort['month_0'] as num).toDouble(),
                    (cohort['month_1'] as num).toDouble(),
                    (cohort['month_2'] as num).toDouble(),
                    (cohort['month_3'] as num).toDouble(),
                    (cohort['month_4'] as num).toDouble(),
                    (cohort['month_5'] as num).toDouble(),
                    (cohort['month_6'] as num).toDouble(),
                  ];

                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          DateFormat('MMM yy').format(date),
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          size.toString(),
                          style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 10),
                        ),
                      ),
                      ...percentages.map((pct) => _buildHeatmapCell(pct)),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCell(double percentage) {
    // Determine color intensity based on retention percentage
    // 0% -> Transparent/Black
    // 100% -> Full Matrix Green
    final intensity = (percentage / 100).clamp(0.0, 1.0);
    final color = percentage == 0 
        ? Colors.transparent 
        : ThemeColors.matrixGreen.withValues(alpha: 0.1 + (intensity * 0.9));

    return Container(
      margin: const EdgeInsets.all(2),
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: percentage > 0
          ? Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: intensity > 0.5 ? Colors.black : Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}
