import '../../discovery/domain/discovery_models.dart';
import '../../puzzle/domain/authored_expression_checker.dart';
import '../../puzzle/domain/equation_token.dart';
import '../../puzzle/domain/puzzle.dart';
import '../../puzzle/domain/puzzle_learning_support.dart';
import 'board_mechanic_models.dart';
import 'campaign_models.dart';
import 'learning_models.dart';
import 'stage_recurrence_models.dart';

enum CampaignIssueSeverity { warning, error }

enum CampaignIssueCode {
  duplicatePuzzleId,
  missingRegion,
  duplicateRegionId,
  duplicateLegacyRegionId,
  conflictingRegionAlias,
  invalidRegionMetadata,
  invalidRegionOrder,
  invalidRegionPrerequisite,
  missingRegionChapter,
  invalidRegionAccessGate,
  invalidRegionFinalStage,
  invalidRegionHotspot,
  overlappingRegionHotspot,
  invalidRegionAssetKey,
  duplicateRegionAssetKey,
  missingFeaturedCharacter,
  invalidFeaturedCharacterId,
  duplicateFeaturedCharacterId,
  unknownFeaturedCharacterId,
  duplicateChapterId,
  missingChapterStage,
  duplicateStageId,
  duplicateStagePuzzle,
  invalidChapterOrder,
  invalidChapterPrerequisite,
  invalidStageOrder,
  stageChapterMismatch,
  missingSkillId,
  missingLearningObjective,
  duplicateLearningVariant,
  missingLearningPrerequisite,
  unknownLearningPrerequisite,
  futureLearningPrerequisite,
  invalidNextStageLink,
  invalidAdditionalUnlock,
  invalidLearningVariantProfile,
  invalidStageRecurrence,
  unauthoredLearningPlan,
  insufficientMasteryVariants,
  missingTransferOpportunity,
  missingPuzzleLearningSupport,
  invalidMathHintSequence,
  missingWorkedSolution,
  invalidWorkedSolution,
  missingMisconceptionFeedback,
  invalidTransferPrompt,
  hintBudgetExceedsSupport,
  missingAnswerExpression,
  missingAuthoredPuzzle,
  authoredPuzzleStillPlanned,
  unresolvedPlannedPuzzle,
  overlappingTokenSetup,
  tokenSetupMismatch,
  unknownDecoyToken,
  requiredSealCountMismatch,
  decoySealCountMismatch,
  mathReasoningStepMismatch,
  mathOperatorKindMismatch,
  mathParenthesisMismatch,
  mathOrderOfOperationsMismatch,
  invalidMoveBudget,
  missingBoardVariant,
  missingPhoneBoardVariant,
  duplicateBoardVariant,
  duplicateFixtureId,
  duplicateFixtureSeed,
  boardCapacityTooSmall,
  invalidMatchTierDetails,
  simultaneousDifficultyIncrease,
  advancedMatchRuleIntroducedWithHardMath,
  unverifiedPlayableFixture,
  unsupportedPlayableMatchRules,
  invalidBoardMechanicPlan,
  invalidBoardMechanicSequence,
  unsupportedPlayableBoardMechanic,
}

class CampaignValidationIssue {
  const CampaignValidationIssue({
    required this.code,
    required this.severity,
    required this.location,
    required this.message,
  });

  final CampaignIssueCode code;
  final CampaignIssueSeverity severity;
  final String location;
  final String message;
}

class CampaignValidationReport {
  CampaignValidationReport(Iterable<CampaignValidationIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<CampaignValidationIssue> issues;

  Iterable<CampaignValidationIssue> get errors =>
      issues.where((issue) => issue.severity == CampaignIssueSeverity.error);

  Iterable<CampaignValidationIssue> get warnings =>
      issues.where((issue) => issue.severity == CampaignIssueSeverity.warning);

  bool get isValid => errors.isEmpty;
}

class CampaignValidator {
  const CampaignValidator();

