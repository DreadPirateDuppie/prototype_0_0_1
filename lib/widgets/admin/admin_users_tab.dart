import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prototype_0_0_1/config/theme_config.dart';
import '../../providers/admin_provider.dart';
import 'admin_user_detail_dialog.dart';
import 'dart:async';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  // Debounce timer
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      if (!provider.isLoading && provider.hasNextPage) {
        provider.loadUsersPaginated(searchQuery: _searchQuery);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        Provider.of<AdminProvider>(context, listen: false)
            .loadUsersPaginated(reset: true, searchQuery: query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: ThemeColors.matrixGreen, fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: '>_SEARCH_NODES...',
              hintStyle: TextStyle(color: ThemeColors.matrixGreen.withValues(alpha: 0.3)),
              prefixIcon: const Icon(Icons.search, color: ThemeColors.matrixGreen),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: ThemeColors.matrixGreen.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: ThemeColors.matrixGreen.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: ThemeColors.matrixGreen, width: 2),
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: Consumer<AdminProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.users.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen));
              }

              if (provider.users.isEmpty) {
                return const Center(
                  child: Text(
                    'ZERO_NODES_LOCATED',
                    style: TextStyle(color: Colors.white24, fontFamily: 'monospace', fontSize: 12),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => provider.loadUsersPaginated(reset: true, searchQuery: _searchQuery),
                color: ThemeColors.matrixGreen,
                backgroundColor: Colors.black,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: provider.users.length + (provider.hasNextPage ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.users.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ThemeColors.matrixGreen, 
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    final user = provider.users[index];
                    return _buildUserTile(context, user);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserTile(BuildContext context, Map<String, dynamic> user) {
    final isBanned = user['is_banned'] == true;
    final isVerified = user['is_verified'] == true;
    final isAdmin = user['is_admin'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBanned 
              ? Colors.redAccent.withValues(alpha: 0.3) 
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ThemeColors.matrixGreen.withValues(alpha: 0.2)),
            image: user['avatar_url'] != null
                ? DecorationImage(image: NetworkImage(user['avatar_url']), fit: BoxFit.cover)
                : null,
          ),
          child: user['avatar_url'] == null
              ? Center(
                  child: Text(
                    (user['username'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: ThemeColors.matrixGreen, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Text(
              user['username'] ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 8),
              const Icon(Icons.verified, size: 14, color: Colors.blueAccent),
            ],
            if (isAdmin) ...[
              const SizedBox(width: 8),
              const Icon(Icons.security, size: 14, color: Colors.redAccent),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['email'] ?? 'NO_IDENTIFIER',
              style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
            ),
            if (isBanned)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'STATUS: QUARANTINED [${user['ban_reason'] ?? 'NO_REASON'}]',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
        onTap: () {
          final adminProvider = Provider.of<AdminProvider>(context, listen: false);
          showDialog(
            context: context,
            builder: (context) => ChangeNotifierProvider.value(
              value: adminProvider,
              child: AdminUserDetailDialog(user: user),
            ),
          );
        },
      ),
    );
  }
}
