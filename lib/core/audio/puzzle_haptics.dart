import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_settings.dart';

Future<void> playPuzzleHaptic(PuzzleHaptic cue) async {
  if (kIsWeb) return; // Browser preview is not proof of device vibration.
  switch (cue) {
    case PuzzleHaptic.select:
      await HapticFeedback.selectionClick();
    case PuzzleHaptic.swap:
    case PuzzleHaptic.match:
      await HapticFeedback.lightImpact();
    case PuzzleHaptic.fragment:
      await HapticFeedback.mediumImpact();
    case PuzzleHaptic.success:
      await HapticFeedback.heavyImpact();
  }
}