  CampaignValidationReport validate({
    required CampaignDefinition campaign,
    required Iterable<Puzzle> puzzles,
    Iterable<String>? knownCharacterIds,
  }) {
    final issues = <CampaignValidationIssue>[];
    final puzzleById = <String, Puzzle>{};
    for (final puzzle in puzzles) {
      if (puzzleById.containsKey(puzzle.id)) {
        issues.add(
          _error(
            CampaignIssueCode.duplicatePuzzleId,
            'puzzle:${puzzle.id}',
            'Puzzle ID ${puzzle.id} is duplicated.',
          ),
        );
      } else {
        puzzleById[puzzle.id] = puzzle;
      }
    }

    final knownCharacters = knownCharacterIds?.toSet();
    final regionIds = <String>{};
    final legacyRegionIds = <String>{};
    final visitedRegions = <RegionDefinition>[];
    final regionAssetKeys = <String>{};
    final chapterIds = <String>{};
    final stageIds = <String>{};
    final stagePuzzleIds = <String>{};
    final learningVariantIds = <String>{};
    final introducedAdvancedMatchTiers = <MatchDifficultyTier>{};
    final orderedStages = campaign.stages.toList(growable: false);
    final knownStageIds = {for (final stage in orderedStages) stage.id};
    final stageIndexById = <String, int>{
      for (var index = 0; index < orderedStages.length; index += 1)
        orderedStages[index].id: index,
    };
    final expectedNextStageById = <String, String?>{};
    for (final region in campaign.regions) {
      final regionStages = region.stages.toList(growable: false);
      for (var index = 0; index < regionStages.length; index += 1) {
        expectedNextStageById[regionStages[index].id] =
            index + 1 < regionStages.length ? regionStages[index + 1].id : null;
      }
    }
    final knownLearningSkillIds = <String>{
      for (final stage in orderedStages) stage.learningPlan.primarySkillId,
      for (final stage in orderedStages)
        ...stage.learningPlan.reinforcedSkillIds,
    };
    final stagesByLearningSkill = <String, List<StageDefinition>>{};
    final earlierLearningSkillsByStageId = <String, Set<String>>{};
    final seenPrimaryLearningSkills = <String>{};
    for (final stage in orderedStages) {
      earlierLearningSkillsByStageId[stage.id] = Set.unmodifiable(
        seenPrimaryLearningSkills,
      );
      stagesByLearningSkill
          .putIfAbsent(stage.learningPlan.primarySkillId, () => [])
          .add(stage);
      seenPrimaryLearningSkills.add(stage.learningPlan.primarySkillId);
    }

    if (campaign.regions.isEmpty) {
      issues.add(
        _error(
          CampaignIssueCode.missingRegion,
          'campaign:${campaign.id}',
          'A campaign must contain at least one region.',
        ),
      );
    }

    for (
      var regionIndex = 0;
      regionIndex < campaign.regions.length;
      regionIndex += 1
    ) {
      final region = campaign.regions[regionIndex];
      final regionLocation = 'region:${region.id}';
      final expectedRegionPrerequisite = regionIndex == 0
          ? null
          : campaign.regions[regionIndex - 1].id;

      if (!regionIds.add(region.id)) {
        issues.add(
          _error(
            CampaignIssueCode.duplicateRegionId,
            regionLocation,
            'Region ID ${region.id} is duplicated.',
          ),
        );
      }
      if (!legacyRegionIds.add(region.legacyId)) {
        issues.add(
          _error(
            CampaignIssueCode.duplicateLegacyRegionId,
            regionLocation,
            'Legacy region ID ${region.legacyId} is duplicated.',
          ),
        );
      }
      if (legacyRegionIds.contains(region.id) ||
          regionIds.contains(region.legacyId)) {
        issues.add(
          _error(
            CampaignIssueCode.conflictingRegionAlias,
            regionLocation,
            'Canonical and legacy region IDs must not collide across regions.',
          ),
        );
      }
      if (region.id.trim().isEmpty ||
          region.legacyId.trim().isEmpty ||
          region.title.trim().isEmpty ||
          region.description.trim().isEmpty ||
          region.finalStageId.trim().isEmpty) {
        issues.add(
          _error(
            CampaignIssueCode.invalidRegionMetadata,
            regionLocation,
            'Region IDs, title, description, and final stage ID are required.',
          ),
        );
      }
      if (region.number != regionIndex + 1) {
        issues.add(
          _error(
            CampaignIssueCode.invalidRegionOrder,
            regionLocation,
            'Expected region number ${regionIndex + 1}, got ${region.number}.',
          ),
        );
      }
      if (region.prerequisiteRegionId != expectedRegionPrerequisite) {
        issues.add(
          _error(
            CampaignIssueCode.invalidRegionPrerequisite,
            regionLocation,
            'Expected prerequisite $expectedRegionPrerequisite, got '
            '${region.prerequisiteRegionId}.',
          ),
        );
      }
      if (!region.hotspot.hasNormalizedValues ||
          region.hotspot.left < 0 ||
          region.hotspot.top < 0 ||
          region.hotspot.right > 1 ||
          region.hotspot.bottom > 1) {
        issues.add(
          _error(
            CampaignIssueCode.invalidRegionHotspot,
            regionLocation,
            'World-map hotspot and its bounds must stay within 0..1.',
          ),
        );
      }
      for (final previousRegion in visitedRegions) {
        if (_hotspotsOverlap(region.hotspot, previousRegion.hotspot)) {
          issues.add(
            _error(
              CampaignIssueCode.overlappingRegionHotspot,
              regionLocation,
              'World-map hotspot overlaps region ${previousRegion.id}.',
            ),
          );
        }
      }
      visitedRegions.add(region);

      for (final assetKey in region.visualAssets.values) {
        if (assetKey.trim().isEmpty) {
          issues.add(
            _error(
              CampaignIssueCode.invalidRegionAssetKey,
              regionLocation,
              'Every region visual asset key must be non-empty.',
            ),
          );
        } else if (!regionAssetKeys.add(assetKey)) {
          issues.add(
            _error(
              CampaignIssueCode.duplicateRegionAssetKey,
              regionLocation,
              'Region visual asset key $assetKey is duplicated.',
            ),
          );
        }
      }

      if (region.featuredCharacterIds.isEmpty) {
        issues.add(
          _error(
            CampaignIssueCode.missingFeaturedCharacter,
            regionLocation,
            'At least one featured character is required.',
          ),
        );
      }
      final featuredIds = <String>{};
      for (final characterId in region.featuredCharacterIds) {
        if (characterId.trim().isEmpty) {
          issues.add(
            _error(
              CampaignIssueCode.invalidFeaturedCharacterId,
              regionLocation,
              'Featured character IDs must be non-empty.',
            ),
          );
        } else if (!featuredIds.add(characterId)) {
          issues.add(
            _error(
              CampaignIssueCode.duplicateFeaturedCharacterId,
              regionLocation,
              'Featured character $characterId is duplicated in the region.',
            ),
          );
        } else if (knownCharacters != null &&
            !knownCharacters.contains(characterId)) {
          issues.add(
            _error(
              CampaignIssueCode.unknownFeaturedCharacterId,
              regionLocation,
              'Featured character $characterId is not in the character catalog.',
            ),
          );
        }
      }

      if (region.chapters.isEmpty) {
        issues.add(
          _error(
            CampaignIssueCode.missingRegionChapter,
            regionLocation,
            'A campaign region must contain at least one chapter.',
          ),
        );
        continue;
      }

      final regionStages = region.stages.toList();
      final accessGateIndex = regionStages.indexWhere(
        (stage) => stage.id == region.accessGateStageId,
      );
      if (accessGateIndex < 0 ||
          accessGateIndex >= regionStages.length ||
          region.accessGateStageId.trim().isEmpty) {
        issues.add(
          _error(
            CampaignIssueCode.invalidRegionAccessGate,
            regionLocation,
            'Access gate ${region.accessGateStageId} must belong to the region.',
          ),
        );
      } else {
        final accessGate = regionStages[accessGateIndex];
        final expectedRegionalContinuation =
            accessGateIndex + 1 < regionStages.length
            ? regionStages[accessGateIndex + 1].id
            : null;
        final nextRegionStages = regionIndex + 1 < campaign.regions.length
            ? campaign.regions[regionIndex + 1].stages.toList(growable: false)
            : const <StageDefinition>[];
        final expectedNextRegionStageId = nextRegionStages.isEmpty
            ? null
            : nextRegionStages.first.id;
        if (accessGate.learningPlan.nextStageId !=
                expectedRegionalContinuation ||
            (expectedNextRegionStageId != null &&
                !accessGate.learningPlan.additionalUnlockStageIds.contains(
                  expectedNextRegionStageId,
                ))) {
          issues.add(
            _error(
              CampaignIssueCode.invalidRegionAccessGate,
              regionLocation,
              'An access gate must continue its own region and also unlock '
              'the first stage of the next region.',
            ),
          );
        }
      }
      if (regionStages.isEmpty || region.finalStageId != regionStages.last.id) {
        issues.add(
          _error(
            CampaignIssueCode.invalidRegionFinalStage,
            regionLocation,
            'Final stage ${region.finalStageId} must be the last stage in the region.',
          ),
        );
      }
      StageDefinition? previousRegionStage;

      for (
        var chapterIndex = 0;
        chapterIndex < region.chapters.length;
        chapterIndex += 1
      ) {
        final chapter = region.chapters[chapterIndex];
        final chapterLocation = 'chapter:${chapter.id}';
        final expectedChapterPrerequisite = chapterIndex == 0
            ? null
            : region.chapters[chapterIndex - 1].id;
        if (!chapterIds.add(chapter.id)) {
          issues.add(
            _error(
              CampaignIssueCode.duplicateChapterId,
              chapterLocation,
              'Chapter ID ${chapter.id} is duplicated.',
            ),
          );
        }
        if (chapter.number != chapterIndex + 1) {
          issues.add(
            _error(
              CampaignIssueCode.invalidChapterOrder,
              chapterLocation,
              'Expected chapter number ${chapterIndex + 1}, got ${chapter.number}.',
            ),
          );
        }
        if (chapter.prerequisiteChapterId != expectedChapterPrerequisite) {
          issues.add(
            _error(
              CampaignIssueCode.invalidChapterPrerequisite,
              chapterLocation,
              'Expected prerequisite $expectedChapterPrerequisite, got '
              '${chapter.prerequisiteChapterId}.',
            ),
          );
        }
        if (chapter.stages.isEmpty) {
          issues.add(
            _error(
              CampaignIssueCode.missingChapterStage,
              chapterLocation,
              'A campaign chapter must contain at least one stage.',
            ),
          );
        }

        for (
          var stageIndex = 0;
          stageIndex < chapter.stages.length;
          stageIndex += 1
        ) {
          final stage = chapter.stages[stageIndex];
          final location = 'stage:${stage.id}';
          if (!stageIds.add(stage.id)) {
            issues.add(
              _error(
                CampaignIssueCode.duplicateStageId,
                location,
                'Stage ID ${stage.id} is duplicated.',
              ),
            );
          }
          if (stage.number != stageIndex + 1) {
            issues.add(
              _error(
                CampaignIssueCode.invalidStageOrder,
                location,
                'Expected stage number ${stageIndex + 1}, got ${stage.number}.',
              ),
            );
          }
          if (stage.chapterId != chapter.id) {
            issues.add(
              _error(
                CampaignIssueCode.stageChapterMismatch,
                location,
                'Stage chapter ${stage.chapterId} does not match ${chapter.id}.',
              ),
            );
          }
          if (stage.skillId.trim().isEmpty) {
            issues.add(
              _error(
                CampaignIssueCode.missingSkillId,
                location,
                'Every stage must declare a stable curriculum skill ID.',
              ),
            );
          }
          _validateLearningPlan(
            stage,
            location,
            expectedNextStageById[stage.id],
            knownLearningSkillIds,
            earlierLearningSkillsByStageId[stage.id]!,
            orderedStages.isNotEmpty && stage.id == orderedStages.first.id,
            stagesByLearningSkill[stage.learningPlan.primarySkillId]!,
            orderedStages.length > 1,
            issues,
          );
          _validateAdditionalUnlocks(
            stage,
            location,
            knownStageIds,
            stageIndexById,
            issues,
          );
          _validateVariantAndRecurrence(
            stage,
            location,
            orderedStages,
            stageIndexById,
            issues,
          );
          if (!learningVariantIds.add(stage.learningPlan.variantId)) {
            issues.add(
              _error(
                CampaignIssueCode.duplicateLearningVariant,
                location,
                'Learning variant ${stage.learningPlan.variantId} is '
                'assigned to more than one stage.',
              ),
            );
          }
          if (stage.answerExpression.trim().isEmpty) {
            issues.add(
              _error(
                CampaignIssueCode.missingAnswerExpression,
                location,
                'Every stage must declare its intended answer expression.',
              ),
            );
          }
          if (!stagePuzzleIds.add(stage.puzzleId)) {
            issues.add(
              _error(
                CampaignIssueCode.duplicateStagePuzzle,
                location,
                'Puzzle ${stage.puzzleId} is assigned to more than one stage.',
              ),
            );
          }
          // Replaying a completed-source skill is not a new math concept.
          // Runtime access still requires that source completion; this check
          // proves the catalog links a real earlier authored source of at
          // least this mathematical difficulty, rather than trusting a chapter
          // name or an authoring-role label.
          final hasFamiliarMathSource = _hasFamiliarMathSource(
            stage,
            orderedStages,
            stageIndexById,
            puzzleById,
          );
          if (previousRegionStage != null) {
            if (stage.mathDifficulty.tier.index >
                    previousRegionStage.mathDifficulty.tier.index &&
                stage.matchDifficulty.tier.index >
                    previousRegionStage.matchDifficulty.tier.index &&
                !hasFamiliarMathSource) {
              issues.add(
                _error(
                  CampaignIssueCode.simultaneousDifficultyIncrease,
                  location,
                  'Math and match difficulty must not rise on the same stage.',
                ),
              );
            }
          }
          previousRegionStage = stage;
          final matchTier = stage.matchDifficulty.tier;
          if ((matchTier == MatchDifficultyTier.b3 ||
                  matchTier == MatchDifficultyTier.b4) &&
              introducedAdvancedMatchTiers.add(matchTier) &&
              stage.mathDifficulty.tier.index > MathDifficultyTier.m1.index &&
              !hasFamiliarMathSource) {
            issues.add(
              _error(
                CampaignIssueCode.advancedMatchRuleIntroducedWithHardMath,
                location,
                'B3 and B4 must first be introduced with M0 or M1 math, '
                'or a verified recurrence of an earlier authored skill.',
              ),
            );
          }
          _validateRules(stage, location, issues);
          _validateBoardMechanicPlan(stage, location, issues);

          final puzzle = puzzleById[stage.puzzleId];
          if (stage.contentStatus == StageContentStatus.planned) {
            if (puzzle == null) {
              issues.add(
                _warning(
                  CampaignIssueCode.unresolvedPlannedPuzzle,
                  location,
                  'Planned puzzle ${stage.puzzleId} has not been authored.',
                ),
              );
            } else {
              issues.add(
                _error(
                  CampaignIssueCode.authoredPuzzleStillPlanned,
                  location,
                  'Authored puzzle ${stage.puzzleId} must be promoted to '
                  'puzzleReady or playable.',
                ),
              );
            }
            continue;
          }

          if (puzzle == null) {
            issues.add(
              _error(
                CampaignIssueCode.missingAuthoredPuzzle,
                location,
                'Stage references missing authored puzzle ${stage.puzzleId}.',
              ),
            );
            continue;
          }
          _validatePuzzleBinding(stage, puzzle, location, issues);
        }
      }
    }

    final mechanicSequenceIssues = const BoardMechanicSequenceValidator()
        .validate(orderedStages.map((stage) => stage.boardMechanicPlan));
    for (final mechanicIssue in mechanicSequenceIssues) {
      issues.add(
        _error(
          CampaignIssueCode.invalidBoardMechanicSequence,
          'board-plan:${mechanicIssue.planId}',
          '${mechanicIssue.code.name}: '
              '${mechanicIssue.mechanicIds.map((id) => id.name).join(', ')}.',
        ),
      );
    }

    return CampaignValidationReport(issues);
  }

