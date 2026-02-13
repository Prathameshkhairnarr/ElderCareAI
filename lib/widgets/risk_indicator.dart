import 'dart:math';
import 'package:flutter/material.dart';

class RiskIndicator extends StatelessWidget {
  final double score;
  final double size;

  const RiskIndicator({super.key, required this.score, this.size = 200});

  Color _getColor(double value) {
    if (value < 30) return const Color(0xFF4CAF50);
    if (value < 60) return const Color(0xFFFFA726);
    if (value < 80) return const Color(0xFFFF7043);
    return const Color(0xFFEF5350);
  }

  String _getLabel(double value) {
    if (value < 30) return 'Low Risk';
    if (value < 60) return 'Moderate';
    if (value < 80) return 'High Risk';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final color = _getColor(value);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RiskArcPainter(
                  progress: value / 100,
                  color: color,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.toInt()}',
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getLabel(value),
                    style: TextStyle(
                      fontSize: size * 0.075,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RiskArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _RiskArcPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;
    const strokeWidth = 14.0;
    const startAngle = 2.4; // ~137 degrees
    const sweepTotal = 2 * pi - (startAngle - pi) * 2;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * progress,
      false,
      fgPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * progress,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RiskArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
