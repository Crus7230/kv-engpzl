import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/domain/campaign_progress_migration.dart';

void main() {
  const migrator = CampaignProgressMigrator();
  final migrated = migrator.migrate(
    progress: CampaignProgressSnapshot(
      campaignVersion: 3,
      completedStageIds: const {
        'r01-c03-s10',
        'r02-c03-s10',
        'legacy.completed-unknown',
      },
      unlockedStageIds: const {'r01-c01-s01', 'legacy.unknown-stage'},
    ),
    campaign: initialCampaign,
  );

  _expect(
    migrated.campaignVersion == 4,
    'Migration must advance the persisted campaign version.',
  );
  _expect(
    migrated.unlockedStageIds.containsAll(const {
      'r01-c01-s01',
      'r01-c04-s01',
      'r02-c01-s01',
      'r02-c04-s01',
      'r03-c01-s01',
      'legacy.unknown-stage',
      'legacy.completed-unknown',
    }),
    'Completed C03 gates must backfill both branch unlocks without deleting '
    'unknown legacy data.',
  );
  _expect(
    migrated.completedStageIds.length == 3,
    'Migration must preserve completion evidence.',
  );

  var rejectedNewerVersion = false;
  try {
    migrator.migrate(
      progress: CampaignProgressSnapshot(campaignVersion: 5),
      campaign: initialCampaign,
    );
  } on StateError {
    rejectedNewerVersion = true;
  }
  _expect(
    rejectedNewerVersion,
    'A newer save version must never be silently downgraded.',
  );

  stdout.writeln(
    'Campaign progress migration verification passed: v3 branch backfill, '
    'unknown-ID preservation, and downgrade rejection.',
  );
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
