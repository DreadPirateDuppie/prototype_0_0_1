import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype_0_0_1/config/theme_config.dart';
import '../../providers/admin_provider.dart';
import 'package:intl/intl.dart';

class AdminErrorsTab extends StatelessWidget {
  const AdminErrorsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.errorLogs.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen));
        }

        if (provider.errorLogs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            _buildTerminalHeader(provider.errorLogs.length),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: provider.errorLogs.length,
                itemBuilder: (context, index) {
                  final log = provider.errorLogs[index];
                  return _ErrorLogTile(log: log);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTerminalHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white.withValues(alpha: 0.05),
      child: Row(
        children: [
          const Icon(Icons.terminal, color: ThemeColors.matrixGreen, size: 16),
          const SizedBox(width: 8),
          Text(
            'LIVE_STREAM_BUFFER: $count ENTRIES',
            style: const TextStyle(
              color: ThemeColors.matrixGreen,
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'RECORDING',
            style: TextStyle(
              color: Colors.redAccent,
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: ThemeColors.matrixGreen.withValues(alpha: 0.3), size: 64),
          const SizedBox(height: 24),
          const Text(
            'SYSTEM_READY: NO_ERRORS_DETECTED',
            style: TextStyle(
              color: ThemeColors.matrixGreen,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorLogTile extends StatelessWidget {
  final Map<String, dynamic> log;

  const _ErrorLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.parse(log['created_at']).toLocal();
    final timeStr = DateFormat('HH:mm:ss').format(timestamp);
    final errorType = log['error_type'] ?? 'UNKNOWN';
    final message = log['error_message'] ?? 'No message';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => _showErrorDetail(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[$timeStr]',
                    style: const TextStyle(
                      color: Colors.white24,
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorType,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ErrorDetailDialog(log: log),
    );
  }
}

class _ErrorDetailDialog extends StatelessWidget {
  final Map<String, dynamic> log;

  const _ErrorDetailDialog({required this.log});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ThemeColors.matrixGreen, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.redAccent),
                const SizedBox(width: 12),
                const Text(
                  'CRITICAL_FAILURE_DUMP',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            _buildDetailRow('TYPE', log['error_type']),
            _buildDetailRow('USER_ID', log['user_id'] ?? 'ANONYMOUS'),
            _buildDetailRow('SEVERITY', log['severity']?.toString().toUpperCase()),
            const SizedBox(height: 16),
            const Text(
              'RAW_MESSAGE:',
              style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.white.withValues(alpha: 0.05),
              child: Text(
                log['error_message'] ?? 'N/A',
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'STACK_TRACE:',
              style: TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.white.withValues(alpha: 0.05),
                child: SingleChildScrollView(
                  child: Text(
                    log['stack_trace'] ?? 'NO_STACK_TRACE_AVAILABLE',
                    style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10),
          ),
          Text(
            value ?? 'N/A',
            style: const TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
