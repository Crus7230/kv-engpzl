import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../managers/game_state_manager.dart';
import 'game_hud.dart';

class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.title,
    required this.stage,
    required this.state,
    this.stageLabel,
    this.textColor = Colors.white,
    this.badgeColor = const Color(0xFF2455D6),
    this.showStageChip = true,
  });

  final String title;
  final int stage;
  final GameStateManager state;
  final String? stageLabel;
  final Color textColor;
  final Color badgeColor;
  final bool showStageChip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: Icon(Icons.arrow_back_ios_new, color: textColor),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            GameHud(state: state, textColor: textColor),
          ],
        ),
        if (showStageChip) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              stageLabel ?? 'STAGE $stage',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
