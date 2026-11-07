import 'package:flutter/material.dart';
import 'package:net_bench/domain/models/network_adapter.dart';
import 'package:net_bench/ui/theme/app_theme.dart';
import 'package:net_bench/ui/view_models/server_view_model.dart';
import 'package:net_bench/ui/views/dialogs/installation_guide_dialog.dart';
import 'package:net_bench/ui/views/widgets/common/command_preview_card.dart';
import 'package:net_bench/ui/views/widgets/common/status_badge.dart';

class ServerMonitorCard extends StatefulWidget {
  const ServerMonitorCard({
    super.key,
    required this.serverVm,
    required this.binaryPath,
    this.isOlderThan3191 = false,
  });

  final ServerViewModel serverVm;
  final String? binaryPath;
  final bool isOlderThan3191;

  @override
  State<ServerMonitorCard> createState() => _ServerMonitorCardState();
}

class _ServerMonitorCardState extends State<ServerMonitorCard> {
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _portController =
        TextEditingController(text: widget.serverVm.port.toString());
  }

  @override
  void didUpdateWidget(covariant ServerMonitorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.serverVm.port.toString() != _portController.text &&
        !widget.serverVm.isRunning) {
      _portController.text = widget.serverVm.port.toString();
    }
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverVm = widget.serverVm;
    final state = serverVm.state;
    final isRunning = state.isRunning;

    final bindArg =
        serverVm.bindAddress != '0.0.0.0' ? ' -B ${serverVm.bindAddress}' : '';
    final oneOffArg = serverVm.oneOff ? ' -1' : '';
    final cmd =
        '${widget.binaryPath ?? 'iperf3'} -s -p ${serverVm.port}$bindArg$oneOffArg';

    final adapterItems = serverVm.availableAdapters.toList();
    if (!adapterItems.any((a) => a.ipAddress == serverVm.bindAddress)) {
      adapterItems.insert(
        0,
        NetworkAdapter(name: 'Custom', ipAddress: serverVm.bindAddress),
      );
    }

    final selectedAdapter = adapterItems.firstWhere(
      (a) => a.ipAddress == serverVm.bindAddress,
      orElse: () => NetworkAdapter(
          name: 'Interface', ipAddress: serverVm.bindAddress),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Controls
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.dns, size: 16, color: AppTheme.primaryLight),
                const SizedBox(width: 8),
                const Text(
                  'LOCAL IPERF3 SERVER DAEMON',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(
                  label: isRunning
                      ? (state.isSimulated ? 'LISTENING (DEMO)' : 'LISTENING')
                      : 'STOPPED',
                  color: isRunning ? AppTheme.success : Colors.white38,
                  icon: isRunning ? Icons.check_circle : Icons.stop_circle_outlined,
                ),
                if (widget.isOlderThan3191) ...[
                  const SizedBox(width: 8),
                  const StatusBadge(
                    label: 'iPerf < 3.19.1 (Vulnerable)',
                    color: AppTheme.warning,
                    icon: Icons.security_update_warning,
                  ),
                ],
                const SizedBox(width: 24),
                // Bind Address Dropdown & Refresh
                      Container(
                        height: 32,
                        padding: const EdgeInsets.only(left: 8, right: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHigh,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.settings_ethernet,
                                size: 14, color: AppTheme.primaryLight),
                            const SizedBox(width: 6),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: serverVm.bindAddress,
                                isDense: true,
                                style: AppTheme.monoStyle(fontSize: 11),
                                dropdownColor: AppTheme.surfaceHigh,
                                onChanged: isRunning
                                    ? null
                                    : (val) {
                                        if (val != null) serverVm.setBindAddress(val);
                                      },
                                items: adapterItems.map((adapter) {
                                  return DropdownMenuItem<String>(
                                    value: adapter.ipAddress,
                                    child: Text(
                                      adapter.displayName,
                                      style: AppTheme.monoStyle(fontSize: 11),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh,
                                  size: 13, color: Colors.white60),
                              tooltip: 'Refresh network adapters',
                              padding: EdgeInsets.zero,
                              constraints:
                                  const BoxConstraints(minWidth: 24, minHeight: 24),
                              visualDensity: VisualDensity.compact,
                              onPressed:
                                  isRunning ? null : () => serverVm.loadAdapters(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // One-Off Toggle
                      Tooltip(
                        message: 'Exit after handling a single benchmark test (-1)',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: serverVm.oneOff,
                              onChanged: isRunning
                                  ? null
                                  : (val) {
                                      if (val != null) serverVm.setOneOff(val);
                                    },
                              visualDensity: VisualDensity.compact,
                            ),
                            const Text(
                              'One-off (-1)',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Port Input
                      SizedBox(
                        width: 90,
                        height: 32,
                        child: TextField(
                          enabled: !isRunning,
                          decoration: const InputDecoration(
                            labelText: 'PORT',
                            labelStyle: TextStyle(fontSize: 10),
                            isDense: true,
                          ),
                          style: AppTheme.monoStyle(fontSize: 11),
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final p = int.tryParse(val);
                            if (p != null) serverVm.setPort(p);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Start / Stop Toggle Button
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              isRunning ? AppTheme.error : AppTheme.success,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => serverVm.toggleServer(),
                        icon: Icon(
                          isRunning ? Icons.stop : Icons.play_arrow,
                          size: 15,
                        ),
                        label: Text(
                          isRunning ? 'STOP SERVER' : 'START SERVER',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
          // Error Alert Banner
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Dynamic Interface / Caution Banner
          if (serverVm.bindAddress == '0.0.0.0') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppTheme.warning),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Binding to 0.0.0.0 exposes the server port to all devices across all network interfaces without authentication.',
                      style: TextStyle(fontSize: 10.5, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 14, color: AppTheme.primaryLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bound exclusively to ${selectedAdapter.displayName}. Only traffic arriving on this network adapter will be accepted.',
                      style: const TextStyle(
                          fontSize: 10.5, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Command Preview
          CommandPreviewCard(
            command: cmd,
            title: 'Server Daemon Command',
          ),
          const SizedBox(height: 12),
          // Active Clients Pill
          if (state.activeClients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Text(
                    'CONNECTED CLIENTS: ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                    ),
                  ),
                  ...state.activeClients.map((client) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Text(
                            client,
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              color: AppTheme.primaryLight,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          // Terminal Logs
          const Text(
            'DAEMON LOG STREAM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: state.logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dns_outlined,
                              size: 28, color: Colors.white24),
                          const SizedBox(height: 8),
                          Text(
                            widget.binaryPath != null
                                ? 'Server daemon is idle. Click "START SERVER" to listen for incoming tests.'
                                : 'Click "START SERVER" to run a simulated server daemon, or install native iPerf3 for real testing.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white38),
                          ),
                          if (widget.binaryPath == null) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => InstallationGuideDialog.show(context),
                              icon: const Icon(Icons.download, size: 14),
                              label: const Text('HOW TO INSTALL IPERF3',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryLight,
                                side: const BorderSide(color: AppTheme.primary),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.logs.length,
                      itemBuilder: (context, idx) {
                        final line = state.logs[idx];
                        return Text(
                          line,
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            color: line.startsWith('[ERROR]')
                                ? AppTheme.error
                                : (line.startsWith('[SERVER')
                                    ? AppTheme.primaryLight
                                    : const Color(0xFFC9D1D9)),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
