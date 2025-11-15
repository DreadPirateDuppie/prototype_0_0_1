import 'package:flutter/material.dart';
import 'dart:math' as math;

class WheelSpin extends StatefulWidget {
  final Function(int) onSpinComplete;
  final bool canSpin;

  const WheelSpin({
    super.key,
    required this.onSpinComplete,
    required this.canSpin,
  });

  @override
  State<WheelSpin> createState() => _WheelSpinState();
}

class _WheelSpinState extends State<WheelSpin>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  final List<int> _rewards = [10, 25, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (!widget.canSpin || _isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    // Generate random number of full rotations + landing position
    final random = math.Random();
    final fullRotations = 5 + random.nextInt(3); // 5-7 full rotations
    final landingIndex = random.nextInt(_rewards.length);
    final landingAngle = (landingIndex * (2 * math.pi / _rewards.length)) + math.pi / 2;
    final totalRotation = (fullRotations * 2 * math.pi) + landingAngle;

    _animation = Tween<double>(
      begin: 0,
      end: totalRotation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.reset();
    _controller.forward().then((_) {
      setState(() {
        _isSpinning = false;
      });
      widget.onSpinComplete(_rewards[landingIndex]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Wheel
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animation.value,
                  child: child,
                );
              },
              child: SizedBox(
                width: 250,
                height: 250,
                child: CustomPaint(
                  painter: WheelPainter(rewards: _rewards),
                ),
              ),
            ),
            // Pointer
            Positioned(
              top: 0,
              child: Icon(
                Icons.arrow_drop_down,
                size: 50,
                color: Colors.red.shade700,
              ),
            ),
            // Center button
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: widget.canSpin && !_isSpinning
                    ? Colors.deepPurple
                    : Colors.grey,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'SPIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: widget.canSpin && !_isSpinning ? _spinWheel : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            backgroundColor: Colors.deepPurple,
            disabledBackgroundColor: Colors.grey,
          ),
          child: Text(
            _isSpinning
                ? 'Spinning...'
                : widget.canSpin
                    ? 'Spin the Wheel!'
                    : 'Come back tomorrow!',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<int> rewards;

  WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    final colors = [
      Colors.red.shade400,
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
    ];

    final segmentAngle = 2 * math.pi / rewards.length;

    for (int i = 0; i < rewards.length; i++) {
      final startAngle = i * segmentAngle - math.pi / 2;
      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Draw text
      final textAngle = startAngle + segmentAngle / 2;
      final textX = center.dx + (radius * 0.6) * math.cos(textAngle);
      final textY = center.dy + (radius * 0.6) * math.sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: rewards[i].toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Draw border
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) => false;
}
