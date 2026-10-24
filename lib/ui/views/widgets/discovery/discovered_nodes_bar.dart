import 'package:flutter/material.dart';
import 'package:net_bench/domain/models/discovered_node.dart';
import 'package:net_bench/ui/theme/app_theme.dart';

class DiscoveredNodesBar extends StatelessWidget {
  const DiscoveredNodesBar({
    super.key,
    required this.nodes,
    required this.isScanning,
    required this.onScanTriggered,
    required this.onNodeSelected,
    required this.currentTargetHost,
  });

  final List<DiscoveredNode> nodes;
  final bool isScanning;
  final VoidCallback onScanTriggered;
  final ValueChanged<DiscoveredNode> onNodeSelected;
  final String currentTargetHost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.radar,
            size: 14,
            color: isScanning ? AppTheme.primaryLight : Colors.white60,
          ),
          const SizedBox(width: 8),
          const Text(
            'SUBNET DISCOVERY',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          // Discovered Node Chips
          Expanded(
            child: nodes.isEmpty
                ? Text(
                    isScanning
                        ? 'Sweeping subnet for active iPerf3 servers (port 5201)...'
                        : 'No remote servers found. Click "Scan Subnet" to search LAN.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isScanning ? AppTheme.primaryLight : Colors.white38,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: nodes.map((node) {
                        final isSelected = node.ip == currentTargetHost;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => onNodeSelected(node),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withValues(alpha: 0.25)
                                    : AppTheme.surfaceHighest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    node.discoveryType == 'peer_beacon'
                                        ? Icons.hub
                                        : Icons.dns,
                                    size: 11,
                                    color: isSelected
                                        ? AppTheme.primaryLight
                                        : Colors.white60,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    node.displayName,
                                    style: AppTheme.monoStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ),
                                  if (node.latencyMs != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '${node.latencyMs}ms',
                                      style: AppTheme.monoStyle(
                                        fontSize: 9.5,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Trigger scan button
          SizedBox(
            height: 26,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: isScanning ? null : onScanTriggered,
              icon: isScanning
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.primaryLight,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 13),
              label: Text(
                isScanning ? 'SCANNING...' : 'SCAN SUBNET',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
