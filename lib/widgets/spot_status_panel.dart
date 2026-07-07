import 'dart:async';
import 'package:flutter/material.dart';
import '../models/spot_status.dart';
import '../services/spot_status_service.dart';
import '../utils/error_helper.dart';

/// "Eyes on the Street" Quick-Report panel for the Spot Detail screen: shows
/// the spot's current Live Intelligence status (reverting to CLEAR once the
/// 4-hour TTL lapses) and one-tap buttons to report a new status.
///
/// Triggers the SECURITY_ACTIVE haptic pattern whenever this panel newly
/// observes that alert — either on first load or on a live flip while the
/// user has the screen open.
class SpotStatusPanel extends StatefulWidget {
  final String spotId;

  const SpotStatusPanel({super.key, required this.spotId});

  @override
  State<SpotStatusPanel> createState() => _SpotStatusPanelState();
}

class _SpotStatusPanelState extends State<SpotStatusPanel> {
  final SpotStatusService _service = SpotStatusService();
  StreamSubscription<SpotStatus>? _subscription;
  SpotStatus? _status;
  bool _isReporting = false;

  @override
  void initState() {
    super.initState();
    _subscription = _service.subscribeToSpotStatus(widget.spotId).listen((status) {
      if (!mounted) return;
      final wasAlert = _status?.statusType.isTacticalAlert ?? false;
      setState(() => _status = status);
      if (status.statusType == SpotStatusType.securityActive && !wasAlert) {
        SpotStatusService.triggerSecurityAlertHaptic();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _report(SpotStatusType type) async {
    if (_isReporting) return;
    setState(() => _isReporting = true);

    final result = await _service.reportStatus(widget.spotId, type);

    if (mounted) {
      setState(() => _isReporting = false);
      if (result == null) {
        ErrorHelper.showError(context, 'Failed to submit report. Try again.');
      } else if (result['recorded'] == false && result['reason'] == 'cooldown') {
        ErrorHelper.showError(
          context,
          'You already reported this spot recently. Give it a few minutes.',
        );
      }
    }
  }

  ({Color color, IconData icon}) _presentationFor(SpotStatusType type) {
    switch (type) {
      case SpotStatusType.securityActive:
        return (color: Colors.redAccent, icon: Icons.local_police_rounded);
      case SpotStatusType.wet:
        return (color: Colors.blueAccent, icon: Icons.water_drop_rounded);
      case SpotStatusType.lockedOff:
        return (color: Colors.orangeAccent, icon: Icons.lock_rounded);
      case SpotStatusType.sessionAlive:
        return (color: Colors.greenAccent, icon: Icons.bolt_rounded);
      case SpotStatusType.clear:
        return (color: const Color(0xFF00FF41), icon: Icons.radar_rounded);
    }
  }

  String _timeRemaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'expiring';
    if (remaining.inHours > 0) return '${remaining.inHours}h left';
    if (remaining.inMinutes > 0) return '${remaining.inMinutes}m left';
    return '<1m left';
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    final status = _status ?? SpotStatus.clearFor(widget.spotId);
    final presentation = _presentationFor(status.statusType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: presentation.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(presentation.icon, color: presentation.color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE INTEL: ${status.statusType.label.toUpperCase()}',
                      style: TextStyle(
                        color: presentation.color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (status.expiresAt != null)
                      Text(
                        _timeRemaining(status.expiresAt!),
                        style: TextStyle(
                          color: presentation.color.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'QUICK-REPORT',
            style: TextStyle(
              color: matrixGreen.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SpotStatusType.values
                .where((type) => type != SpotStatusType.clear)
                .map((type) => _buildReportChip(type))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportChip(SpotStatusType type) {
    final presentation = _presentationFor(type);
    return ActionChip(
      avatar: Icon(presentation.icon, color: presentation.color, size: 16),
      label: Text(
        type.label,
        style: TextStyle(color: presentation.color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      backgroundColor: presentation.color.withValues(alpha: 0.1),
      side: BorderSide(color: presentation.color.withValues(alpha: 0.4)),
      onPressed: _isReporting ? null : () => _report(type),
    );
  }
}