  bool _hasFamiliarMathSource(
    StageDefinition stage,
    List<StageDefinition> orderedStages,
    Map<String, int> stageIndexById,
    Map<String, Puzzle> puzzleById,
  ) {
    final recurrence = stage.recurrencePlan;
    if (recurrence == null ||
        !recurrence.isSpiral ||
        !recurrence.isValid ||
        !stage.isPlayable ||
        stage.learningPlan.status != LearningPlanStatus.authored) {
      return false;
    }
    final sourceIndex = stageIndexById[recurrence.sourceStageId];
    final currentIndex = stageIndexById[stage.id]!;
    if (sourceIndex == null ||
        sourceIndex >= currentIndex ||
        !recurrence.acceptsCatalogStageGap(currentIndex - sourceIndex)) {
      return false;
    }
    final source = orderedStages[sourceIndex];
    final sourcePuzzle = puzzleById[source.puzzleId];
    return source.isPlayable &&
        source.learningPlan.status == LearningPlanStatus.authored &&
        sourcePuzzle?.learningSupport?.hasCompletePlayableSupport == true &&
        source.boardVariants.variants.every((variant) => variant.isVerified) &&
        _supportsRuntimeMatchRules(source) &&
        source.learningPlan.primarySkillId ==
            stage.learningPlan.primarySkillId &&
        source.mathDifficulty.tier.index >= stage.mathDifficulty.tier.index &&
        recurrence.source.stageId == source.variantProfile.stageId &&
        recurrence.source.meaningfulFingerprint ==
            source.variantProfile.meaningfulFingerprint &&
        recurrence.revisitStageId == stage.id &&
        recurrence.revisit.meaningfulFingerprint ==
            stage.variantProfile.meaningfulFingerprint;
  }

