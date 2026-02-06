import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/ad_banner.dart';

class TransactionHistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const TransactionHistoryScreen({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark theme
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFF00FF41)),
        title: const Text(
          'TRANSACTION_LOG',
          style: TextStyle(
            color: Color(0xFF00FF41),
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: transactions.isEmpty
                ? const Center(
                    child: Text(
                      'NO TRANSACTIONS FOUND.',
                      style: TextStyle(color: Colors.white54, fontFamily: 'monospace'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      final amount = tx['amount'] as num? ?? 0;
                      final type = tx['transaction_type'] as String? ?? 'Unknown';
                      final description = tx['description'] as String? ?? '';
                      final createdAt = tx['created_at'] != null 
                          ? DateTime.parse(tx['created_at'] as String).toLocal()
                          : DateTime.now();
                      
                      final isPositive = amount >= 0;
                      final color = isPositive ? const Color(0xFF00FF41) : Colors.redAccent;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color.withValues(alpha: 0.3)),
                              ),
                              child: Icon(
                                isPositive ? Icons.add_rounded : Icons.remove_rounded,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatType(type),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (description.isNotEmpty)
                                    Text(
                                      description,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 14,
                                      ),
                                    ),
                                  Text(
                                    DateFormat('MMM dd, yyyy • HH:mm').format(createdAt),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isPositive ? '+' : ''}$amount',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'daily_login':
        return 'DAILY CHECK-IN';
      case 'ad_watch':
        return 'AD REWARD';
      case 'battle_win':
        return 'BATTLE VICTORY';
      case 'battle_wager':
        return 'BATTLE WAGER';
      case 'spot_discovery':
        return 'SPOT DISCOVERY';
      default:
        return type.toUpperCase().replaceAll('_', ' ');
    }
  }
}
