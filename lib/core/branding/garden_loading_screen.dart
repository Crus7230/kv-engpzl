import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'garden_brand_mark.dart';

/// A finite entrance animation; the caller controls when preparation is done.
class GardenLoadingScreen extends StatefulWidget {
  const GardenLoadingScreen({
    super.key,
    required this.status,
    this.reduceMotion = false,
  });

  final String status;
  final bool reduceMotion;

  @override
  State<GardenLoadingScreen> createState() => _GardenLoadingScreenState();
}

class _GardenLoadingScreenState extends State<GardenLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(GardenLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  void _updateMotion() {
    _reduceMotion =
        widget.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _entrance.value = 1;
    } else if (!_started) {
      _entrance.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.canvasTop, Color(0xFFEAF5ED)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 560;
            final compact = constraints.maxHeight < 400;
            final padding = compact ? 16.0 : 28.0;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.outline),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C4931A9),
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(compact ? 22 : 32),
                          child: horizontal
                              ? Row(
                                  children: [
                                    _mark(compact ? 120 : 160),
                                    const SizedBox(width: 30),
                                    Expanded(child: _message(context, compact)),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _mark(compact ? 104 : 136),
                                    const SizedBox(height: 24),
                                    _message(context, compact),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _mark(double size) => AnimatedBuilder(
    animation: _entrance,
    child: GardenBrandMark(size: size),
    builder: (context, child) {
      final progress = Curves.easeOutCubic.transform(_entrance.value);
      return Transform.translate(
        offset: Offset(0, 8 * (1 - progress)),
        child: Transform.scale(scale: 0.94 + 0.06 * progress, child: child),
      );
    },
  );

  Widget _message(BuildContext context, bool compact) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '일곱 수식 정원',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'KV 수학탐험대',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: compact ? 23 : 28,
          height: 1.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '작은 풀이가 정원을 자라게 해요',
        style: TextStyle(color: AppColors.mutedInk, fontSize: 14, height: 1.4),
      ),
      SizedBox(height: compact ? 18 : 26),
      Semantics(
        liveRegion: true,
        label: widget.status,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const _SeedIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: Text(
                        widget.status,
                        key: ValueKey(widget.status),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _SeedIndicator extends StatelessWidget {
  const _SeedIndicator();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final color in const [
        AppColors.primary,
        AppColors.success,
        AppColors.accent,
      ])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const SizedBox(width: 6, height: 10),
          ),
        ),
    ],
  );
}