  void _validateAdditionalUnlocks(
    StageDefinition stage,
    String location,
    Set<String> knownStageIds,
    Map<String, int> stageIndexById,
    List<CampaignValidationIssue> issues,
  ) {
    final currentIndex = stageIndexById[stage.id]!;
    for (final unlockStageId in stage.learningPlan.additionalUnlockStageIds) {
      final unlockIndex = stageIndexById[unlockStageId];
      if (!knownStageIds.contains(unlockStageId) ||
          unlockStageId == stage.id ||
          unlockStageId == stage.learningPlan.nextStageId ||
          unlockIndex == null ||
          unlockIndex <= currentIndex) {
        issues.add(
          _error(
            CampaignIssueCode.invalidAdditionalUnlock,
            location,
            'Additional unlock $unlockStageId must target a distinct later stage.',
          ),
        );
      }
    }
  }

  void _validateVariantAndRecurrence(
    StageDefinition stage,
    String location,
    List<StageDefinition> orderedStages,
    Map<String, int> stageIndexById,
    List<CampaignValidationIssue> issues,
  ) {
    final profile = stage.variantProfile;
    if (profile.stageId != stage.id ||
        profile.primarySkillId != stage.learningPlan.primarySkillId ||
        stage.learningPlan.semanticFingerprint !=
            profile.meaningfulFingerprint) {
      issues.add(
        _error(
          CampaignIssueCode.invalidLearningVariantProfile,
          location,
          'Variant profile identity and semantic fingerprint must match the '
          'stage learning plan.',
        ),
      );
    }

    final recurrence = stage.recurrencePlan;
    if (recurrence == null) {
      return;
    }
    final sourceIndex = stageIndexById[recurrence.sourceStageId];
    final revisitIndex = stageIndexById[stage.id]!;
    final sourceStage = sourceIndex == null ? null : orderedStages[sourceIndex];
    final sourceMatches =
        sourceStage != null &&
        sourceStage.variantProfile.meaningfulFingerprint ==
            recurrence.source.meaningfulFingerprint;
    final revisitMatches =
        recurrence.revisitStageId == stage.id &&
        recurrence.revisit.meaningfulFingerprint ==
            profile.meaningfulFingerprint;
    final actualGap = sourceIndex == null ? null : revisitIndex - sourceIndex;
    final hasValidStructure =
        sourceIndex != null &&
        sourceIndex < revisitIndex &&
        sourceMatches &&
        revisitMatches &&
        actualGap != null &&
        recurrence.acceptsCatalogStageGap(actualGap) &&
        recurrence.usesRecommendedGapWindow &&
        recurrence.followsCoreSpiralGapRule;
    final requiresAuthoredVariation =
        stage.learningPlan.status != LearningPlanStatus.requiresRevision;
    final missingCrossRegionEvidence =
        recurrence.kind == RevisitKind.crossRegionTransfer &&
        requiresAuthoredVariation &&
        stage.learningPlan.reinforcedSkillIds.isEmpty;
    if (!hasValidStructure ||
        (requiresAuthoredVariation && !recurrence.hasValidVariation) ||
        missingCrossRegionEvidence) {
      issues.add(
        _error(
          CampaignIssueCode.invalidStageRecurrence,
          location,
          'Recurrence must reference an earlier same-skill stage, match its '
          'actual catalog gap, and use an authored semantic variation '
          'before leaving requiresRevision. Cross-region transfer also needs '
          'an explicitly reinforced skill.',
        ),
      );
    }
  }

