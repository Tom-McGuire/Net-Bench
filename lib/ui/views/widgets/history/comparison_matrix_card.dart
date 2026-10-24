import 'package:flutter/material.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/ui/theme/app_theme.dart';

class ComparisonMatrixCard extends StatelessWidget {
  const ComparisonMatrixCard({
    super.key,
    required this.runs,
    required this.onClearComparison,
  });

  final List<BenchmarkResult> runs;
  final VoidCallback onClearComparison;

  @override
  Widget build(BuildContext context) {
    if (runs.length < 2) return const SizedBox.shrink();

    final base = runs[0];
    final comp = runs[1];

    final throughputDelta = comp.avgThroughputMbps - base.avgThroughputMbps;
    final throughputPct = base.avgThroughputMbps > 0
        ? (throughputDelta / base.avgThroughputMbps) * 100
        : 0.0;

    final jitterDelta = (comp.jitterMs != null && base.jitterMs != null)
        ? comp.jitterMs! - base.jitterMs!
        : null;

    final retransDelta = comp.retransmits - base.retransmits;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows, size: 16, color: AppTheme.primaryLight),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'COMPARISON MATRIX: ${base.profileName} (${base.targetHost}) vs ${comp.profileName} (${comp.targetHost})',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _deltaBadge(
                    label: 'THROUGHPUT',
                    value:
                        '${throughputDelta >= 0 ? '+' : ''}${throughputDelta.toStringAsFixed(1)} Mbps (${throughputPct >= 0 ? '+' : ''}${throughputPct.toStringAsFixed(1)}%)',
                    isPositiveGood: true,
                    isPositive: throughputDelta >= 0,
                  ),
                  const SizedBox(width: 12),
                  if (jitterDelta != null) ...[
                    _deltaBadge(
                      label: 'JITTER',
                      value:
                          '${jitterDelta >= 0 ? '+' : ''}${jitterDelta.toStringAsFixed(2)} ms',
                      isPositiveGood: false,
                      isPositive: jitterDelta > 0,
                    ),
                    const SizedBox(width: 12),
                  ],
                  _deltaBadge(
                    label: 'RETRANSMITS',
                    value: '${retransDelta >= 0 ? '+' : ''}$retransDelta',
                    isPositiveGood: false,
                    isPositive: retransDelta > 0,
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: Colors.white60,
            ),
            onPressed: onClearComparison,
            icon: const Icon(Icons.close, size: 13),
            label: const Text('CLEAR COMPARISON', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _deltaBadge({
    required String label,
    required String value,
    required bool isPositiveGood,
    required bool isPositive,
  }) {
    final isGood = isPositiveGood ? isPositive : !isPositive;
    final color = isGood ? AppTheme.success : AppTheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: AppTheme.monoStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
