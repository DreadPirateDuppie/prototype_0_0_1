import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';

class AdminUserDetailDialog extends StatelessWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // final userId = user['id']; // Unused as documented by lint
    final username = user['username'] ?? 'Unknown';
    final isAdmin = user['is_admin'] == true;
    final isVerified = user['is_verified'] == true;
    final isBanned = user['is_banned'] == true;
    final canPost = user['can_post'] ?? true;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null
                      ? Text(username[0].toUpperCase(), style: const TextStyle(fontSize: 24))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(user['email'] ?? 'No email'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (isAdmin) _buildBadge('Admin', Colors.red),
                          if (isVerified) _buildBadge('Verified', Colors.blue),
                          if (isBanned) _buildBadge('Banned', Colors.grey),
                          if (!canPost) _buildBadge('Muted', Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32),
            
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Points', (user['points'] ?? 0).toString()),
                // Add more stats here if available in the user map
              ],
            ),
            const Divider(height: 32),

            // Actions
            Expanded(
              child: ListView(
                children: [
                  const Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildActionButton(
                        context,
                        label: isAdmin ? 'Remove Admin' : 'Make Admin',
                        icon: Icons.security,
                        color: isAdmin ? Colors.red : Colors.green,
                        onPressed: () => _toggleAdmin(context),
                      ),
                      _buildActionButton(
                        context,
                        label: isVerified ? 'Unverify' : 'Verify',
                        icon: Icons.verified,
                        color: Colors.blue,
                        onPressed: () => _toggleVerified(context),
                      ),
                      _buildActionButton(
                        context,
                        label: isBanned ? 'Unban User' : 'Ban User',
                        icon: Icons.block,
                        color: isBanned ? Colors.green : Colors.red,
                        onPressed: () => isBanned ? _unbanUser(context) : _banUser(context),
                      ),
                      _buildActionButton(
                        context,
                        label: canPost ? 'Restrict Posting' : 'Allow Posting',
                        icon: Icons.edit_off,
                        color: Colors.orange,
                        onPressed: () => _togglePosting(context, !canPost),
                      ),
                      _buildActionButton(
                        context,
                        label: 'Add Points',
                        icon: Icons.add_circle,
                        color: Colors.green,
                        onPressed: () => _showPointsDialog(context, true),
                      ),
                      _buildActionButton(
                        context,
                        label: 'Remove Points',
                        icon: Icons.remove_circle,
                        color: Colors.red,
                        onPressed: () => _showPointsDialog(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildTransactionHistory(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTransactionHistory(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<AdminProvider>().getUserTransactionHistory(user['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No transactions found.');
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final tx = snapshot.data![index];
            final amount = tx['amount'] as num;
            final isPositive = amount > 0;
            
            return ListTile(
              dense: true,
              leading: Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? Colors.green : Colors.red,
                size: 16,
              ),
              title: Text(tx['description'] ?? 'Unknown transaction'),
              trailing: Text(
                '${isPositive ? '+' : ''}$amount',
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(tx['created_at'].toString().split('T')[0]),
            );
          },
        );
      },
    );
  }

  // Action Handlers
  void _toggleAdmin(BuildContext context) {
    final provider = context.read<AdminProvider>();
    final isCurrentlyAdmin = user['is_admin'] == true;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCurrentlyAdmin ? 'Remove Admin?' : 'Make Admin?'),
        content: Text('Are you sure you want to ${isCurrentlyAdmin ? 'remove admin rights from' : 'grant admin rights to'} ${user['username']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.toggleAdminStatus(user['id'], !isCurrentlyAdmin);
              if (context.mounted) Navigator.pop(context); // Close detail dialog
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _toggleVerified(BuildContext context) {
    final provider = context.read<AdminProvider>();
    final isVerified = user['is_verified'] == true;
    
    provider.toggleVerificationStatus(user['id'], !isVerified).then((_) {
      if (context.mounted) Navigator.pop(context);
    });
  }

  void _banUser(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban User'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason for ban'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) return;
              Navigator.pop(context);
              await context.read<AdminProvider>().banUser(user['id'], reasonController.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Ban', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _unbanUser(BuildContext context) {
    context.read<AdminProvider>().unbanUser(user['id']).then((_) {
      if (context.mounted) Navigator.pop(context);
    });
  }

  void _togglePosting(BuildContext context, bool canPost) {
    context.read<AdminProvider>().togglePostingRestriction(user['id'], canPost).then((_) {
      if (context.mounted) Navigator.pop(context);
    });
  }

  void _showPointsDialog(BuildContext context, bool isAdding) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAdding ? 'Add Points' : 'Remove Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || descController.text.isEmpty) return;
              
              Navigator.pop(context);
              if (isAdding) {
                await context.read<AdminProvider>().addPoints(user['id'], amount, descController.text);
              } else {
                await context.read<AdminProvider>().removePoints(user['id'], amount, descController.text);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