  void _validateBoardMechanicPlan(
    StageDefinition stage,
    String location,
    List<CampaignValidationIssue> issues,
  ) {
    final baselineBindings = stage.boardMechanicPlan.bindings.where(
      (binding) => binding.rule.mechanicId == BoardMechanicId.singleLayerSeal,
    );
    final baselineRule = baselineBindings.length == 1
        ? baselineBindings.single.rule
        : null;
    if (stage.boardMechanicPlan.id.trim().isEmpty ||
        baselineRule is! SingleLayerSealRule ||
        baselineRule.sealCount != stage.matchDifficulty.requiredSealCount) {
      issues.add(
        _error(
          CampaignIssueCode.invalidBoardMechanicPlan,
          location,
          'Every stage needs one single-layer baseline matching the required '
          'seal count.',
        ),
      );
    }
    if (stage.isPlayable &&
        !currentDiscoveryBoardMechanics.supportsForPlay(
          stage.boardMechanicPlan,
        )) {
      issues.add(
        _error(
          CampaignIssueCode.unsupportedPlayableBoardMechanic,
          location,
          'Playable stages may use only mechanics supported by the engine, '
          'adapter, and verified fixtures.',
        ),
      );
    }
  }

  void _validateLearningPlan(
    StageDefinition stage,
    String location,
    String? expectedNextStageId,
    Set<String> knownLearningSkillIds,
    Set<String> earlierLearningSkillIds,
    bool isFirstCampaignStage,
    List<StageDefinition> masteryPathStages,
    bool validatesMasteryPath,
    List<CampaignValidationIssue> issues,
  ) {
    final plan = stage.learningPlan;
    if (plan.primarySkillId.trim().isEmpty ||
        plan.variantId.trim().isEmpty ||
        plan.objective.trim().isEmpty) {
      issues.add(
        _error(
          CampaignIssueCode.missingLearningObjective,
          location,
          'Every stage must declare a primary learning skill and objective.',
        ),
      );
    }
    if (plan.nextStageId != expectedNextStageId) {
      issues.add(
        _error(
          CampaignIssueCode.invalidNextStageLink,
          location,
          'Expected next learning stage $expectedNextStageId, got '
          '${plan.nextStageId}.',
        ),
      );
    }
    final invalidPrerequisites = plan.prerequisiteSkillIds.where(
      (skillId) =>
          skillId == plan.primarySkillId ||
          !knownLearningSkillIds.contains(skillId),
    );
    if (invalidPrerequisites.isNotEmpty) {
      issues.add(
        _error(
          CampaignIssueCode.unknownLearningPrerequisite,
          location,
          'Prerequisite skills must be known and differ from the primary '
          'skill: ${invalidPrerequisites.join(', ')}.',
        ),
      );
    }
    if (plan.role == StageLearningRole.prerequisiteCheck &&
        !isFirstCampaignStage &&
        plan.prerequisiteSkillIds.isEmpty) {
      issues.add(
        _error(
          CampaignIssueCode.missingLearningPrerequisite,
          location,
          'A prerequisite-check stage must name an earlier learning skill.',
        ),
      );
    }
    final futurePrerequisites = plan.prerequisiteSkillIds.where(
      (skillId) => !earlierLearningSkillIds.contains(skillId),
    );
    if (!isFirstCampaignStage && futurePrerequisites.isNotEmpty) {
      issues.add(
        _error(
          CampaignIssueCode.futureLearningPrerequisite,
          location,
          'Prerequisite skills must appear earlier in the campaign: '
          '${futurePrerequisites.join(', ')}.',
        ),
      );
    }
    if (stage.hasAuthoredPuzzle && plan.status != LearningPlanStatus.authored) {
      issues.add(
        _error(
          CampaignIssueCode.unauthoredLearningPlan,
          location,
          'Puzzle-ready and playable stages require an authored learning plan.',
        ),
      );
    }
    if (plan.status != LearningPlanStatus.requiresRevision &&
        validatesMasteryPath) {
      final sameStatusMasteryPathStages = masteryPathStages
          .where(
            (candidate) =>
                candidate.learningPlan.status == plan.status ||
                (plan.status == LearningPlanStatus.planned &&
                    candidate.learningPlan.status ==
                        LearningPlanStatus.authored),
          )
          .toList(growable: false);
      if (sameStatusMasteryPathStages.length < 2) {
        issues.add(
          _error(
            CampaignIssueCode.insufficientMasteryVariants,
            location,
            'A ${plan.status.name} mastery skill needs at least two stage '
            'variants with the same learning-plan status.',
          ),
        );
      }
      final hasIndependentPair = sameStatusMasteryPathStages.any(
        (candidate) => sameStatusMasteryPathStages.any(
          (other) =>
              other.id != candidate.id &&
              candidate.variantProfile.isIndependentVariationFrom(
                other.variantProfile,
              ),
        ),
      );
      if (plan.status == LearningPlanStatus.authored && !hasIndependentPair) {
        issues.add(
          _error(
            CampaignIssueCode.insufficientMasteryVariants,
            location,
            'Authored mastery variants must differ on at least two educational '
            'axes including context, representation, unknown position, '
            'or answer AST.',
          ),
        );
      }
      final hasTransferOpportunity = sameStatusMasteryPathStages.any((
        candidate,
      ) {
        final hasTransferRole = switch (candidate.learningPlan.role) {
          StageLearningRole.nearTransfer ||
          StageLearningRole.representationTransfer ||
          StageLearningRole.farTransfer => true,
          _ => false,
        };
        return hasTransferRole &&
            (plan.status != LearningPlanStatus.authored ||
                sameStatusMasteryPathStages.any(
                  (other) =>
                      other.id != candidate.id &&
                      candidate.variantProfile.isIndependentVariationFrom(
                        other.variantProfile,
                      ),
                ));
      });
      if (!hasTransferOpportunity) {
        issues.add(
          _error(
            CampaignIssueCode.missingTransferOpportunity,
            location,
            'A ${plan.status.name} mastery skill needs an independent transfer '
            'stage with the same learning-plan status.',
          ),
        );
      }
    }
  }

