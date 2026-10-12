import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/progress/progress.dart';

/// Debug-only entry. Imported R1 progress opens R2 for visual/manual review.
/// Production main.dart, onboarding and real save keys are not changed.
void main() {
  if (!kDebugMode) throw StateError('The R2 preview is debug-only.');
  WidgetsFlutterBinding.ensureInitialized();
  final completed = initialCampaign.regions.first.chapters
      .take(3)
      .expand((c) => c.stages)
      .map((s) => s.id)
      .toSet();
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: 'R2 검증용',
        location: BannerLocation.topEnd,
        child: MathAdventureApp(
          repository: ProgressRepository(
            _PreviewSaveStore(),
            initialFactory: () => SaveEnvelopeV1(
              completedStageIds: completed,
              unlockedStageIds: {...completed, 'r02-c01-s01'},
              playerCharacterId: 'CHAR_D',
              onboardingCompleted: true,
              unlockedCharacterIds: const {'CHAR_D', 'CHAR_J', 'CHAR_L'},
              viewedStoryIds: const {
                'expedition-join-CHAR_J',
                'expedition-join-CHAR_L',
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _PreviewSaveStore implements KeyValueSaveStore {
  final _delegate = SharedPreferencesSaveStore();
  @override
  Future<String?> read(String key) => _delegate.read('r2-validation.$key');
  @override
  Future<void> write(String key, String value) =>
      _delegate.write('r2-validation.$key', value);
}
