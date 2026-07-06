import 'package:flutter/material.dart';

class RewardsTransactionHistory extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final VoidCallback onViewAll;

  const RewardsTransactionHistory({
    super.key,
    required this.transactions,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ledger History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF41),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final amount = (tx['amount'] as num).toDouble();
              final isPositive = amount > 0;
              final date = DateTime.parse(tx['created_at'] as String);
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isPositive ? const Color(0xFF00FF41) : Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx['description'] ?? tx['transaction_type'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.month}/${date.day} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}$amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isPositive ? const Color(0xFF00FF41) : Colors.red.shade700,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
