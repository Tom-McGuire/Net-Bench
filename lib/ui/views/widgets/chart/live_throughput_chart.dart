import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:net_bench/domain/models/live_sample.dart';
import 'package:net_bench/ui/theme/app_theme.dart';

class LiveThroughputChart extends StatefulWidget {
  const LiveThroughputChart({
    super.key,
    required this.samples,
    this.isUdp = false,
    this.isBufferbloat = false,
  });

  final List<LiveSample> samples;
  final bool isUdp;
  final bool isBufferbloat;

  @override
  State<LiveThroughputChart> createState() => _LiveThroughputChartState();
}

class _LiveThroughputChartState extends State<LiveThroughputChart> {
  bool _showSecondaryMetric = true;

  @override
  Widget build(BuildContext context) {
    if (widget.samples.isEmpty) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart,
                  size: 40,
                  color: AppTheme.primaryLight.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              const Text(
                'Throughput waveform will stream here during benchmark',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    final throughputSpots = widget.samples
        .map((s) => FlSpot(s.secondsElapsed, s.throughputMbps))
        .toList();

    // Determine max Y for auto-scaling
    double maxY = 100.0;
    for (final s in widget.samples) {
      if (s.throughputMbps > maxY) maxY = s.throughputMbps;
    }
    maxY = (maxY * 1.15).ceilToDouble();

    // Secondary metric spots (Jitter or Ping)
    List<FlSpot> secondarySpots = [];
    if (_showSecondaryMetric) {
      if (widget.isUdp) {
        secondarySpots = widget.samples
            .where((s) => s.jitterMs != null)
            .map((s) => FlSpot(s.secondsElapsed, s.jitterMs!))
            .toList();
      } else if (widget.isBufferbloat) {
        secondarySpots = widget.samples
            .where((s) => s.pingRttMs != null)
            .map((s) => FlSpot(s.secondsElapsed, s.pingRttMs!))
            .toList();
      }
    }

    final hasSecondary = secondarySpots.isNotEmpty;
    final secondaryLabel = widget.isUdp ? 'Jitter (ms)' : 'Ping RTT (ms)';

    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 14, right: 20, left: 10, bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.area_chart, size: 14, color: AppTheme.primaryLight),
              const SizedBox(width: 8),
              const Text(
                'LIVE BANDWIDTH & LATENCY TREND',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              // Throughput legend
              _legendDot(AppTheme.primaryLight, 'Throughput (Mbps)'),
              if (widget.isUdp || widget.isBufferbloat) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => setState(
                      () => _showSecondaryMetric = !_showSecondaryMetric),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: _legendDot(
                      _showSecondaryMetric ? AppTheme.warning : Colors.white24,
                      secondaryLabel,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: widget.samples.length.toDouble() > 10
                    ? widget.samples.length.toDouble()
                    : 10,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: maxY > 200 ? (maxY / 4).roundToDouble() : 50,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFF262626),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => const FlLine(
                    color: Color(0xFF262626),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(1)}G'
                                : '${value.toInt()}M',
                            style: AppTheme.monoStyle(
                              fontSize: 9.5,
                              color: Colors.white38,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        if (value % 2 == 0 || value == 1) {
                          return Text(
                            '${value.toInt()}s',
                            style: AppTheme.monoStyle(
                              fontSize: 9.5,
                              color: Colors.white38,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppTheme.border),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF22272E),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((barSpot) {
                        final isPrimary = barSpot.barIndex == 0;
                        return LineTooltipItem(
                          isPrimary
                              ? '${barSpot.y.toStringAsFixed(1)} Mbps'
                              : '${barSpot.y.toStringAsFixed(2)} ${widget.isUdp ? 'ms jitter' : 'ms ping'}',
                          AppTheme.monoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPrimary
                                ? AppTheme.primaryLight
                                : AppTheme.warning,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // 1. Throughput line with gradient area fill
                  LineChartBarData(
                    spots: throughputSpots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppTheme.primaryLight,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.35),
                          AppTheme.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  // 2. Secondary Latency/Jitter line (if enabled)
                  if (hasSecondary)
                    LineChartBarData(
                      spots: secondarySpots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: AppTheme.warning,
                      barWidth: 2.0,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color == Colors.white24 ? Colors.white30 : Colors.white70,
          ),
        ),
      ],
    );
  }
}
