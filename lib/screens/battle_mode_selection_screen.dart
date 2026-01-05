import 'dart:ui';
import 'package:flutter/material.dart';
import 'create_battle_screen.dart';
import 'quick_match_lobby_dialog.dart';
import 'skate_lobby_setup_screen.dart';
import '../config/theme_config.dart';

class BattleModeSelectionScreen extends StatelessWidget {
  const BattleModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Show global Matrix
      appBar: AppBar(
        title: const Text(
          '> BATTLE MODE',
          style: TextStyle(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        iconTheme: const IconThemeData(color: ThemeColors.matrixGreen),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  ThemeColors.matrixGreen.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeColors.matrixGreen.withValues(alpha: 0.03),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Spacer(),
                
                // Quick Match
                _buildCyberButton(
                  context,
                  title: 'QUICK MATCH',
                  description: 'ESTABLISH INSTANT UPLINK W/ RANDOM HOST',
                  protocolId: 'PRTCOL_QM_01',
                  icon: Icons.bolt,
                  color: Colors.redAccent,
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const QuickMatchLobbyDialog(),
                    ).then((result) {
                      if (result == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    });
                  },
                ),

                const SizedBox(height: 20),

                // Play vs Friends
                _buildCyberButton(
                  context,
                  title: 'VS FRIENDS',
                  description: 'TARGETED CONNECTION TO KNOWN NODES',
                  protocolId: 'PRTCOL_VF_02',
                  icon: Icons.radar,
                  color: ThemeColors.matrixGreen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateBattleScreen(),
                      ),
                    ).then((result) {
                      if (result == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    });
                  },
                ),

                const SizedBox(height: 20),

                // Local Game
                _buildCyberButton(
                  context,
                  title: 'LOCAL GAME',
                  description: 'OFFLINE PROXIMITY ENGAGEMENT (IRL)',
                  protocolId: 'PRTCOL_LG_03',
                  icon: Icons.lan,
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SkateLobbySetupScreen(),
                      ),
                    );
                  },
                ),
                
                const Spacer(),
                _buildFooterStatus(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              color: ThemeColors.matrixGreen,
            ),
            const SizedBox(width: 8),
            const Text(
              'SESSION_INITIATED',
              style: TextStyle(
                color: ThemeColors.matrixGreen,
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'SELECT ENGAGEMENT PROTOCOL:',
          style: TextStyle(
            color: ThemeColors.matrixGreen.withValues(alpha: 0.5),
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterStatus() {
    return Column(
      children: [
        Divider(color: ThemeColors.matrixGreen.withValues(alpha: 0.1)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatusItem('ENCRYPTION', 'ACTIVE'),
            _buildStatusItem('LATENCY', 'LOW'),
            _buildStatusItem('SYSTEM', 'READY'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontFamily: 'monospace',
            fontSize: 8,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: ThemeColors.matrixGreen,
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCyberButton(
    BuildContext context, {
    required String title,
    required String description,
    required String protocolId,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Corner Brackets
                Positioned(top: 0, left: 0, child: _buildCorner(color, true, true)),
                Positioned(top: 0, right: 0, child: _buildCorner(color, true, false)),
                Positioned(bottom: 0, left: 0, child: _buildCorner(color, false, true)),
                Positioned(bottom: 0, right: 0, child: _buildCorner(color, false, false)),
                
                // Scanline overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          color.withValues(alpha: 0.02),
                          Colors.transparent,
                        ],
                        stops: const [0.48, 0.5, 0.52],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Icon area with glitched look
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.05),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: color,
                                    fontFamily: 'monospace',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Text(
                                  '[$protocolId]',
                                  style: TextStyle(
                                    color: color.withValues(alpha: 0.4),
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontFamily: 'monospace',
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chevron_right,
                        color: color.withValues(alpha: 0.3),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(Color color, bool isTop, bool isLeft) {
    const size = 10.0;
    const thickness = 2.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: color, width: thickness) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: color, width: thickness) : BorderSide.none,
          left: isLeft ? BorderSide(color: color, width: thickness) : BorderSide.none,
          right: !isLeft ? BorderSide(color: color, width: thickness) : BorderSide.none,
        ),
      ),
    );
  }
}
