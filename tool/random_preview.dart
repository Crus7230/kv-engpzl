import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/features/progress/progress.dart';

/// Isolated debug progress. Production saves and onboarding are untouched.
void main() {
  if (!kDebugMode) throw StateError('The random-board preview is debug-only.');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MathAdventureApp(
      repository: ProgressRepository(
        _RandomPreviewStore(),
        initialFactory: () => SaveEnvelopeV1(
          completedStageIds: const {'r01-c01-s01'},
          unlockedStageIds: const {'r01-c01-s01', 'r01-c01-s02'},
          playerCharacterId: 'CHAR_D',
          onboardingCompleted: true,
          unlockedCharacterIds: const {'CHAR_D'},
        ),
      ),
    ),
  );
}

class _RandomPreviewStore implements KeyValueSaveStore {
  final _delegate = SharedPreferencesSaveStore();
  @override
  Future<String?> read(String key) => _delegate.read('random-v5-preview.$key');
  @override
  Future<void> write(String key, String value) =>
      _delegate.write('random-v5-preview.$key', value);
}
