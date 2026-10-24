import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:net_bench/ui/theme/app_theme.dart';
import 'package:net_bench/ui/view_models/benchmark_view_model.dart';
import 'package:net_bench/ui/views/dialogs/installation_guide_dialog.dart';
import 'package:net_bench/ui/views/widgets/common/status_badge.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.viewModel});

  final BenchmarkViewModel viewModel;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(
      text: widget.viewModel.binaryInfo.path ?? '',
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickBinary() async {
    final res = await FilePicker.pickFiles(
      dialogTitle: 'Select iPerf3 Executable',
      type: FileType.custom,
      allowedExtensions: ['exe', ''],
    );

    if (res.isNotEmpty && res.first.path != null) {
      final picked = res.first.path!;
      setState(() {
        _pathController.text = picked;
      });
      await widget.viewModel.updateCustomBinaryPath(picked);
    }
  }

  Future<void> _confirmPurgeHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text(
          'Purge All History?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: const Text(
          'This action will permanently delete all historical benchmark runs from local database storage. This action cannot be undone.',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(fontSize: 11, color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('PURGE ALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.viewModel.clearAllHistory();
      Navigator.of(context).pop();
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
        width: 540,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppTheme.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'APPLICATION SETTINGS',
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
            const SizedBox(height: 16),
            const Text(
              'IPERF3 EXECUTABLE PATH',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    style: AppTheme.monoStyle(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'e.g. C:\\Program Files\\iperf3\\iperf3.exe',
                      hintStyle: const TextStyle(fontSize: 11, color: Colors.white24),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 13),
                        onPressed: () {
                          _pathController.clear();
                          widget.viewModel.updateCustomBinaryPath('');
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      widget.viewModel.updateCustomBinaryPath(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _pickBinary,
                  icon: const Icon(Icons.folder_open, size: 14),
                  label: const Text('BROWSE...', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Binary Status Pill & Version
            Row(
              children: [
                StatusBadge(
                  label: info.isAvailable ? 'INSTALLED & READY' : 'NOT FOUND',
                  color: info.isAvailable ? AppTheme.success : AppTheme.warning,
                  icon: info.isAvailable ? Icons.check_circle : Icons.warning_amber,
                ),
                if (info.version != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info.version!,
                      style: AppTheme.monoStyle(fontSize: 10.5, color: Colors.white60),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primaryLight,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => InstallationGuideDialog(
                        viewModel: widget.viewModel,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_for_offline, size: 14),
                  label: const Text('INSTALL GUIDE',
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            if (!info.isAvailable) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 15, color: AppTheme.primaryLight),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tip: On Windows, install in seconds via PowerShell: winget install iperf3',
                        style: TextStyle(fontSize: 10.5, color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => InstallationGuideDialog(
                            viewModel: widget.viewModel,
                          ),
                        );
                      },
                      child: const Text('VIEW GUIDE',
                          style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
            if (info.isOlderThan3191) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.security_update_warning, size: 16, color: AppTheme.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Security Advisory: Detected iPerf3 version is older than 3.19.1. Older versions contain known memory vulnerabilities (e.g. CVE-2023-38403) when running as a server. Upgrading is strongly recommended.',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Simulation / Demo Mode Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Demo / Simulation Mode',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Generate realistic real-time benchmark streaming data without requiring an external iPerf3 server.',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
              value: widget.viewModel.isDemoMode,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) {
                widget.viewModel.setDemoMode(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            // Clear History Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _confirmPurgeHistory,
                  icon: const Icon(Icons.delete_sweep, size: 14),
                  label: const Text('PURGE ALL HISTORY', style: TextStyle(fontSize: 11)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    widget.viewModel.updateCustomBinaryPath(_pathController.text);
                    Navigator.of(context).pop();
                  },
                  child: const Text('DONE', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
