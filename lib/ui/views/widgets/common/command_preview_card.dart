import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:net_bench/ui/theme/app_theme.dart';

class CommandPreviewCard extends StatefulWidget {
  const CommandPreviewCard({
    super.key,
    required this.command,
    this.title = 'Generated Command',
  });

  final String command;
  final String title;

  @override
  State<CommandPreviewCard> createState() => _CommandPreviewCardState();
}

class _CommandPreviewCardState extends State<CommandPreviewCard> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.command));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.commandBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, size: 14, color: AppTheme.primaryLight),
              const SizedBox(width: 8),
              Text(
                widget.title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _copy,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        _copied ? Icons.check : Icons.copy,
                        size: 12,
                        color: _copied ? AppTheme.success : Colors.white60,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? 'COPIED' : 'COPY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _copied ? AppTheme.success : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            widget.command,
            style: AppTheme.monoStyle(
              fontSize: 11.5,
              color: const Color(0xFFE6EDF3),
            ),
          ),
        ],
      ),
    );
  }
}
