import 'dart:math';
import 'package:flutter/material.dart';
import 'package:net_bench/ui/theme/app_theme.dart';

class ThroughputGaugeWidget extends StatelessWidget {
  const ThroughputGaugeWidget({
    super.key,
    required this.currentSpeedMbps,
    required this.peakSpeedMbps,
    required this.avgSpeedMbps,
    this.maxScaleMbps = 1000.0,
    this.isUdp = false,
  });

  final double currentSpeedMbps;
  final double peakSpeedMbps;
  final double avgSpeedMbps;
  final double maxScaleMbps;
  final bool isUdp;

  @override
  Widget build(BuildContext context) {
    // Dynamically calculate effective max scale (100M, 1G, 2.5G, 10G)
    double effectiveMax = maxScaleMbps;
    final highest = max(currentSpeedMbps, peakSpeedMbps);
    if (highest > 5000) {
      effectiveMax = 10000.0;
    } else if (highest > 1200) {
      effectiveMax = 2500.0;
    } else if (highest > 120) {
      effectiveMax = 1000.0;
    } else if (effectiveMax <= 100) {
      effectiveMax = 100.0;
    }

    final isGbps = currentSpeedMbps >= 1000.0;
    final displayValue = isGbps
        ? (currentSpeedMbps / 1000.0).toStringAsFixed(2)
        : currentSpeedMbps.toStringAsFixed(1);
    final displayUnit = isGbps ? 'Gbits/sec' : 'Mbits/sec';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'THROUGHPUT GAUGE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'SCALE: ${effectiveMax >= 1000 ? '${(effectiveMax / 1000).toInt()}G' : '${effectiveMax.toInt()}M'}',
                style: AppTheme.monoStyle(
                  fontSize: 9.5,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            width: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(220, 150),
                  painter: _GaugePainter(
                    value: currentSpeedMbps,
                    peak: peakSpeedMbps,
                    max: effectiveMax,
                  ),
                ),
                Positioned(
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayValue,
                        style: AppTheme.monoStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        displayUnit,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryLight,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricPill(
                label: 'AVG',
                value: avgSpeedMbps >= 1000
                    ? '${(avgSpeedMbps / 1000).toStringAsFixed(2)} Gbps'
                    : '${avgSpeedMbps.toStringAsFixed(1)} Mbps',
                color: Colors.white70,
              ),
              _metricPill(
                label: 'PEAK',
                value: peakSpeedMbps >= 1000
                    ? '${(peakSpeedMbps / 1000).toStringAsFixed(2)} Gbps'
                    : '${peakSpeedMbps.toStringAsFixed(1)} Mbps',
                color: AppTheme.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.monoStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.peak,
    required this.max,
  });

  final double value;
  final double peak;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.78);
    final radius = size.width * 0.40;

    const startAngle = 135 * (pi / 180);
    const sweepTotal = 270 * (pi / 180);

    // 1. Background Arc Track
    final bgPaint = Paint()
      ..color = const Color(0xFF282828)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // 2. Active Sweeping Gradient Arc
    final clampedRatio = (value / max).clamp(0.0, 1.0);
    final activeSweep = sweepTotal * clampedRatio;

    if (activeSweep > 0) {
      final activePaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepTotal,
          colors: [
            AppTheme.primary,
            AppTheme.primaryLight,
            AppTheme.success,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }

    // 3. Peak Indicator Marker
    final peakRatio = (peak / max).clamp(0.0, 1.0);
    if (peakRatio > 0.02) {
      final peakAngle = startAngle + (sweepTotal * peakRatio);
      final markerCenter = Offset(
        center.dx + radius * cos(peakAngle),
        center.dy + radius * sin(peakAngle),
      );

      final markerPaint = Paint()
        ..color = AppTheme.success
        ..style = PaintingStyle.fill;

      canvas.drawCircle(markerCenter, 4, markerPaint);
      canvas.drawCircle(
        markerCenter,
        6,
        Paint()
          ..color = AppTheme.success.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // 4. Tick Marks
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 8; i++) {
      final tickAngle = startAngle + (sweepTotal * (i / 8));
      final inner = Offset(
        center.dx + (radius - 10) * cos(tickAngle),
        center.dy + (radius - 10) * sin(tickAngle),
      );
      final outer = Offset(
        center.dx + (radius - 16) * cos(tickAngle),
        center.dy + (radius - 16) * sin(tickAngle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.peak != peak ||
        oldDelegate.max != max;
  }
}
