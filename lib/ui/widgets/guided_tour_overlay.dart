import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class GuidedTourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final FutureOr<void> Function()? onStepEnter;

  const GuidedTourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.onStepEnter,
  });
}

class GuidedTourOverlay extends StatefulWidget {
  final List<GuidedTourStep> steps;
  final VoidCallback onFinish;
  final Widget child;
  final bool isActive;
  final GlobalKey? exitPassThroughKey;

  const GuidedTourOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    required this.child,
    required this.isActive,
    this.exitPassThroughKey,
  });

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay> {
  int _currentIndex = 0;
  Rect? _targetRect;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _activateStep(0);
    }
  }

  @override
  void didUpdateWidget(covariant GuidedTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _activateStep(0);
    } else if (!widget.isActive && oldWidget.isActive) {
      setState(() {
        _targetRect = null;
        _currentIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _activateStep(int index) async {
    if (index < 0 || index >= widget.steps.length) return;
    setState(() {
      _currentIndex = index;
    });

    final step = widget.steps[index];
    if (step.onStepEnter != null) {
      await step.onStepEnter!();
    }

    if (!mounted || !widget.isActive) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      _measureTarget();
      _focusNode.requestFocus();
    });
  }

  void _measureTarget() {
    final step = widget.steps[_currentIndex];
    final targetContext = step.targetKey.currentContext;
    if (targetContext == null) {
      setState(() => _targetRect = null);
      return;
    }
    final renderBox = targetContext.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || overlayBox == null) {
      setState(() => _targetRect = null);
      return;
    }
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    setState(() {
      _targetRect = (topLeft & renderBox.size).inflate(6);
    });
  }

  void _nextStep() {
    if (_currentIndex + 1 < widget.steps.length) {
      _activateStep(_currentIndex + 1);
    } else {
      widget.onFinish();
    }
  }

  void _prevStep() {
    if (_currentIndex > 0) {
      _activateStep(_currentIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || widget.steps.isEmpty) {
      return widget.child;
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onFinish();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _nextStep();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prevStep();
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          final step = widget.steps[_currentIndex];
          final isLast = _currentIndex == widget.steps.length - 1;

          return Stack(
            children: [
              widget.child,
              // Dimmed Spotlight Cutout Layer
              Positioned.fill(
                child: _SpotlightHitBlocker(
                  passThroughKey: widget.exitPassThroughKey,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // Block stray clicks outside controls
                    child: CustomPaint(
                      painter: _SpotlightPainter(
                        targetRect: _targetRect,
                        accentColor: AppTheme.accent,
                        highlightColor: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                ),
              ),
              // Floating Tooltip Card
              _buildTooltipCard(screenSize, step, isLast),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTooltipCard(Size screenSize, GuidedTourStep step, bool isLast) {
    const double margin = 16.0;
    const double estimatedCardHeight = 220.0;
    final double cardWidth = math.min(
      440.0,
      math.max(260.0, screenSize.width - margin * 2),
    );

    double left = (screenSize.width - cardWidth) / 2;
    double top = (screenSize.height - estimatedCardHeight) / 2;

    if (_targetRect != null) {
      final rect = _targetRect!;
      left = rect.left.clamp(
        margin,
        math.max(margin, screenSize.width - cardWidth - margin),
      );

      final spaceBelow = screenSize.height - rect.bottom;
      final spaceAbove = rect.top;

      if (spaceBelow >= estimatedCardHeight + margin) {
        top = rect.bottom + 12;
      } else if (spaceAbove >= estimatedCardHeight + margin) {
        top = rect.top - estimatedCardHeight - 12;
      } else {
        // Target is a large full-height panel: place card inside top-right or center
        top = math.max(margin + 60, rect.top + 24);
        left = math
            .min(
              rect.right - cardWidth - 24,
              screenSize.width - cardWidth - margin,
            )
            .clamp(
              margin,
              math.max(margin, screenSize.width - cardWidth - margin),
            );
      }

      top = top.clamp(
        margin,
        math.max(margin, screenSize.height - estimatedCardHeight - margin),
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: cardWidth,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: AppTheme.isDark ? 0.45 : 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'DEMO WALKTHROUGH • STEP ${_currentIndex + 1} OF ${widget.steps.length}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.monoFont,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.isDark
                              ? AppTheme.primaryLight
                              : AppTheme.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onFinish,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onFinish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.warning,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 30),
                    ),
                    child: const Text(
                      'End Demo',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Flexible(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_currentIndex > 0)
                          OutlinedButton(
                            onPressed: _prevStep,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: BorderSide(color: AppTheme.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 30),
                            ),
                            child: const Text('Back', style: TextStyle(fontSize: 11)),
                          ),
                        FilledButton.icon(
                          onPressed: _nextStep,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                isLast ? AppTheme.success : AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 30),
                          ),
                          icon: Icon(
                            isLast
                                ? Icons.check_circle_outline
                                : Icons.arrow_forward,
                            size: 14,
                          ),
                          label: Text(
                            isLast ? 'Finish & Clear' : 'Next',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final Color accentColor;
  final Color highlightColor;

  _SpotlightPainter({
    required this.targetRect,
    required this.accentColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawPath(fullPath, dimPaint);
      return;
    }

    final rrect = RRect.fromRectAndRadius(
      targetRect!,
      const Radius.circular(8),
    );
    final cutoutPath = Path()..addRRect(rrect);
    final combinedPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cutoutPath,
    );

    canvas.drawPath(combinedPath, dimPaint);

    // Draw glowing accent border around the spotlight cutout
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect, glowPaint);

    final borderPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.highlightColor != highlightColor;
}

class _SpotlightHitBlocker extends SingleChildRenderObjectWidget {
  const _SpotlightHitBlocker({
    required Widget child,
    this.passThroughKey,
  }) : super(child: child);

  final GlobalKey? passThroughKey;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSpotlightHitBlocker(passThroughKey: passThroughKey);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSpotlightHitBlocker renderObject,
  ) {
    renderObject.passThroughKey = passThroughKey;
  }
}

class _RenderSpotlightHitBlocker extends RenderProxyBox {
  _RenderSpotlightHitBlocker({this.passThroughKey});

  GlobalKey? passThroughKey;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final targetContext = passThroughKey?.currentContext;
    if (targetContext != null) {
      final targetBox = targetContext.findRenderObject() as RenderBox?;
      if (targetBox != null && targetBox.hasSize && targetBox.attached) {
        final targetTopLeft =
            targetBox.localToGlobal(Offset.zero, ancestor: this);
        final targetRect = targetTopLeft & targetBox.size;
        if (targetRect.contains(position)) {
          return false;
        }
      }
    }
    return super.hitTest(result, position: position);
  }
}
