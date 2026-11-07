import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/ui/theme/app_theme.dart';
import 'package:net_bench/ui/views/widgets/common/status_badge.dart';

class HistoryDataTable extends StatefulWidget {
  const HistoryDataTable({
    super.key,
    required this.runs,
    required this.selectedComparisonIds,
    required this.onToggleComparison,
    required this.selectedInspectorRecord,
    required this.onSelectInspectorRecord,
    required this.onDeleteRun,
    required this.onExportCsv,
    required this.onExportJson,
  });

  final List<BenchmarkResult> runs;
  final Set<String> selectedComparisonIds;
  final ValueChanged<String> onToggleComparison;
  final BenchmarkResult? selectedInspectorRecord;
  final ValueChanged<BenchmarkResult> onSelectInspectorRecord;
  final ValueChanged<String> onDeleteRun;
  final ValueChanged<BenchmarkResult> onExportCsv;
  final ValueChanged<BenchmarkResult> onExportJson;

  @override
  State<HistoryDataTable> createState() => _HistoryDataTableState();
}

class _HistoryDataTableState extends State<HistoryDataTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.runs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.history_toggle_off,
                size: 48,
                color: Colors.white24,
              ),
              SizedBox(height: 12),
              Text(
                'No historical benchmark runs found',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Completed runs will automatically be stored in local SQLite database.',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1100,
              child: Column(
                children: [
                  // Table Header
                  _buildHeaderRow(),
                  const Divider(height: 1),
                  // Table Rows
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: _verticalController,
                        itemCount: widget.runs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: AppTheme.border),
                        itemBuilder: (context, index) {
                          final run = widget.runs[index];
                          final isInspecting =
                              widget.selectedInspectorRecord?.id == run.id;
                          final isCompared =
                              widget.selectedComparisonIds.contains(run.id);

                          return _buildDataRow(
                            run: run,
                            isInspecting: isInspecting,
                            isCompared: isCompared,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      height: 32,
      color: AppTheme.surfaceHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(
        children: [
          SizedBox(width: 32, child: Center(child: Text('#', style: _headerStyle))),
          SizedBox(width: 145, child: Text('TIMESTAMP', style: _headerStyle)),
          SizedBox(width: 140, child: Text('PROFILE', style: _headerStyle)),
          SizedBox(width: 140, child: Text('TARGET', style: _headerStyle)),
          SizedBox(width: 90, child: Text('PROTO / STR', style: _headerStyle)),
          SizedBox(width: 110, child: Text('AVG BITRATE', style: _headerStyle)),
          SizedBox(width: 100, child: Text('PEAK', style: _headerStyle)),
          SizedBox(width: 110, child: Text('JITTER / LOSS', style: _headerStyle)),
          SizedBox(width: 75, child: Text('RETR', style: _headerStyle)),
          SizedBox(width: 80, child: Text('STATUS', style: _headerStyle)),
          SizedBox(width: 58, child: Center(child: Text('ACTIONS', style: _headerStyle))),
        ],
      ),
    );
  }

  Widget _buildDataRow({
    required BenchmarkResult run,
    required bool isInspecting,
    required bool isCompared,
  }) {
    Color rowBg = Colors.transparent;
    if (isInspecting) {
      rowBg = AppTheme.primary.withValues(alpha: 0.15);
    } else if (isCompared) {
      rowBg = AppTheme.primaryLight.withValues(alpha: 0.08);
    }

    return InkWell(
      onTap: () => widget.onSelectInspectorRecord(run),
      child: Container(
        height: 34,
        color: rowBg,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Compare Checkbox
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isCompared,
                onChanged: (_) => widget.onToggleComparison(run.id),
                visualDensity: VisualDensity.compact,
                activeColor: AppTheme.primary,
              ),
            ),
            // Timestamp
            SizedBox(
              width: 145,
              child: Text(
                _dateFormat.format(run.timestamp),
                style: AppTheme.monoStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
            // Profile Name
            SizedBox(
              width: 140,
              child: Text(
                run.profileName,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Target
            SizedBox(
              width: 140,
              child: Text(
                '${run.targetHost}:${run.port}',
                style: AppTheme.monoStyle(
                  fontSize: 11,
                  color: AppTheme.primaryLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Protocol & Streams
            SizedBox(
              width: 90,
              child: Text(
                '${run.protocol.toUpperCase()} (${run.streams}P)',
                style: AppTheme.monoStyle(
                  fontSize: 11,
                  color: Colors.white60,
                ),
              ),
            ),
            // Avg Bitrate
            SizedBox(
              width: 110,
              child: Text(
                run.avgThroughputMbps >= 1000
                    ? '${(run.avgThroughputMbps / 1000).toStringAsFixed(2)} Gbps'
                    : '${run.avgThroughputMbps.toStringAsFixed(1)} Mbps',
                style: AppTheme.monoStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // Peak
            SizedBox(
              width: 100,
              child: Text(
                run.peakThroughputMbps >= 1000
                    ? '${(run.peakThroughputMbps / 1000).toStringAsFixed(2)} Gbps'
                    : '${run.peakThroughputMbps.toStringAsFixed(1)} Mbps',
                style: AppTheme.monoStyle(
                  fontSize: 11,
                  color: AppTheme.success,
                ),
              ),
            ),
            // Jitter / Loss
            SizedBox(
              width: 110,
              child: Text(
                run.isUdp
                    ? '${run.jitterMs?.toStringAsFixed(2) ?? '-'}ms / ${run.lossPercent?.toStringAsFixed(1) ?? '0'}%'
                    : (run.bufferbloatDeltaMs != null
                        ? '+${run.bufferbloatDeltaMs!.toStringAsFixed(1)}ms RTT'
                        : '-'),
                style: AppTheme.monoStyle(
                  fontSize: 10.5,
                  color: run.isUdp ? AppTheme.warning : Colors.white54,
                ),
              ),
            ),
            // Retransmits
            SizedBox(
              width: 75,
              child: Text(
                run.retransmits.toString(),
                style: AppTheme.monoStyle(
                  fontSize: 11,
                  color: run.retransmits > 5 ? AppTheme.warning : Colors.white60,
                ),
              ),
            ),
            // Status Badge
            SizedBox(
              width: 80,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  label: run.status,
                  color: run.isSuccessful
                      ? AppTheme.success
                      : (run.status == 'aborted'
                          ? AppTheme.warning
                          : AppTheme.error),
                ),
              ),
            ),
            // Actions Popup Menu
            SizedBox(
              width: 58,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 14, color: Colors.white60),
                padding: EdgeInsets.zero,
                color: AppTheme.surfaceHigh,
                onSelected: (val) {
                  if (val == 'csv') widget.onExportCsv(run);
                  if (val == 'json') widget.onExportJson(run);
                  if (val == 'delete') widget.onDeleteRun(run.id);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'csv',
                    height: 28,
                    child: Text('Export CSV', style: TextStyle(fontSize: 11)),
                  ),
                  const PopupMenuItem(
                    value: 'json',
                    height: 28,
                    child: Text('Export JSON', style: TextStyle(fontSize: 11)),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 28,
                    child: Text('Delete Run',
                        style: TextStyle(fontSize: 11, color: AppTheme.error)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    color: Colors.white70,
  );
}