  void _validateRules(
    StageDefinition stage,
    String location,
    List<CampaignValidationIssue> issues,
  ) {
    _validateIntendedAnswerMetadata(stage, location, issues);
    final moves = stage.moveBudget;
    if (moves.referenceMoves < 1 ||
        moves.parMoves < moves.referenceMoves ||
        moves.moveLimit < moves.parMoves) {
      issues.add(
        _error(
          CampaignIssueCode.invalidMoveBudget,
          location,
          'Move budget must satisfy 1 <= W <= P <= L.',
        ),
      );
    }
    if (stage.boardVariants.variants.isEmpty) {
      issues.add(
        _error(
          CampaignIssueCode.missingBoardVariant,
          location,
          'At least one physical board fixture is required.',
        ),
      );
    }
    if (!stage.boardVariants.supports(DiscoveryBoardConfig.compactPhone) ||
        !stage.boardVariants.supports(DiscoveryBoardConfig.standardPhone)) {
      issues.add(
        _error(
          CampaignIssueCode.missingPhoneBoardVariant,
          location,
          'Every stage must declare equivalent compact 5x5 and standard 6x6 fixtures.',
        ),
      );
    }

    final boardSizes = <String>{};
    final fixtureIds = <String>{};
    final fixtureSeeds = <int>{};
    for (final variant in stage.boardVariants.variants) {
      final config = variant.config;
      final size = '${config.rows}x${config.columns}';
      if (!boardSizes.add(size)) {
        issues.add(
          _error(
            CampaignIssueCode.duplicateBoardVariant,
            location,
            'Board layout $size is duplicated.',
          ),
        );
      }
      if (!fixtureIds.add(variant.fixtureId)) {
        issues.add(
          _error(
            CampaignIssueCode.duplicateFixtureId,
            location,
            'Board fixture ID ${variant.fixtureId} is duplicated.',
          ),
        );
      }
      if (!fixtureSeeds.add(variant.seed)) {
        issues.add(
          _error(
            CampaignIssueCode.duplicateFixtureSeed,
            location,
            'Board fixture seed ${variant.seed} is duplicated.',
          ),
        );
      }
      final occupiedCells =
          stage.matchDifficulty.requiredSealCount +
          stage.matchDifficulty.decoySealCount +
          stage.matchDifficulty.obstacleCount;
      if (config.rows * config.columns < occupiedCells) {
        issues.add(
          _error(
            CampaignIssueCode.boardCapacityTooSmall,
            location,
            'Board layout $size cannot hold $occupiedCells configured cells.',
          ),
        );
      }
      if (stage.isPlayable && !variant.isVerified) {
        issues.add(
          _error(
            CampaignIssueCode.unverifiedPlayableFixture,
            location,
            'Playable fixture ${variant.fixtureId} is not verified.',
          ),
        );
      }
    }

    final match = stage.matchDifficulty;
    if (!_matchesDeclaredTier(match)) {
      issues.add(
        _error(
          CampaignIssueCode.invalidMatchTierDetails,
          location,
          'Gem, seal, obstacle, special-rule, and planning values do not match ${match.tier.name}.',
        ),
      );
    }
    if (stage.isPlayable && !_supportsRuntimeMatchRules(stage)) {
      issues.add(
        _error(
          CampaignIssueCode.unsupportedPlayableMatchRules,
          location,
          'Playable match rules must agree with supported two-layer seals '
          'and four-match line power bindings. Obstacles and other effects '
          'remain unavailable.',
        ),
      );
    }
  }

  bool _supportsRuntimeMatchRules(StageDefinition stage) {
    final match = stage.matchDifficulty;
    final plan = stage.boardMechanicPlan;
    if (!currentDiscoveryBoardMechanics.supportsForPlay(plan) ||
        match.obstacleCount != 0 ||
        match.maxSealLayers < 1 ||
        match.maxSealLayers > 2) {
      return false;
    }
    final layers = plan.bindings
        .map((binding) => binding.rule)
        .whereType<LayeredSealRule>()
        .toList();
    final hasSupportedLayers =
        layers.length == 1 &&
        layers.single.layers == 2 &&
        layers.single.sealCount == match.requiredSealCount;
    if (match.maxSealLayers == 2 ? !hasSupportedLayers : layers.isNotEmpty) {
      return false;
    }
    final powers = plan.bindings
        .map((binding) => binding.rule)
        .whereType<LinePowerRule>()
        .toList();
    return switch (match.specialRule) {
      MatchSpecialRule.none => powers.isEmpty,
      MatchSpecialRule.fourMatchPower =>
        powers.length == 1 &&
            powers.single.creationMatchLength == 4 &&
            powers.single.requiredActivations == 1,
    };
  }

