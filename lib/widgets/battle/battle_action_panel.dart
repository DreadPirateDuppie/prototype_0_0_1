import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/battle_detail_provider.dart';
import '../../models/battle.dart';
import '../../config/theme_config.dart';
import 'battle_voting_panel.dart';
import 'rps_selection_grid.dart';

class BattleActionPanel extends StatelessWidget {
  const BattleActionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BattleDetailProvider>(
      builder: (context, provider, child) {
        final battle = provider.battle;
        if (battle == null) return const SizedBox.shrink();

        // RPS Check
        if (battle.setterId == null) {
          return RpsSelectionGrid(
            battle: battle,
            onMoveSelected: provider.submitRpsMove,
            onForfeit: provider.forfeitBattle,
          );
        }

        if (battle.verificationStatus == VerificationStatus.quickFireVoting) {
          return BattleVotingPanel(
            battle: battle,
            onVote: provider.submitVote,
          );
        }

        if (battle.verificationStatus == VerificationStatus.communityVerification) {
          return _buildCommunityReviewPanel();
        }

        final bool canUploadSet = provider.isMyTurn && battle.setTrickVideoUrl == null;
        final bool canUploadAttempt = provider.isMyTurn &&
            battle.setTrickVideoUrl != null &&
            battle.verificationStatus == VerificationStatus.pending;

        String helper;
        IconData icon;
        Color color;
        VoidCallback onPressed;
        String label = 'UPLOAD CLIP';

        if (canUploadSet) {
          helper = 'Set the challenge for your opponent';
          icon = Icons.add_a_photo_outlined;
          color = ThemeColors.matrixGreen;
          onPressed = () => _handleUploadSet(context, provider);
          label = 'SET TRICK';
        } else if (canUploadAttempt) {
          helper = 'Attempt the trick to avoid a letter';
          icon = Icons.sports_kabaddi_outlined;
          color = Colors.orange;
          onPressed = () => _handleUploadAttempt(context, provider);
          label = 'ATTEMPT TRICK';
        } else {
          helper = 'Wait for your turn to make a move';
          icon = Icons.lock_outline;
          color = Colors.red;
          onPressed = () {}; // No-op
          label = "OPPONENT'S TURN";
          if (battle.turnDeadline != null) {
            label += ' (${_formatDuration(battle.getRemainingTime())})';
          }
        }

        return Column(
          children: [
            _buildActionButton(
              label: label,
              helper: helper,
              icon: icon,
              color: color,
              onPressed: onPressed,
            ),
            if (canUploadAttempt) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => _handleForfeitTurn(context, provider),
                child: Text(
                  'SKIP TRICK (TAKE LETTER)',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.red.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCommunityReviewPanel() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: ThemeColors.surfaceDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: Colors.orange,
              size: 40,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'COMMUNITY REVIEW',
            style: AppTextStyles.heading3.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Votes didn\'t match. The community will decide the outcome.',
            style: AppTextStyles.body2.copyWith(
              color: ThemeColors.textSecondary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String helper,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final bool isOpponentTurn = label.contains("OPPONENT'S TURN");
    
    Color textColor;
    if (isOpponentTurn) {
      textColor = Colors.white;
    } else if (color == ThemeColors.matrixGreen || color == Colors.orange) {
      textColor = Colors.black;
    } else {
      textColor = Colors.white;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            gradient: isOpponentTurn 
                ? const LinearGradient(
                    colors: [Color(0xFF600000), Color(0xFFB71C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !isOpponentTurn ? color : null,
            boxShadow: [
              BoxShadow(
                color: (isOpponentTurn ? Colors.red : color).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18, color: textColor),
            label: Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          helper.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            color: ThemeColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleUploadSet(BuildContext context, BattleDetailProvider provider) async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    if (!context.mounted) return;

    final trickName = await showDialog<String>(
      context: context,
      builder: (context) => _TrickNameDialog(),
    );
    
    if (!context.mounted) return;
    await provider.uploadSetTrick(File(video.path), trickName);
  }

  Future<void> _handleUploadAttempt(BuildContext context, BattleDetailProvider provider) async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    await provider.uploadAttempt(File(video.path));
  }

  Future<void> _handleForfeitTurn(BuildContext context, BattleDetailProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SKIP TRICK?'),
        content: const Text('Are you sure you want to skip this trick? You will receive a letter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SKIP')),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.forfeitTurn();
    }
  }
}

class _TrickNameDialog extends StatefulWidget {
  @override
  State<_TrickNameDialog> createState() => _TrickNameDialogState();
}

class _TrickNameDialogState extends State<_TrickNameDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name Your Trick'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'e.g., Kickflip, Tre Flip'),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Set Name'),
        ),
      ],
    );
  }
}
