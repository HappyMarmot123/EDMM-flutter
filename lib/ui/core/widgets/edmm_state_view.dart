import 'package:flutter/material.dart';

import '../motion/edmm_motion.dart';
import '../themes/edmm_theme_extensions.dart';
import '../themes/edmm_theme_tokens.dart';
import 'edmm_surface.dart';

enum EdmmStateKind { loading, empty, searchEmpty, error }

class EdmmStateView extends StatefulWidget {
  const EdmmStateView({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be provided together.',
       );

  final EdmmStateKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<EdmmStateView> createState() => _EdmmStateViewState();
}

class _EdmmStateViewState extends State<EdmmStateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: EdmmMotion.ambient,
    );
    _pulseOpacity = Tween<double>(begin: 0.38, end: 0.72).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant EdmmStateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulse() {
    final shouldAnimate =
        widget.kind == EdmmStateKind.loading &&
        !EdmmMotion.reducedMotionOf(context);
    if (shouldAnimate) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }
    _pulseController
      ..stop()
      ..value = 0.5;
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.title.trim().isNotEmpty, 'EdmmStateView requires a title.');
    final announcement = <String>[
      widget.title.trim(),
      if (widget.message?.trim().isNotEmpty ?? false) widget.message!.trim(),
    ].join('. ');
    final content = widget.kind == EdmmStateKind.loading
        ? _StateSkeleton(opacity: _pulseOpacity)
        : _StateMessage(
            kind: widget.kind,
            title: widget.title,
            message: widget.message,
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: announcement,
      child: EdmmSurface(
        variant: EdmmSurfaceVariant.outlined,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final unpaddedHeight = constraints.maxHeight - (EdmmSpacing.xl * 2);
            final minContentHeight =
                constraints.hasBoundedHeight && unpaddedHeight > 0
                ? unpaddedHeight
                : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(EdmmSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ExcludeSemantics(child: content),
                      if (widget.onAction != null) ...<Widget>[
                        const SizedBox(height: EdmmSpacing.md),
                        TextButton(
                          onPressed: widget.onAction,
                          child: Text(widget.actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.kind,
    required this.title,
    required this.message,
  });

  final EdmmStateKind kind;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    final (icon, iconColor) = switch (kind) {
      EdmmStateKind.empty => (Icons.inbox_outlined, colors.brandSoft),
      EdmmStateKind.searchEmpty => (Icons.search_off, colors.brandSoft),
      EdmmStateKind.error => (Icons.error_outline, colors.error),
      EdmmStateKind.loading => (Icons.hourglass_empty, colors.textMuted),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: iconColor, size: 32),
        const SizedBox(height: EdmmSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: EdmmTypography.sectionTitle.copyWith(
            color: colors.textPrimary,
          ),
        ),
        if (message?.trim().isNotEmpty ?? false) ...<Widget>[
          const SizedBox(height: EdmmSpacing.xs),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: EdmmTypography.body.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _StateSkeleton extends StatelessWidget {
  const _StateSkeleton({required this.opacity});

  final Animation<double> opacity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    return SizedBox(
      key: const Key('edmm-state-skeleton'),
      width: 240,
      height: 96,
      child: FadeTransition(
        key: const Key('edmm-state-skeleton-pulse'),
        opacity: opacity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SkeletonBar(width: 152, height: 18, color: colors.surfaceRaised),
            const SizedBox(height: EdmmSpacing.sm),
            _SkeletonBar(width: 240, height: 12, color: colors.surfaceRaised),
            const SizedBox(height: EdmmSpacing.xs),
            _SkeletonBar(width: 184, height: 12, color: colors.surfaceRaised),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(EdmmRadii.small),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}