  void _validateIntendedAnswerMetadata(
    StageDefinition stage,
    String location,
    List<CampaignValidationIssue> issues,
  ) {
    final operatorLabels = <String>{};
    var operationCount = 0;
    for (final symbol in const ['+', '-', '×', '÷']) {
      final matches = symbol.allMatches(stage.answerExpression).length;
      if (matches > 0) {
        operatorLabels.add(symbol);
        operationCount += matches;
      }
    }
    if (operationCount != stage.mathDifficulty.reasoningSteps) {
      issues.add(
        _error(
          CampaignIssueCode.mathReasoningStepMismatch,
          location,
          'Answer expression has $operationCount operations, but difficulty '
          'declares ${stage.mathDifficulty.reasoningSteps}.',
        ),
      );
    }
    if (operatorLabels.length != stage.mathDifficulty.operatorKindCount) {
      issues.add(
        _error(
          CampaignIssueCode.mathOperatorKindMismatch,
          location,
          'Answer expression has ${operatorLabels.length} operator kinds, but '
          'difficulty declares ${stage.mathDifficulty.operatorKindCount}.',
        ),
      );
    }
    final requiresParentheses = stage.answerExpression.contains('(');
    if (requiresParentheses != stage.mathDifficulty.requiresParentheses) {
      issues.add(
        _error(
          CampaignIssueCode.mathParenthesisMismatch,
          location,
          'Answer expression parenthesis use does not match difficulty.',
        ),
      );
    }
    final usesOrderOfOperations = _usesOrderOfOperations(
      operatorLabels,
      requiresParentheses: requiresParentheses,
    );
    if (usesOrderOfOperations != stage.mathDifficulty.usesOrderOfOperations) {
      issues.add(
        _error(
          CampaignIssueCode.mathOrderOfOperationsMismatch,
          location,
          'Answer expression order-of-operations use does not match difficulty.',
        ),
      );
    }
  }

  bool _matchesDeclaredTier(MatchDifficulty match) => switch (match.tier) {
    MatchDifficultyTier.b0 =>
      match.gemKindCount == 4 &&
          match.requiredSealCount >= 2 &&
          match.requiredSealCount <= 3 &&
          match.decoySealCount == 0 &&
          match.maxSealLayers == 1 &&
          match.obstacleCount == 0 &&
          match.specialRule == MatchSpecialRule.none &&
          match.planningDepth == 1,
    MatchDifficultyTier.b1 =>
      match.gemKindCount == 5 &&
          match.requiredSealCount >= 2 &&
          match.requiredSealCount <= 4 &&
          match.decoySealCount == 0 &&
          match.maxSealLayers == 1 &&
          match.obstacleCount == 0 &&
          match.specialRule == MatchSpecialRule.none &&
          match.planningDepth == (match.hasScriptedOpening ? 1 : 2),
    MatchDifficultyTier.b2 =>
      match.gemKindCount == 5 &&
          match.requiredSealCount >= 2 &&
          match.requiredSealCount <= 5 &&
          match.decoySealCount <= 1 &&
          match.maxSealLayers == 1 &&
          match.obstacleCount == 0 &&
          match.specialRule == MatchSpecialRule.none &&
          match.planningDepth == 3,
    MatchDifficultyTier.b3 =>
      match.gemKindCount == 5 &&
          match.decoySealCount == 0 &&
          ((match.maxSealLayers == 2 && match.obstacleCount == 0) ||
              (match.maxSealLayers == 1 &&
                  match.obstacleCount >= 1 &&
                  match.obstacleCount <= 3)) &&
          match.specialRule == MatchSpecialRule.none &&
          match.planningDepth == 4,
    MatchDifficultyTier.b4 =>
      match.gemKindCount == 5 &&
          match.decoySealCount == 0 &&
          match.maxSealLayers >= 1 &&
          match.maxSealLayers <= 2 &&
          match.obstacleCount == 0 &&
          match.specialRule == MatchSpecialRule.fourMatchPower &&
          match.planningDepth == 5,
  };

  void _validatePuzzleBinding(
    StageDefinition stage,
    Puzzle puzzle,
    String location,
    List<CampaignValidationIssue> issues,
  ) {
    _validatePuzzleLearningSupport(stage, puzzle, location, issues);
    final answerOverlap = stage.startingTokenIds.intersection(
      stage.buriedTokenIds,
    );
    final decoyOverlap = stage.decoyTokenIds.intersection({
      ...stage.startingTokenIds,
      ...stage.buriedTokenIds,
    });
    if (answerOverlap.isNotEmpty || decoyOverlap.isNotEmpty) {
      issues.add(
        _error(
          CampaignIssueCode.overlappingTokenSetup,
          location,
          'Starting, buried, and decoy token IDs must be disjoint.',
        ),
      );
    }
    final configuredAnswerIds = {
      ...stage.startingTokenIds,
      ...stage.buriedTokenIds,
    };
    if (configuredAnswerIds.length != puzzle.requiredTokenIds.length ||
        !configuredAnswerIds.containsAll(puzzle.requiredTokenIds)) {
      issues.add(
        _error(
          CampaignIssueCode.tokenSetupMismatch,
          location,
          'Starting and buried tokens must partition every required token.',
        ),
      );
    }

    final puzzleTokenIds = {for (final token in puzzle.tokens) token.id};
    if (stage.decoyTokenIds.any(
      (id) =>
          !puzzleTokenIds.contains(id) || puzzle.requiredTokenIds.contains(id),
    )) {
      issues.add(
        _error(
          CampaignIssueCode.unknownDecoyToken,
          location,
          'Every discovered decoy must be a non-required puzzle token.',
        ),
      );
    }
    if (stage.buriedTokenIds.length !=
        stage.matchDifficulty.requiredSealCount) {
      issues.add(
        _error(
          CampaignIssueCode.requiredSealCountMismatch,
          location,
          'Configured ${stage.buriedTokenIds.length} required seals, but '
          'match difficulty expects '
          '${stage.matchDifficulty.requiredSealCount}.',
        ),
      );
    }
    if (stage.decoyTokenIds.length != stage.matchDifficulty.decoySealCount) {
      issues.add(
        _error(
          CampaignIssueCode.decoySealCountMismatch,
          location,
          'Configured ${stage.decoyTokenIds.length} decoy seals, but match '
          'difficulty expects ${stage.matchDifficulty.decoySealCount}.',
        ),
      );
    }

    final requiredTokens = puzzle.tokens.where(
      (token) => puzzle.requiredTokenIds.contains(token.id),
    );
    final operatorLabels = requiredTokens
        .where((token) => token.kind == EquationTokenKind.operator)
        .map((token) => token.label)
        .toSet();
    if (operatorLabels.length != stage.mathDifficulty.operatorKindCount) {
      issues.add(
        _error(
          CampaignIssueCode.mathOperatorKindMismatch,
          location,
          'Configured ${stage.mathDifficulty.operatorKindCount} operator '
          'kinds, but puzzle uses ${operatorLabels.length}.',
        ),
      );
    }
    final operatorTokenCount = requiredTokens
        .where((token) => token.kind == EquationTokenKind.operator)
        .length;
    if (operatorTokenCount != stage.mathDifficulty.reasoningSteps) {
      issues.add(
        _error(
          CampaignIssueCode.mathReasoningStepMismatch,
          location,
          'Configured ${stage.mathDifficulty.reasoningSteps} reasoning steps, '
          'but puzzle requires $operatorTokenCount operations.',
        ),
      );
    }
    final requiresParentheses = requiredTokens.any(
      (token) =>
          token.kind == EquationTokenKind.leftParenthesis ||
          token.kind == EquationTokenKind.rightParenthesis,
    );
    if (requiresParentheses != stage.mathDifficulty.requiresParentheses) {
      issues.add(
        _error(
          CampaignIssueCode.mathParenthesisMismatch,
          location,
          'Parenthesis difficulty does not match the puzzle token setup.',
        ),
      );
    }
    final usesOrderOfOperations = _usesOrderOfOperations(
      operatorLabels,
      requiresParentheses: requiresParentheses,
    );
    if (usesOrderOfOperations != stage.mathDifficulty.usesOrderOfOperations) {
      issues.add(
        _error(
          CampaignIssueCode.mathOrderOfOperationsMismatch,
          location,
          'Order-of-operations difficulty does not match the puzzle tokens.',
        ),
      );
    }
  }

