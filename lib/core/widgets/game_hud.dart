import 'package:flutter/material.dart';

import '../managers/game_state_manager.dart';
import '../theme/app_theme.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.state,
    this.textColor = Colors.white,
  });

  final GameStateManager state;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.favorite, color: AppColors.error, size: 18),
        Text(
          ' ${state.hearts}',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.star, color: AppColors.secondary, size: 18),
        Text(
          ' ${state.stars}',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
