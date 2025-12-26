import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

class AdminErrorLogsScreen extends StatefulWidget {
  const AdminErrorLogsScreen({super.key});

  @override
  State<AdminErrorLogsScreen> createState() => _AdminErrorLogsScreenState();
}

class _AdminErrorLogsScreenState extends State<AdminErrorLogsScreen> {
  List<Map<String, dynamic>> _errorLogs = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadErrorLogs();
  }

  Future<void> _loadErrorLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await SupabaseService.getErrorLogs(limit: 500);
      if (mounted) {
        setState(() {
          _errorLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_searchQuery.isEmpty) return _errorLogs;
    return _errorLogs.where((log) {
      final message = (log['error_message'] as String? ?? '').toLowerCase();
      final screen = (log['screen_name'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return message.contains(query) || screen.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);

    return Scaffold(
      backgroundColor: matrixBlack,
      appBar: AppBar(
        title: const Text(
          'ERROR LOGS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: matrixBlack,
        foregroundColor: matrixGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadErrorLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              style: const TextStyle(color: matrixGreen),
              decoration: InputDecoration(
                hintText: 'Search errors...',
                hintStyle: TextStyle(color: matrixGreen.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, color: matrixGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: matrixGreen),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: matrixGreen.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: matrixGreen, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Stats summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: matrixGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: matrixGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total', _errorLogs.length.toString()),
                _buildStat('Showing', _filteredLogs.length.toString()),
              ],
            ),
          ),

          // Error list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: matrixGreen),
                  )
                : _filteredLogs.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No errors logged yet 🎉'
                              : 'No matching errors found',
                          style: TextStyle(
                            color: matrixGreen.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: matrixGreen,
                        onRefresh: _loadErrorLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredLogs.length,
                          itemBuilder: (context, index) {
                            return _buildErrorCard(_filteredLogs[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    const matrixGreen = Color(0xFF00FF41);
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: matrixGreen,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: matrixGreen.withValues(alpha: 0.7),
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(Map<String, dynamic> log) {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    final message = log['error_message'] as String? ?? 'Unknown error';
    final stack = log['error_stack'] as String?;
    final screenName = log['screen_name'] as String?;
    final createdAt = log['created_at'] as String?;
    final userProfiles = log['user_profiles'] as Map<String, dynamic>?;
    final username = userProfiles?['username'] as String? ?? 
                     userProfiles?['display_name'] as String? ?? 
                     'Anonymous';

    DateTime? timestamp;
    if (createdAt != null) {
      try {
        timestamp = DateTime.parse(createdAt);
      } catch (e) {
        // Ignore parse errors
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: matrixGreen,
        collapsedIconColor: matrixGreen.withValues(alpha: 0.7),
        title: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.person, size: 14, color: matrixGreen.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                username,
                style: TextStyle(
                  color: matrixGreen.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              if (screenName != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.app_shortcut, size: 14, color: matrixGreen.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  screenName,
                  style: TextStyle(
                    color: matrixGreen.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              if (timestamp != null)
                Text(
                  DateFormat('MMM d, HH:mm').format(timestamp.toLocal()),
                  style: TextStyle(
                    color: matrixGreen.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: matrixBlack,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full error message
                SelectableText(
                  message,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                
                // Stack trace if available
                if (stack != null) ...[
                  const SizedBox(height: 12),
                  const Divider(color: matrixGreen),
                  const SizedBox(height: 8),
                  Text(
                    'Stack Trace:',
                    style: TextStyle(
                      color: matrixGreen.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    stack,
                    style: TextStyle(
                      color: matrixGreen.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],

                // Copy button
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final fullError = stack != null 
                          ? '$message\n\nStack Trace:\n$stack'
                          : message;
                      Clipboard.setData(ClipboardData(text: fullError));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('COPY'),
                    style: TextButton.styleFrom(
                      foregroundColor: matrixGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