  void _validatePuzzleLearningSupport(
    StageDefinition stage,
    Puzzle puzzle,
    String location,
    List<CampaignValidationIssue> issues,
  ) {
    final support = puzzle.learningSupport;
    if (support == null) {
      issues.add(
        _error(
          CampaignIssueCode.missingPuzzleLearningSupport,
          location,
          'Puzzle-ready and playable stages require typed learning support.',
        ),
      );
      return;
    }
    const requiredHintKinds = [
      PuzzleHintKind.observation,
      PuzzleHintKind.relationship,
      PuzzleHintKind.partialExpression,
    ];
    final hasRequiredHintSequence =
        support.hintSteps.length == requiredHintKinds.length &&
        List.generate(
          requiredHintKinds.length,
          (index) => support.hintSteps[index].kind == requiredHintKinds[index],
        ).every((matches) => matches);
    if (!hasRequiredHintSequence ||
        support.hintSteps.any((hint) => hint.message.trim().isEmpty)) {
      issues.add(
        _error(
          CampaignIssueCode.invalidMathHintSequence,
          location,
          'Learning support requires observation, relationship, and partial '
          'expression hints in that order.',
        ),
      );
    }
    if (support.workedSolutionSteps.length < 2 ||
        support.workedSolutionSteps.any(
          (step) =>
              step.expression.trim().isEmpty || step.explanation.trim().isEmpty,
        )) {
      issues.add(
        _error(
          CampaignIssueCode.missingWorkedSolution,
          location,
          'Learning support requires at least two explained solution steps.',
        ),
      );
    }
    const expressionChecker = AuthoredExpressionChecker();
    final workedChecks = [
      for (final step in support.workedSolutionSteps)
        expressionChecker.evaluateEquation(step.expression),
    ];
    if (workedChecks.any((check) => !check.isValid) ||
        (workedChecks.isNotEmpty && workedChecks.last.value != puzzle.target)) {
      issues.add(
        _error(
          CampaignIssueCode.invalidWorkedSolution,
          location,
          'Worked equations must be valid, true, and finish at the puzzle target.',
        ),
      );
    }
    final misconceptionCategories = {
      for (final feedback in support.misconceptionFeedback) feedback.category,
    };
    if (support.misconceptionFeedback.length !=
            PuzzleMisconceptionCategory.values.length ||
        misconceptionCategories.length !=
            PuzzleMisconceptionCategory.values.length ||
        !misconceptionCategories.containsAll(
          PuzzleMisconceptionCategory.values,
        ) ||
        support.misconceptionFeedback.any(
          (feedback) => feedback.message.trim().isEmpty,
        )) {
      issues.add(
        _error(
          CampaignIssueCode.missingMisconceptionFeedback,
          location,
          'Every supported misconception category needs one feedback message.',
        ),
      );
    }
    if (support.learningObjective.trim().isEmpty ||
        support.transferPrompt.question.trim().isEmpty ||
        support.transferPrompt.expectedExpression.trim().isEmpty ||
        !expressionChecker
            .evaluate(support.transferPrompt.expectedExpression)
            .isValid) {
      issues.add(
        _error(
          CampaignIssueCode.invalidTransferPrompt,
          location,
          'Learning support requires an objective and a complete transfer prompt.',
        ),
      );
    }
    if (stage.assistRules.freeHintCount > support.hintSteps.length) {
      issues.add(
        _error(
          CampaignIssueCode.hintBudgetExceedsSupport,
          location,
          'Free math hints cannot exceed the authored hint sequence.',
        ),
      );
    }
  }

  bool _usesOrderOfOperations(
    Set<String> operatorLabels, {
    required bool requiresParentheses,
  }) =>
      requiresParentheses ||
      (operatorLabels.any(const {'+', '-'}.contains) &&
          operatorLabels.any(const {'×', '÷', '*', '/'}.contains));

  bool _hotspotsOverlap(
    NormalizedMapHotspot first,
    NormalizedMapHotspot second,
  ) =>
      first.left < second.right &&
      first.right > second.left &&
      first.top < second.bottom &&
      first.bottom > second.top;

  CampaignValidationIssue _error(
    CampaignIssueCode code,
    String location,
    String message,
  ) => CampaignValidationIssue(
    code: code,
    severity: CampaignIssueSeverity.error,
    location: location,
    message: message,
  );

  CampaignValidationIssue _warning(
    CampaignIssueCode code,
    String location,
    String message,
  ) => CampaignValidationIssue(
    code: code,
    severity: CampaignIssueSeverity.warning,
    location: location,
    message: message,
  );
}
