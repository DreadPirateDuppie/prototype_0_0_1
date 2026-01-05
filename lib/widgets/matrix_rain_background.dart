import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class MatrixRainBackground extends StatefulWidget {
  final double opacity;
  final double speed;
  final Color color;

  const MatrixRainBackground({
    super.key,
    this.opacity = 0.1,
    this.speed = 0.6,
    this.color = const Color(0xFF00FF41),
  });

  @override
  State<MatrixRainBackground> createState() => _MatrixRainBackgroundState();
}

class _MatrixRainBackgroundState extends State<MatrixRainBackground> with SingleTickerProviderStateMixin {
  late Timer _timer;
  late List<_MatrixColumn> _columns;
  final Random _random = Random();
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _columns = [];
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          for (var column in _columns) {
            column.update(_random, widget.speed);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _initializeColumns(Size size) {
    if (_lastSize == size) return;
    _lastSize = size;
    
    final columnCount = (size.width / 8.0).ceil(); // Much higher frequency (was 12)
    _columns = List.generate(columnCount, (index) {
      return _MatrixColumn(
        x: index * 8.0,
        y: _random.nextDouble() * size.height,
        chars: List.generate(15 + _random.nextInt(15), (_) => _generateChar()),
      );
    });
  }

  String _generateChar() {
    return _random.nextBool() ? "1" : "0";
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _initializeColumns(Size(constraints.maxWidth, constraints.maxHeight));
        return CustomPaint(
          size: Size.infinite,
          painter: _MatrixPainter(
            columns: _columns,
            opacity: widget.opacity,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _MatrixColumn {
  double x;
  double y;
  List<String> chars;
  double speed;

  _MatrixColumn({
    required this.x,
    required this.y,
    required this.chars,
  }) : speed = 2.0 + Random().nextDouble() * 5.0;

  void update(Random random, double speedMultiplier) {
    y += speed * speedMultiplier;
    if (y > 1200) { 
      y = -chars.length * 12.0; // Tighter vertical spacing
    }
    // Occasionally change a character
    if (random.nextDouble() > 0.9) {
      chars[random.nextInt(chars.length)] = _generateChar(random);
    }
  }

  String _generateChar(Random random) {
    return random.nextBool() ? "1" : "0";
  }
}

class _MatrixPainter extends CustomPainter {
  final List<_MatrixColumn> columns;
  final double opacity;
  final Color color;

  _MatrixPainter({
    required this.columns,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: color,
      fontSize: 12, // Thinner characters (was 18)
      fontFamily: 'monospace',
      fontWeight: FontWeight.w400, // Thinner weight (was w900)
    );

    for (var column in columns) {
      // If column is off screen bottom, reset it to top
      if (column.y > size.height) {
        column.y = -column.chars.length * 12.0;
      }

      for (int i = 0; i < column.chars.length; i++) {
        final charY = column.y + (i * 12.0); // More frequent/tighter vertical spacing
        if (charY < -20 || charY > size.height) continue;

        // Fade out characters at the top of the column
        double charOpacity = (i / column.chars.length) * opacity;
        
        // The last character is bright white/green
        if (i == column.chars.length - 1) {
          charOpacity = opacity * 2.0;
        }

        final span = TextSpan(
          text: column.chars[i],
          style: textStyle.copyWith(
            color: (i == column.chars.length - 1) 
              ? Colors.white.withValues(alpha: (opacity * 3).clamp(0, 1)) // White head
              : color.withValues(alpha: charOpacity.clamp(0, 1)),
            shadows: i == column.chars.length - 1 ? [
              Shadow(color: color, blurRadius: 10),
            ] : null,
          ),
        );

        final tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(column.x, charY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
