import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:net_bench/ui/theme/app_theme.dart';
import 'package:net_bench/ui/view_models/benchmark_view_model.dart';
import 'package:net_bench/ui/views/widgets/common/status_badge.dart';

class InstallationGuideDialog extends StatefulWidget {
  const InstallationGuideDialog({super.key, required this.viewModel});

  final BenchmarkViewModel viewModel;

  static Future<void> show(BuildContext context, [BenchmarkViewModel? vm]) {
    final viewModel = vm ?? Provider.of<BenchmarkViewModel>(context, listen: false);
    return showDialog(
      context: context,
      builder: (_) => InstallationGuideDialog(viewModel: viewModel),
    );
  }

  @override
  State<InstallationGuideDialog> createState() =>
      _InstallationGuideDialogState();
}

class _InstallationGuideDialogState extends State<InstallationGuideDialog> {
  int _selectedOsIndex = Platform.isWindows
      ? 0
      : (Platform.isMacOS ? 1 : 2); // 0: Windows, 1: macOS, 2: Linux
  String? _copiedCommand;
  bool _isChecking = false;

  void _copy(String command) {
    Clipboard.setData(ClipboardData(text: command));
    setState(() {
      _copiedCommand = command;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $command'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surfaceHigh,
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _copiedCommand == command) {
        setState(() {
          _copiedCommand = null;
        });
      }
    });
  }

  Future<void> _checkBinary() async {
    setState(() {
      _isChecking = true;
    });
    await widget.viewModel.repository.checkBinary();
    if (widget.viewModel.repository.binaryInfo.isAvailable) {
      widget.viewModel.setDemoMode(false);
    }
    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.viewModel.binaryInfo;

    return Dialog(
      backgroundColor: AppTheme.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.download_for_offline,
                    size: 20, color: AppTheme.primaryLight),
                const SizedBox(width: 8),
                const Text(
                  'HOW TO INSTALL IPERF3',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Current Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  StatusBadge(
                    label: info.isAvailable ? 'IPERF3 DETECTED' : 'NOT DETECTED',
                    color: info.isAvailable
                        ? AppTheme.success
                        : AppTheme.warning,
                    icon: info.isAvailable
                        ? Icons.check_circle
                        : Icons.warning_amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      info.isAvailable
                          ? (info.path ?? 'Available in system PATH')
                          : 'Running in simulated demo mode. Install iPerf3 to benchmark physical network interfaces.',
                      style: AppTheme.monoStyle(
                        fontSize: 10.5,
                        color: info.isAvailable
                            ? AppTheme.success
                            : Colors.white60,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryLight,
                      side: const BorderSide(color: AppTheme.border),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: _isChecking ? null : _checkBinary,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 13),
                    label: const Text('RE-CHECK',
                        style: TextStyle(fontSize: 10.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // OS Selector Tabs
            Row(
              children: [
                _buildOsTab(0, 'Windows', Icons.window),
                const SizedBox(width: 8),
                _buildOsTab(1, 'macOS', Icons.apple),
                const SizedBox(width: 8),
                _buildOsTab(2, 'Linux', Icons.terminal),
              ],
            ),
            const SizedBox(height: 16),
            // Instructions for selected OS
            if (_selectedOsIndex == 0) _buildWindowsInstructions(),
            if (_selectedOsIndex == 1) _buildMacInstructions(),
            if (_selectedOsIndex == 2) _buildLinuxInstructions(),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'After installing, click "RE-CHECK" above or restart the app.',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CLOSE', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOsTab(int index, String title, IconData icon) {
    final isSelected = _selectedOsIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedOsIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.primaryLight : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowsInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Method 1: WinGet (Recommended)
        _buildMethodCard(
          badge: 'RECOMMENDED / FASTEST',
          title: 'Method 1: Windows Package Manager (winget)',
          description:
              'Open Windows PowerShell or Command Prompt and run the following command:',
          command: 'winget install iperf3',
          notes:
              '• Installs in seconds without requiring manual zip downloads.\n• Installs to system PATH so net-bench auto-detects it immediately.',
        ),
        const SizedBox(height: 10),
        // Method 2: Chocolatey
        _buildMethodCard(
          badge: 'ALTERNATIVE',
          title: 'Method 2: Chocolatey',
          description:
              'If you use the Chocolatey package manager, run in an administrative terminal:',
          command: 'choco install iperf3',
        ),
        const SizedBox(height: 10),
        // Method 3: Manual Download
        _buildMethodCard(
          badge: 'MANUAL',
          title: 'Method 3: Standalone ZIP Download',
          description:
              'Download the Windows 64-bit standalone package from iperf.fr or GitHub:',
          command: 'https://iperf.fr/iperf-download.php',
          isUrl: true,
          notes:
              '• Extract iperf3.exe and cygwin1.dll to C:\\Program Files\\iperf3\\\n• net-bench checks Program Files automatically on startup.',
        ),
      ],
    );
  }

  Widget _buildMacInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMethodCard(
          badge: 'RECOMMENDED',
          title: 'Homebrew (macOS)',
          description: 'Open Terminal and install iPerf3 via Homebrew:',
          command: 'brew install iperf3',
          notes:
              '• Installs to /opt/homebrew/bin/iperf3 (Apple Silicon) or /usr/local/bin/iperf3 (Intel).\n• Automatically auto-detected by net-bench.',
        ),
      ],
    );
  }

  Widget _buildLinuxInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMethodCard(
          badge: 'UBUNTU / DEBIAN',
          title: 'Debian / Ubuntu / Raspberry Pi OS',
          description: 'Run in terminal:',
          command: 'sudo apt update && sudo apt install iperf3 -y',
        ),
        const SizedBox(height: 10),
        _buildMethodCard(
          badge: 'FEDORA / RHEL',
          title: 'Fedora / CentOS / Red Hat',
          description: 'Run in terminal:',
          command: 'sudo dnf install iperf3 -y',
        ),
        const SizedBox(height: 10),
        _buildMethodCard(
          badge: 'ARCH LINUX',
          title: 'Arch Linux / Manjaro',
          description: 'Run in terminal:',
          command: 'sudo pacman -S iperf3',
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required String badge,
    required String title,
    required String description,
    required String command,
    bool isUrl = false,
    String? notes,
  }) {
    final isCopied = _copiedCommand == command;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badge.contains('RECOMMENDED')
                      ? AppTheme.success.withValues(alpha: 0.2)
                      : AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: badge.contains('RECOMMENDED')
                        ? AppTheme.success
                        : AppTheme.primaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          // Command Bar with Copy Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    command,
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      color: isUrl ? AppTheme.primaryLight : const Color(0xFF58A6FF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copy(command),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCopied
                          ? AppTheme.success.withValues(alpha: 0.2)
                          : AppTheme.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            isCopied ? AppTheme.success : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCopied ? Icons.check : Icons.copy,
                          size: 12,
                          color: isCopied ? AppTheme.success : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCopied ? 'COPIED' : 'COPY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCopied ? AppTheme.success : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (notes != null) ...[
            const SizedBox(height: 6),
            Text(
              notes,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white38,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
