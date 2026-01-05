import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import 'package:prototype_0_0_1/config/theme_config.dart';
import 'dart:ui';
import '../widgets/admin/admin_analytics_tab.dart';
import '../widgets/admin/admin_users_tab.dart';
import '../widgets/admin/admin_reports_tab.dart';
import '../widgets/admin/admin_settings_tab.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminProvider()..init(),
      child: const _AdminDashboardContent(),
    );
  }
}

class _AdminDashboardContent extends StatelessWidget {
  const _AdminDashboardContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && !provider.isAdmin) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: ThemeColors.matrixGreen)),
          );
        }

        if (!provider.isAdmin) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                '>_ACCESS_DENIED',
                style: TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 24),
                  const Text(
                    'SECURITY_FAILURE: PERMISSION_MINIMUM_NOT_MET',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'ERROR_LOG: ${provider.error!}',
                        style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.8),
              elevation: 0,
              title: const Text(
                '>_ADMIN_CONSOLE',
                style: TextStyle(
                  color: ThemeColors.matrixGreen,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 18,
                ),
              ),
              bottom: TabBar(
                indicatorColor: ThemeColors.matrixGreen,
                labelColor: ThemeColors.matrixGreen,
                unselectedLabelColor: Colors.white24,
                labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(icon: Icon(Icons.analytics_outlined, size: 20), text: 'METRICS'),
                  Tab(icon: Icon(Icons.people_outline, size: 20), text: 'NODES'),
                  Tab(icon: Icon(Icons.gavel_outlined, size: 20), text: 'MOD'),
                  Tab(icon: Icon(Icons.settings_outlined, size: 20), text: 'CORE'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: ThemeColors.matrixGreen, size: 20),
                  onPressed: provider.loadAllData,
                ),
              ],
            ),
            body: Stack(
              children: [
                // Matrix background could be added here if needed, 
                // but usually the main layout has it.
                const TabBarView(
                  children: [
                    AdminAnalyticsTab(),
                    AdminUsersTab(),
                    AdminReportsTab(),
                    AdminSettingsTab(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
