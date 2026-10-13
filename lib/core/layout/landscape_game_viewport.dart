import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keep phone layouts intact; letterbox tall foldables instead of stretching
/// the map/board into a nearly square canvas. Values are logical pixels.
class LandscapeGameViewport extends StatelessWidget {
  const LandscapeGameViewport({required this.child, super.key});

  static const maximumHeight = 432.0;
  static const maximumWidth = 960.0;
  static const landscapeAspectRatio = 20 / 9;
  static const minimumPhoneAspectRatio = 16 / 9;
  static const frameKey = ValueKey('landscape-game-frame');

  final Widget child;

  static Size fit(Size available) {
    final width = math.min(available.width, maximumWidth);
    var height = math.min(available.height, maximumHeight);
    // A 16:9 low-resolution phone is not a tall foldable. Keep its scarce
    // vertical space; apply the 20:9 shape only to taller window proportions.
    if (available.height > 0 &&
        available.width / available.height < minimumPhoneAspectRatio) {
      height = math.min(height, width / landscapeAspectRatio);
    }
    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF122A30),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = fit(constraints.biggest);
          final media = MediaQuery.of(context);
          return Center(
            child: SizedBox(
              key: frameKey,
              width: size.width,
              height: size.height,
              child: MediaQuery(
                data: media.copyWith(
                  size: size,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                ),
                child: ClipRect(child: child),
              ),
            ),
          );
        },
      ),
    ),
  );
}
