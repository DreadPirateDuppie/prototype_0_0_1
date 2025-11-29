import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';
import 'skate_lobby_screen.dart';

class SkateLobbySetupScreen extends StatefulWidget {
  const SkateLobbySetupScreen({super.key});

  @override
  State<SkateLobbySetupScreen> createState() => _SkateLobbySetupScreenState();
}

class _SkateLobbySetupScreenState extends State<SkateLobbySetupScreen> {
  final _codeController = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;

  static const Color matrixGreen = Color(0xFF00FF41);
  static const Color matrixBlack = Color(0xFF000000);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createLobby() async {
    setState(() => _isCreating = true);
    try {
      final lobbyId = await SupabaseService.createLobby();
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SkateLobbyScreen(lobbyId: lobbyId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to create lobby: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinLobby() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 4) {
      ErrorHelper.showError(context, 'Please enter a valid 4-character code');
      return;
    }

    setState(() => _isJoining = true);
    try {
      final lobbyId = await SupabaseService.joinLobby(code);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SkateLobbyScreen(lobbyId: lobbyId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, 'Failed to join lobby: $e');
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: matrixBlack,
      appBar: AppBar(
        title: const Text(
          '> SKATE_LOBBY',
          style: TextStyle(
            color: matrixGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: matrixBlack,
        iconTheme: const IconThemeData(color: matrixGreen),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: matrixGreen.withValues(alpha: 0.3),
            height: 1,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            
            // Create Lobby Section
            _buildSection(
              title: 'HOST A GAME',
              description: 'Create a new lobby and invite friends with a code.',
              child: ElevatedButton(
                onPressed: _isCreating || _isJoining ? null : _createLobby,
                style: ElevatedButton.styleFrom(
                  backgroundColor: matrixGreen,
                  foregroundColor: matrixBlack,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: matrixBlack,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'CREATE LOBBY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 48),
            
            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: matrixGreen.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: matrixGreen.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: matrixGreen.withValues(alpha: 0.3))),
              ],
            ),

            const SizedBox(height: 48),

            // Join Lobby Section
            _buildSection(
              title: 'JOIN A GAME',
              description: 'Enter the 4-character code from the host.',
              child: Column(
                children: [
                  TextField(
                    controller: _codeController,
                    style: const TextStyle(
                      color: matrixGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 4,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'CODE',
                      hintStyle: TextStyle(
                        color: matrixGreen.withValues(alpha: 0.3),
                        letterSpacing: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: matrixGreen.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                          color: matrixGreen,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: matrixGreen.withValues(alpha: 0.05),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isCreating || _isJoining ? null : _joinLobby,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: matrixGreen,
                        side: const BorderSide(color: matrixGreen, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isJoining
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: matrixGreen,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'JOIN LOBBY',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}
