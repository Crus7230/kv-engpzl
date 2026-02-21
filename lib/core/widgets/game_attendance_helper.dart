import 'package:flutter/material.dart';

import '../managers/game_state_manager.dart';
import 'attendance_checkin_dialog.dart';

Future<void> claimAttendanceAndShowDialog(
  BuildContext context,
  GameStateManager gameState,
) async {
  final attendance = await gameState.claimAttendanceIfNeeded();
  if (attendance == null || !attendance.claimed) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AttendanceCheckinDialog(
      streak: attendance.streak,
      starsGained: attendance.starsGained,
      today: DateTime.now(),
      attendanceHistory: gameState.attendanceHistory,
      animateTodayStamp: true,
    ),
  );
}

