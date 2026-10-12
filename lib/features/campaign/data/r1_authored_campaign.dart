import '../../puzzle/domain/equation_engine.dart';
import '../../puzzle/domain/equation_token.dart';
import '../../puzzle/domain/puzzle.dart';
import '../../puzzle/domain/puzzle_learning_support.dart';
import '../../puzzle/domain/sentence_math_problem.dart';
import '../domain/board_mechanic_models.dart';
import '../domain/campaign_models.dart';
import '../domain/learning_models.dart';
import '../domain/stage_recurrence_models.dart';
import 'regional_campaign.dart';
import 'r1_board_progression.dart';
import 'r2_board_progression.dart';

part 'r2_authored_content.dart';

/// Internal-alpha content. Fixtures have deterministic reference paths, not
/// family-calibrated difficulty estimates or release validation.
///
/// Keep the immutable regional blueprint and its identifiers separate from
/// this authored overlay. C04-C06 change actual mathematical context/representation
/// rather than merely changing nouns, numbers, seeds, or board placement.
final Map<String, Puzzle> r1PuzzlesByStageId = Map.unmodifiable({
  for (final entry in _authored.entries)
    entry.key: _buildPuzzle(
      regionalCampaign.stageById(entry.key)!,
      entry.value,
    ),
});

/// Ordered answer tokens are also the authoring AST validation fixture.
final Map<String, List<String>> r1AnswerTokenIdsByStageId =
    Map<String, List<String>>.unmodifiable({
      for (final entry in r1PuzzlesByStageId.entries)
        entry.key: List<String>.unmodifiable(
          entry.value.tokens.map((token) => token.id),
        ),
    });

final Map<String, Puzzle> r2PuzzlesByStageId = Map.unmodifiable({
  for (final entry in _r2Authored.entries)
    entry.key: _buildPuzzle(
      regionalCampaign.stageById(entry.key)!,
      entry.value,
    ),
});

final Map<String, Puzzle> authoredPuzzlesByStageId = Map.unmodifiable({
  ...r1PuzzlesByStageId,
  ...r2PuzzlesByStageId,
});

CampaignDefinition buildRenewalCampaign(CampaignDefinition blueprint) =>
    buildR1Campaign(blueprint, includeR2: true);

/// Kept solely to replay checkpoints created before the renewed physics.
final Map<String, StageDefinition> r1LegacyStagesById = Map.unmodifiable({
  for (final stage in buildR1Campaign(
    regionalCampaign,
    renewedMechanics: false,
  ).stages)
    if (r1PuzzlesByStageId.containsKey(stage.id)) stage.id: stage,
});

CampaignDefinition buildR1Campaign(
  CampaignDefinition blueprint, {
  bool renewedMechanics = true,
  bool includeR2 = false,
}) {
  final authored = <String, _Problem>{
    ..._authored,
    if (includeR2) ..._r2Authored,
  };
  final profiles = <String, LearningVariantProfile>{
    for (final stage in blueprint.stages)
      stage.id: authored.containsKey(stage.id)
          ? _buildProfile(stage, authored[stage.id]!)
          : stage.variantProfile,
  };
  final introduced = <BoardMechanicId>{};
  return CampaignDefinition.regional(
    id: blueprint.id,
    version: blueprint.version,
    regions: [
      for (final region in blueprint.regions)
        region.metadata.bindChapters([
          for (final chapter in region.chapters)
            ChapterDefinition(
              id: chapter.id,
              number: chapter.number,
              title: chapter.title,
              description: chapter.description,
              prerequisiteChapterId: chapter.prerequisiteChapterId,
              stages: [
                for (final stage in chapter.stages)
                  _composeStage(
                    stage,
                    profiles,
                    renewedMechanics,
                    introduced,
                    authored,
                  ),
              ],
            ),
        ]),
    ],
  );
}

StageDefinition _composeStage(
  StageDefinition source,
  Map<String, LearningVariantProfile> profiles,
  bool renewedMechanics,
  Set<BoardMechanicId> introduced,
  Map<String, _Problem> authored,
) {
  final data = authored[source.id];
  final recurrence = source.recurrencePlan;
  if (data?.sourceStageId != null &&
      data!.sourceStageId != recurrence?.sourceStageId) {
    throw StateError(
      'Authored source link differs from blueprint: ${source.id}.',
    );
  }
  final reboundRecurrence = recurrence == null
      ? null
      : StageRecurrencePlan(
          source: profiles[recurrence.sourceStageId]!,
          revisit: profiles[source.id]!,
          kind: recurrence.kind,
          minimumCatalogStageGap: recurrence.minimumCatalogStageGap,
          maximumCatalogStageGap: recurrence.maximumCatalogStageGap,
        );
  // Planned recurrences must reference the real source fingerprint after a
  // source is authored. Rebinding does not promote the planned revisit.
  if (!renewedMechanics && data == null && recurrence == null) return source;
  final puzzle = data == null ? null : authoredPuzzlesByStageId[source.id]!;
  final buried = puzzle == null ? source.buriedTokenIds : _buriedIds(puzzle);
  final starting = puzzle == null
      ? source.startingTokenIds
      : puzzle.requiredTokenIds.difference(buried);
  final profile = profiles[source.id]!;
  final renewed = data != null && renewedMechanics
      ? source.id.startsWith('r02-')
            ? R2BoardProgression.forStage(source)
            : R1BoardProgression.forStage(source)
      : null;
  var boardPlan =
      renewed?.plan(source, buried.length) ??
      (data == null
          ? source.boardMechanicPlan
          : _boardMechanicPlan(source, buried.length));
  if (renewedMechanics && data == null) {
    boardPlan = BoardMechanicPlan(
      id: boardPlan.id,
      role: boardPlan.role,
      challengeLevel: boardPlan.challengeLevel,
      learningSourceStageId: boardPlan.learningSourceStageId,
      prerequisiteStageIds: boardPlan.prerequisiteStageIds,
      bindings: [
        for (final binding in boardPlan.bindings)
          if (binding.rule is LinePowerRule)
            BoardMechanicBinding(
              skin: binding.skin,
              rule: LinePowerRule(
                requiredActivations:
                    (binding.rule as LinePowerRule).requiredActivations,
                creationMatchLength:
                    (binding.rule as LinePowerRule).creationMatchLength,
                enableBurst: true,
                enableColor: true,
                enableCombinations: true,
              ),
            )
          else
            binding,
      ],
    );
  }
  // R1 now teaches covers earlier than the original R2 authoring blueprint.
  // Later appearances are refresher encounters, not a second first unlock.
  if (renewedMechanics &&
      boardPlan.role == BoardMechanicRole.introduce &&
      boardPlan.advancedMechanicIds.every(introduced.contains)) {
    boardPlan = BoardMechanicPlan(
      id: boardPlan.id,
      role: BoardMechanicRole.review,
      bindings: boardPlan.bindings,
      challengeLevel: boardPlan.challengeLevel,
      learningSourceStageId: boardPlan.learningSourceStageId,
      prerequisiteStageIds: boardPlan.prerequisiteStageIds,
    );
  }
  introduced.addAll(boardPlan.advancedMechanicIds);
  return StageDefinition(
    id: source.id,
    chapterId: source.chapterId,
    skillId: source.skillId,
    number: source.number,
    title: data?.concept ?? source.title,
    conceptLabel: data?.concept ?? source.conceptLabel,
    answerExpression: data?.expression ?? source.answerExpression,
    puzzleId: source.puzzleId,
    contentStatus: data == null
        ? source.contentStatus
        : StageContentStatus.playable,
    mathDifficulty: data == null
        ? source.mathDifficulty
        : _mathDifficulty(source.mathDifficulty, puzzle!),
    matchDifficulty: data == null
        ? source.matchDifficulty
        : renewed?.match(buried.length) ??
              _matchDifficulty(source, buried.length),
    boardMechanicPlan: boardPlan,
    boardVariants: data == null
        ? source.boardVariants
        : BoardLayoutVariants(
            variants: [
              for (final variant in source.boardVariants.variants)
                BoardLayoutVariant(
                  config: variant.config,
                  fixtureId: renewed != null && renewed.level > 0
                      ? '${variant.fixtureId}-physics3'
                      : variant.fixtureId,
                  seed: variant.seed,
                  isVerified: true,
                ),
            ],
          ),
    moveBudget: data == null
        ? source.moveBudget
        : renewed != null && renewed.level > 0
        ? StageMoveBudget(
            referenceMoves: renewed.level <= 2 ? 8 : 12,
            parMoves: renewed.level <= 2 ? 10 : 14,
            moveLimit: renewed.level <= 2 ? 16 : 20,
          )
        : source.chapterId == 'r01-c05' || source.chapterId == 'r01-c06'
        ? const StageMoveBudget(referenceMoves: 8, parMoves: 10, moveLimit: 16)
        : StageMoveBudget(
            referenceMoves: buried.length,
            parMoves: buried.length + 2,
            moveLimit: buried.length == 2 ? 10 : 12,
          ),
    starRules: source.starRules,
    assistRules: data == null
        ? source.assistRules
        : StageAssistRules(
            tutorialMode: source.id == 'r01-c01-s01'
                ? StageTutorialMode.contextual
                : StageTutorialMode.optional,
            freeHintCount: 3,
            showsSuggestedSwap: false,
            allowsFreeRestart: true,
          ),
    learningPlan: StageLearningPlan(
      status: data == null
          ? source.learningPlan.status
          : LearningPlanStatus.authored,
      primarySkillId: source.learningPlan.primarySkillId,
      prerequisiteSkillIds: source.learningPlan.prerequisiteSkillIds,
      reinforcedSkillIds: {
        ...source.learningPlan.reinforcedSkillIds,
        if (data != null && source.chapterId == 'r02-c06')
          profiles[switch (source.number) {
                2 || 4 => 'r01-c01-s02',
                6 => 'r01-c02-s01',
                9 || 10 => 'r01-c02-s05',
                _ => 'r01-c01-s01',
              }]!
              .primarySkillId,
      },
      variantId: source.id,
      variantProfile: profile,
      role: data == null
          ? source.learningPlan.role
          : source.chapterId.endsWith('-c04')
          ? StageLearningRole.nearTransfer
          : source.learningPlan.role,
      objective: data?.objective ?? source.learningPlan.objective,
      nextStageId: source.learningPlan.nextStageId,
      additionalUnlockStageIds: {
        ...source.learningPlan.additionalUnlockStageIds,
        for (final entry in authored.entries)
          if (entry.key.contains('-c04-') &&
              entry.value.sourceStageId == source.id)
            entry.key,
      },
    ),
    variantProfile: profile,
    recurrencePlan: reboundRecurrence,
    sentenceMathPlan: source.sentenceMathPlan,
    seed: source.seed,
    startingTokenIds: starting,
    buriedTokenIds: buried,
    decoyTokenIds: data == null ? source.decoyTokenIds : const {},
  );
}

MatchDifficulty _matchDifficulty(StageDefinition stage, int sealCount) {
  final layered =
      stage.chapterId == 'r01-c06' ||
      (stage.chapterId == 'r01-c05' && stage.number <= 5);
  final linePower =
      stage.chapterId == 'r01-c06' ||
      (stage.chapterId == 'r01-c05' && stage.number >= 6);
  return MatchDifficulty(
    tier: linePower
        ? MatchDifficultyTier.b4
        : layered
        ? MatchDifficultyTier.b3
        : MatchDifficultyTier.b1,
    gemKindCount: 5,
    requiredSealCount: sealCount,
    decoySealCount: 0,
    maxSealLayers: layered ? 2 : 1,
    obstacleCount: 0,
    specialRule: linePower
        ? MatchSpecialRule.fourMatchPower
        : MatchSpecialRule.none,
    planningDepth: linePower
        ? 5
        : layered
        ? 4
        : 2,
  );
}

BoardMechanicPlan _boardMechanicPlan(StageDefinition stage, int sealCount) {
  final match = _matchDifficulty(stage, sealCount);
  final layered = match.maxSealLayers == 2;
  final linePower = match.specialRule == MatchSpecialRule.fourMatchPower;
  final role = stage.chapterId == 'r01-c06'
      ? BoardMechanicRole.mixed
      : stage.chapterId == 'r01-c05'
      ? switch ((stage.number - 1) % 5) {
          0 => BoardMechanicRole.introduce,
          1 => BoardMechanicRole.guided,
          2 => BoardMechanicRole.independent,
          _ => BoardMechanicRole.review,
        }
      : BoardMechanicRole.baseline;
  return BoardMechanicPlan(
    id: stage.boardMechanicPlan.id,
    role: role,
    bindings: [
      BoardMechanicBinding(
        rule: SingleLayerSealRule(sealCount: sealCount),
        skin: BoardMechanicSkin(
          key: 'r01.alpha.single-layer-seal',
          mechanicId: BoardMechanicId.singleLayerSeal,
        ),
      ),
      if (layered)
        BoardMechanicBinding(
          rule: LayeredSealRule(sealCount: sealCount, layers: 2),
          skin: BoardMechanicSkin(
            key: 'r01.alpha.layered-seal',
            mechanicId: BoardMechanicId.layeredSeal,
          ),
        ),
      if (linePower)
        BoardMechanicBinding(
          rule: LinePowerRule(requiredActivations: 1),
          skin: BoardMechanicSkin(
            key: 'r01.alpha.line-power',
            mechanicId: BoardMechanicId.linePower,
          ),
        ),
    ],
  );
}

MathDifficulty _mathDifficulty(MathDifficulty source, Puzzle puzzle) {
  final operators = puzzle.tokens
      .where((token) => token.kind == EquationTokenKind.operator)
      .map((token) => token.label)
      .toList();
  final requiresParentheses = puzzle.tokens.any((token) => token.isParenthesis);
  return MathDifficulty(
    tier: source.tier,
    compositionTier: source.compositionTier,
    readingTier: source.readingTier,
    reasoningSteps: operators.length,
    operatorKindCount: operators.toSet().length,
    usesOrderOfOperations:
        requiresParentheses ||
        (operators.any(const {'+', '-'}.contains) &&
            operators.any(const {'×', '÷'}.contains)),
    requiresParentheses: requiresParentheses,
  );
}

Set<String> _buriedIds(Puzzle puzzle) => {
  for (final token in puzzle.tokens)
    if (token.kind == EquationTokenKind.operator) token.id,
  puzzle.tokens.lastWhere((token) => token.kind == EquationTokenKind.number).id,
};

LearningVariantProfile _buildProfile(StageDefinition stage, _Problem data) =>
    LearningVariantProfile(
      stageId: stage.id,
      primarySkillId: stage.learningPlan.primarySkillId,
      relationSchemaId: data.relationSchema,
      answerAstShapeId: data.astShape,
      operandBandId: data.operandBand,
      unknownPositionId: data.unknownPosition,
      contextFamilyId: data.contextFamily,
      representationId: data.representation,
      problemSeed: stage.seed,
      boardSeed: stage.boardVariants.variants.last.seed,
    );

Puzzle _buildPuzzle(StageDefinition stage, _Problem data) {
  final tokens = _tokens(stage.id, data.expression);
  final evaluation = const EquationEngine().evaluate(tokens);
  if (!evaluation.isSuccess) {
    throw StateError('Invalid authored expression at ${stage.id}.');
  }
  final support = PuzzleLearningSupport(
    learningObjective: data.objective,
    hintSteps: [
      PuzzleHintStep(
        kind: PuzzleHintKind.observation,
        message: data.observation,
      ),
      PuzzleHintStep(
        kind: PuzzleHintKind.relationship,
        message: data.relationship,
      ),
      PuzzleHintStep(
        kind: PuzzleHintKind.partialExpression,
        message: data.partialExpression,
      ),
    ],
    misconceptionFeedback: [
      PuzzleMisconceptionFeedback(
        category: PuzzleMisconceptionCategory.incompleteExpression,
        message:
            '문장의 수량을 빠뜨리지 않도록 ${tokens.map((t) => t.label).join(' ')} 조각을 모두 한 번씩 사용하세요.',
      ),
      const PuzzleMisconceptionFeedback(
        category: PuzzleMisconceptionCategory.tokenSelection,
        message: '같은 값이라도 각 조각은 한 번만 사용할 수 있어요. 문장에 나온 수량과 연산만 선택하세요.',
      ),
      PuzzleMisconceptionFeedback(
        category: PuzzleMisconceptionCategory.syntax,
        message: tokens.any((token) => token.isParenthesis)
            ? '괄호 안에도 완전한 식을 만들고, 여는 괄호와 닫는 괄호를 짝지으세요.'
            : '수 다음에는 연산자, 연산자 다음에는 수가 오도록 순서를 확인하세요.',
      ),
      PuzzleMisconceptionFeedback(
        category: PuzzleMisconceptionCategory.quantityRelationship,
        message: data.relationship,
      ),
      PuzzleMisconceptionFeedback(
        category: PuzzleMisconceptionCategory.operationOrder,
        message: data.partialExpression,
      ),
    ],
    workedSolutionSteps: [
      PuzzleWorkedSolutionStep(
        expression: data.firstWorkedExpression,
        explanation: data.firstWorkedExplanation,
      ),
      PuzzleWorkedSolutionStep(
        expression: '${data.expression} = ${evaluation.value}',
        explanation: data.explanation,
      ),
    ],
    transferPrompt: PuzzleTransferPrompt(
      question: data.transferQuestion,
      expectedExpression: data.transferExpression,
    ),
  );
  return Puzzle(
    id: stage.puzzleId,
    stageLabel:
        '${stage.id.startsWith('r02-') ? '규칙과 패턴의 숲' : '계산의 평원'} · C${stage.chapterId.substring(5)} S${stage.number.toString().padLeft(2, '0')}',
    concept: data.concept,
    question: data.question,
    visualDescription: data.visualDescription,
    target: evaluation.value!,
    tokens: List.unmodifiable(tokens),
    requiredTokenIds: Set.unmodifiable(tokens.map((token) => token.id)),
    allowedExpressionSignatures: {evaluation.expression!.signature},
    hints: List.unmodifiable(support.hintSteps.map((hint) => hint.message)),
    explanation: data.explanation,
    learningSupport: support,
    sentenceMath: SentenceMathProblem.fromLegacyQuestion(
      question: data.question,
      relationshipExplanation: data.relationship,
      intendedExpression: data.expression,
      relationSchemaId: data.relationSchema,
      unknownPositionId: data.unknownPosition,
      contextFamilyId: data.contextFamily,
      representationId: data.representation,
      // R1 records are text equivalents, not implemented visual tables.
      presentationKind:
          stage.id.startsWith('r02-') ||
              stage.chapterId == 'r01-c04' ||
              stage.chapterId == 'r01-c05' ||
              stage.chapterId == 'r01-c06'
          ? ProblemPresentationKind.textRecord
          : ProblemPresentationKind.prose,
    ),
  );
}

List<EquationToken> _tokens(String stageId, String expression) {
  final lexemes = RegExp(r'\d+|[+\-×÷()]').allMatches(expression);
  return [
    for (final (index, match) in lexemes.indexed)
      EquationToken(
        id: '$stageId-t${index + 1}',
        label: match.group(0)!,
        kind: switch (match.group(0)!) {
          '(' => EquationTokenKind.leftParenthesis,
          ')' => EquationTokenKind.rightParenthesis,
          '+' || '-' || '×' || '÷' => EquationTokenKind.operator,
          _ => EquationTokenKind.number,
        },
      ),
  ];
}

class _Problem {
  const _Problem({
    required this.expression,
    required this.concept,
    required this.question,
    required this.objective,
    required this.observation,
    required this.relationship,
    required this.partialExpression,
    required this.firstWorkedExpression,
    required this.firstWorkedExplanation,
    required this.explanation,
    required this.transferQuestion,
    required this.transferExpression,
    required this.relationSchema,
    required this.astShape,
    required this.contextFamily,
    this.operandBand = 'single-digit-inputs',
    this.unknownPosition = 'result',
    this.representation = 'word-problem',
    this.sourceStageId,
    required this.visualDescription,
  });

  final String expression;
  final String concept;
  final String question;
  final String objective;
  final String observation;
  final String relationship;
  final String partialExpression;
  final String firstWorkedExpression;
  final String firstWorkedExplanation;
  final String explanation;
  final String transferQuestion;
  final String transferExpression;
  final String relationSchema;
  final String astShape;
  final String operandBand;
  final String unknownPosition;
  final String contextFamily;
  final String representation;
  final String? sourceStageId;
  final String visualDescription;
}

const Map<String, _Problem> _authored = {
  'r01-c01-s01': _Problem(
    expression: '3+2',
    concept: '두 수량 합치기',
    question: '빨간 꽃 3송이와 노란 꽃 2송이를 함께 심습니다. 모두 몇 송이일까요?',
    objective: '서로 다른 두 모둠을 합칠 때 덧셈으로 나타낸다.',
    observation: '빨간 꽃과 노란 꽃은 따로 세었지만, 마지막에는 함께 세어요.',
    relationship: '따로 있는 3송이와 2송이를 모으므로 두 수를 더해요.',
    partialExpression: '빨간 꽃 수 3 뒤에 +를 놓고 노란 꽃 수를 이어 보세요.',
    firstWorkedExpression: '3 = 3',
    firstWorkedExplanation: '빨간 꽃 모둠의 수량을 첫 수 3으로 나타내요.',
    explanation: '3에 노란 꽃 2를 더하면 모두 5송이입니다.',
    transferQuestion: '나비 4마리와 벌 3마리를 함께 세는 식은 무엇일까요?',
    transferExpression: '4+3',
    relationSchema: 'combine-two-disjoint-sets',
    astShape: 'add',
    contextFamily: 'color-subsets-of-one-collection',
    visualDescription:
        '빨간 꽃 모둠 3송이와 노란 꽃 모둠 2송이입니다. 색을 구분하지 않아도 문장으로 수량을 읽을 수 있습니다.',
  ),
  'r01-c01-s02': _Problem(
    expression: '7-3',
    concept: '꺼낸 뒤 남은 수',
    question: '바구니에 사과가 7개 있습니다. 3개를 나누어 주면 몇 개가 남을까요?',
    objective: '처음 수량에서 꺼낸 수량을 빼서 남은 수를 구한다.',
    observation: '처음에는 7개이고, 나누어 준 3개는 바구니 밖으로 나가요.',
    relationship: '남은 사과는 처음 7개에서 꺼낸 3개를 빼서 구해요.',
    partialExpression: '처음 수 7에서 시작하고, - 뒤에 꺼낸 수를 놓으세요.',
    firstWorkedExpression: '7 = 7',
    firstWorkedExplanation: '나누어 주기 전 바구니의 수량 7을 기준으로 삼아요.',
    explanation: '7에서 3을 빼면 바구니에 4개가 남습니다.',
    transferQuestion: '빵 8개 중 2개를 먹었을 때 남은 수를 나타내는 식은?',
    transferExpression: '8-2',
    relationSchema: 'take-away-from-initial-set',
    astShape: 'subtract',
    contextFamily: 'consumable-sharing',
    visualDescription: '바구니 속 사과 7개 중 3개가 밖으로 이동한 상황입니다.',
  ),
  'r01-c01-s03': _Problem(
    expression: '4+5',
    concept: '사용하기 전 수 찾기',
    question: '동굴에서 횃불 5개를 쓰고 4개가 남았습니다. 동굴에 들어가기 전에는 몇 개를 갖고 있었을까요?',
    objective: '남은 수에 사용한 수를 다시 합쳐 변화 전의 수량을 구한다.',
    observation: '4개는 지금 남은 수이고, 5개는 이미 사용한 수예요. 사용하기 전을 물어요.',
    relationship: '쓴 횃불도 처음에는 가지고 있었어요. 남은 수와 사용한 수를 합쳐 처음 수를 찾아요.',
    partialExpression: '남은 4에 사용한 5를 다시 합치는 부분식을 만들어 보세요.',
    firstWorkedExpression: '9-5 = 4',
    firstWorkedExplanation: '처음에 9개였다면 5개를 쓰고 4개가 남아 문장의 조건과 맞아요.',
    explanation: '남은 4개와 쓴 5개를 합치면 처음 횃불은 9개입니다. 썼다는 말만 보고 빼면 안 돼요.',
    transferQuestion: '식량 2개를 쓰고 6개가 남았습니다. 출발할 때 가진 수를 나타내는 식은?',
    transferExpression: '6+2',
    relationSchema: 'recover-initial-from-remainder-and-outflow',
    astShape: 'add',
    contextFamily: 'expedition-supply-reconstruction',
    unknownPosition: 'initial-quantity',
    visualDescription: '사용한 횃불 5개와 남은 횃불 4개입니다. 알 수 없는 수는 동굴에 들어가기 전의 전체 수입니다.',
  ),
  'r01-c01-s04': _Problem(
    expression: '9-4',
    concept: '옮긴 뒤 내 몫 찾기',
    question: '내 가방에 열쇠 9개가 있습니다. 동료의 가방으로 4개를 옮기면 내 가방에는 몇 개가 남을까요?',
    objective: '물건의 위치가 바뀔 때 처음 장소에 남은 수량을 구한다.',
    observation: '두 가방을 합친 수가 아니라 내 가방에 남은 수만 물어요.',
    relationship: '옮긴 열쇠도 탐험대에는 남아 있지만 내 가방에서는 빠져요. 내 수량에서 옮긴 수를 빼요.',
    partialExpression: '내 가방의 9에서 동료에게 옮긴 4를 빼는 부분식을 만드세요.',
    firstWorkedExpression: '5+4 = 9',
    firstWorkedExplanation: '내 가방에 남은 5개와 옮긴 4개를 합치면 처음 9개와 같아요.',
    explanation: '내 가방의 9에서 옮긴 4를 빼면 5개가 남습니다. 탐험대 전체 수와 내 가방의 수는 달라요.',
    transferQuestion: '보급소의 밧줄 10개 중 6개를 동료에게 옮겼습니다. 보급소에 남은 수를 나타내는 식은?',
    transferExpression: '10-6',
    relationSchema: 'take-away-from-initial-set',
    astShape: 'subtract',
    contextFamily: 'inventory-relocation',
    visualDescription:
        '내 가방의 열쇠 9개 중 4개가 동료 가방으로 이동합니다. 다른 가방을 더하지 않고 내 가방에 남은 수를 묻습니다.',
  ),
  'r01-c01-s05': _Problem(
    expression: '6+3',
    concept: '더 많은 수 구하기',
    question: '북쪽 길은 6칸입니다. 남쪽 길보다 3칸 짧다면 남쪽 길은 몇 칸일까요?',
    objective: '짧은 쪽의 수와 차이를 이용해 더 긴 쪽의 수량을 구한다.',
    observation: '6칸은 북쪽 길의 길이이고, 3칸은 두 길의 차이예요. 남쪽 길을 물어요.',
    relationship: '남쪽은 북쪽보다 길어요. 짧은 길에 차이를 보태야 긴 길의 길이가 돼요.',
    partialExpression: '짧은 길 6에 차이 3을 보태는 부분식을 만들어 보세요.',
    firstWorkedExpression: '9-3 = 6',
    firstWorkedExplanation: '남쪽이 9칸이면 3칸 짧은 북쪽이 6칸이 되어 조건과 맞아요.',
    explanation: '짧은 북쪽 6칸에 차이 3칸을 더하면 남쪽은 9칸입니다. 짧다는 말만 보고 빼지 않아요.',
    transferQuestion: '파란 줄은 5칸이고 빨간 줄보다 2칸 짧습니다. 빨간 줄을 나타내는 식은?',
    transferExpression: '5+2',
    relationSchema: 'compare-more-than-reference',
    astShape: 'add',
    contextFamily: 'route-length-comparison',
    unknownPosition: 'larger-compared-quantity',
    visualDescription: '북쪽 길 6칸은 남쪽보다 3칸 짧습니다. 남쪽 길 전체의 길이는 알려져 있지 않습니다.',
  ),
  'r01-c01-s06': _Problem(
    expression: '10-6',
    concept: '목표까지 부족한 양',
    question: '다리를 열려면 빛돌 10개가 필요합니다. 지금 6개가 있다면 빛돌을 몇 개 더 찾아야 할까요?',
    objective: '필요한 전체와 현재 수량의 차이로 추가로 필요한 양을 구한다.',
    observation: '10개는 다리를 여는 목표이고, 6개는 이미 가진 수예요. 찾을 수만 물어요.',
    relationship: '이미 가진 빛돌은 다시 찾지 않아요. 목표에서 가진 수를 빼면 부족한 양이 돼요.',
    partialExpression: '목표 10에서 이미 가진 6을 빼는 부분식을 만들어 보세요.',
    firstWorkedExpression: '6+4 = 10',
    firstWorkedExplanation: '현재 6개에 4개를 보태면 필요한 빛돌 10개를 채워요.',
    explanation: '목표 10에서 가진 6을 빼면 4개가 부족합니다. 더 찾는 양을 묻더라도 식은 뺄셈이에요.',
    transferQuestion: '문을 열려면 열쇠 14개가 필요하고 9개를 모았습니다. 부족한 양을 나타내는 식은?',
    transferExpression: '14-9',
    relationSchema: 'target-minus-current-for-missing-amount',
    astShape: 'subtract',
    operandBand: 'ten-and-single-digit',
    contextFamily: 'expedition-resource-threshold',
    unknownPosition: 'missing-increase',
    visualDescription: '다리의 목표 빛돌은 10개이고 보유한 빛돌은 6개입니다. 추가로 찾아야 할 수를 묻습니다.',
  ),
  'r01-c01-s07': _Problem(
    expression: '8+7',
    concept: '열을 넘는 합',
    question: '돌다리를 건너며 식량 7개를 쓰고 8개가 남았습니다. 출발할 때 가지고 있던 식량은 몇 개일까요?',
    objective: '남은 수와 사용한 수를 합쳐 10을 넘는 처음 수량을 구한다.',
    observation: '7개는 이미 쓴 식량이고, 8개는 남은 식량이에요. 출발할 때를 물어요.',
    relationship: '출발할 때의 식량에는 지금 남은 것과 길에서 쓴 것이 모두 포함돼요.',
    partialExpression: '남은 8과 사용한 7을 +로 연결하세요. 합이 10을 넘어도 관계는 같아요.',
    firstWorkedExpression: '8+2 = 10',
    firstWorkedExplanation: '7을 2와 5로 나누어 8에 2를 먼저 더하면 10이 돼요.',
    explanation: '남은 8과 쓴 7을 합치면 처음 식량은 15개입니다. 처음 수를 확인하려면 15에서 7을 빼 봐요.',
    transferQuestion: '물통 5개를 쓰고 9개가 남았습니다. 출발할 때의 수를 나타내는 식은?',
    transferExpression: '9+5',
    relationSchema: 'recover-initial-from-remainder-and-outflow',
    astShape: 'add',
    operandBand: 'single-digit-inputs-sum-over-ten',
    contextFamily: 'expedition-supply-reconstruction',
    unknownPosition: 'initial-quantity',
    visualDescription: '출발 때의 식량은 알려져 있지 않습니다. 사용한 식량은 7개이고 남은 식량은 8개입니다.',
  ),
  'r01-c01-s08': _Problem(
    expression: '13-5',
    concept: '전체에서 숨은 부분 찾기',
    question: '지도에 길이 모두 13칸입니다. 보이는 길은 5칸이고 나머지는 안개 속입니다. 가려진 길은 몇 칸일까요?',
    objective: '전체에서 알려진 부분을 빼고 10을 거치는 계산으로 숨은 부분을 구한다.',
    observation: '13칸은 전체 길이고, 5칸은 그 안에서 보이는 부분이에요.',
    relationship: '보이는 길과 가려진 길을 합치면 전체가 돼요. 전체에서 보이는 부분을 빼요.',
    partialExpression: '전체 13에서 보이는 5를 빼는 부분식을 만들어 보세요.',
    firstWorkedExpression: '13-3 = 10',
    firstWorkedExplanation: '보이는 5칸을 3칸과 2칸으로 나누어 먼저 3칸을 제외하면 10칸이에요.',
    explanation:
        '10에서 나머지 2를 제외하면 가려진 길은 8칸입니다. 길이 없어진 것이 아니라 전체 중 숨은 부분을 구해요.',
    transferQuestion: '벽화는 모두 14칸이고 6칸이 보입니다. 천에 가려진 부분을 나타내는 식은?',
    transferExpression: '14-6',
    relationSchema: 'whole-minus-known-part-find-hidden-part',
    astShape: 'subtract',
    operandBand: 'two-digit-minuend-crosses-ten',
    contextFamily: 'partially-visible-route',
    unknownPosition: 'hidden-part',
    visualDescription:
        '전체 길 13칸 가운데 5칸이 보이고 나머지는 안개에 가려져 있습니다. 길이 줄어드는 사건은 없습니다.',
  ),
  'r01-c01-s09': _Problem(
    expression: '5+3+4',
    concept: '세 수량 합치기',
    question: '아침에 열매 5개, 낮에 3개, 저녁에 4개를 수확했습니다. 하루 동안 모두 몇 개를 수확했을까요?',
    objective: '세 번의 수량을 빠뜨리지 않고 두 번의 덧셈으로 합친다.',
    observation: '아침, 낮, 저녁의 수량이 모두 필요해요.',
    relationship: '하루 수확량은 아침 5개와 낮 3개와 저녁 4개를 모두 더한 수예요.',
    partialExpression: '먼저 5 + 3을 만들고, 저녁의 4를 +로 이어 보세요.',
    firstWorkedExpression: '5+3 = 8',
    firstWorkedExplanation: '아침과 낮의 수확량을 합치면 8개예요.',
    explanation: '8개에 저녁 4개를 더하면 12개입니다. 세 수량을 더한 식은 5+3+4입니다.',
    transferQuestion: '세 상자의 공이 2개, 6개, 3개라면 전체 수를 나타내는 식은?',
    transferExpression: '2+6+3',
    relationSchema: 'combine-three-disjoint-sets',
    astShape: 'add-add',
    contextFamily: 'daily-harvest-batches',
    visualDescription: '아침 5개, 낮 3개, 저녁 4개라는 세 묶음이 시간 순서로 나열되어 있습니다.',
  ),
  'r01-c01-s10': _Problem(
    expression: '16-7+3',
    concept: '줄어든 뒤 늘어난 수',
    question: '씨앗이 16개 있습니다. 7개를 심고 새 씨앗 3개를 받았습니다. 지금 가진 씨앗은 몇 개일까요?',
    objective: '줄어드는 사건과 늘어나는 사건을 순서대로 뺄셈과 덧셈으로 나타낸다.',
    observation: '처음 수, 심은 수, 새로 받은 수를 구분하세요.',
    relationship: '심은 7개는 줄어드므로 빼고, 받은 3개는 늘어나므로 더해요.',
    partialExpression: '먼저 16 - 7을 만들고, 새로 받은 3을 더하세요.',
    firstWorkedExpression: '16-7 = 9',
    firstWorkedExplanation: '씨앗을 심고 나면 가진 씨앗은 9개예요.',
    explanation: '남은 9개에 새 씨앗 3개를 더하면 12개입니다. 사건 순서대로 16-7+3을 만들어요.',
    transferQuestion: '구슬 15개 중 6개를 쓰고 4개를 받으면 가진 수를 나타내는 식은?',
    transferExpression: '15-6+4',
    relationSchema: 'initial-minus-outflow-plus-inflow',
    astShape: 'subtract-add',
    operandBand: 'two-digit-initial-single-digit-changes',
    contextFamily: 'inventory-change-events',
    visualDescription: '처음 씨앗 16개, 심음 7개, 받음 3개가 이 순서대로 일어납니다.',
  ),
  'r01-c02-s01': _Problem(
    expression: '4×3',
    concept: '같은 묶음의 전체 수',
    question: '화분마다 씨앗을 4개씩 심습니다. 화분 3개에 심는 씨앗은 모두 몇 개일까요?',
    objective: '한 묶음의 수와 묶음 수를 구분하여 곱셈으로 전체를 구한다.',
    observation: '4는 한 화분의 씨앗 수이고, 3은 화분의 수예요.',
    relationship: '4개가 3번 반복되므로 4를 3번 더하는 대신 곱셈으로 나타내요.',
    partialExpression: '한 화분의 4 뒤에 ×를 놓고 화분 수 3을 이어 보세요.',
    firstWorkedExpression: '4+4+4 = 12',
    firstWorkedExplanation: '화분 세 개의 씨앗을 각각 4개씩 더하면 12개예요.',
    explanation: '같은 4개 묶음 3개를 4×3으로 나타내면 모두 12개입니다.',
    transferQuestion: '주머니마다 돌 5개씩, 주머니가 2개면 전체 수를 나타내는 식은?',
    transferExpression: '5×2',
    relationSchema: 'equal-size-groups-total',
    astShape: 'multiply',
    contextFamily: 'container-content-groups',
    visualDescription:
        '화분 3개에 씨앗이 각각 4개씩 있습니다. 한 묶음 4, 묶음 수 3을 문장으로 읽을 수 있습니다.',
  ),
  'r01-c02-s02': _Problem(
    expression: '5×4',
    concept: '배열의 전체 수',
    question: '한 줄에 꽃이 5송이씩 있고 같은 줄이 4줄입니다. 이 화단의 꽃은 모두 몇 송이일까요?',
    objective: '배열에서 한 줄의 수와 줄 수를 찾아 곱셈으로 나타낸다.',
    observation: '각 줄의 5송이가 4줄에 똑같이 반복돼요.',
    relationship: '한 줄 5송이에 줄 수 4를 곱하면 배열의 전체 꽃 수예요.',
    partialExpression: '한 줄의 수 5와 줄 수 4를 ×로 연결하세요.',
    firstWorkedExpression: '5+5+5+5 = 20',
    firstWorkedExplanation: '네 줄의 5송이를 모두 더하면 20송이예요.',
    explanation: '5송이씩 4줄이므로 식은 5×4이고 꽃은 20송이입니다.',
    transferQuestion: '한 줄에 의자 6개씩 3줄이면 전체 의자를 나타내는 식은?',
    transferExpression: '6×3',
    relationSchema: 'rectangular-array-total',
    astShape: 'multiply',
    contextFamily: 'rectangular-spatial-array',
    representation: 'row-described-array',
    visualDescription:
        '각 줄에 꽃 5송이가 있는 줄이 4개입니다. 배열 그림을 보지 못해도 한 줄 5와 줄 수 4로 풀 수 있습니다.',
  ),
  'r01-c02-s03': _Problem(
    expression: '12÷3',
    concept: '같은 몫으로 나누기',
    question: '사과 12개를 바구니 3개에 똑같이 나눕니다. 한 바구니에 몇 개씩 들어갈까요?',
    objective: '전체와 나눌 곳의 수로 한 곳의 몫을 구한다.',
    observation: '전체 12개와 바구니 수 3개를 알고, 한 바구니의 몫은 몰라요.',
    relationship: '12개를 같은 크기의 3몫으로 나누므로 전체를 몫의 수로 나눠요.',
    partialExpression: '전체 12 뒤에 ÷를 놓고, 나눌 바구니 수 3을 이어 보세요.',
    firstWorkedExpression: '4×3 = 12',
    firstWorkedExplanation: '바구니마다 4개씩이면 세 바구니에 모두 12개가 돼요.',
    explanation: '12개를 세 곳에 똑같이 나누면 12÷3=4이므로 한 바구니에 4개입니다.',
    transferQuestion: '연필 15자루를 5명에게 똑같이 주면 한 명의 몫을 나타내는 식은?',
    transferExpression: '15÷5',
    relationSchema: 'equal-share-find-group-size',
    astShape: 'divide',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'fair-distribution-to-containers',
    unknownPosition: 'group-size',
    visualDescription: '전체 사과 12개를 바구니 세 개에 똑같이 나눕니다. 각 바구니의 몫을 묻습니다.',
  ),
  'r01-c02-s04': _Problem(
    expression: '18÷3',
    concept: '같은 크기 묶음의 수',
    question: '모종 18개를 화분 하나에 3개씩 심습니다. 화분은 몇 개 필요할까요?',
    objective: '전체와 한 묶음의 수로 필요한 묶음의 개수를 구한다.',
    observation: '18은 전체 모종 수, 3은 화분 하나에 넣는 모종 수예요.',
    relationship: '전체에서 3개씩 몇 번 묶을 수 있는지 알아보므로 18을 3으로 나눠요.',
    partialExpression: '18 ÷ 3을 만들고, 결과가 화분 수라는 점을 확인하세요.',
    firstWorkedExpression: '3×6 = 18',
    firstWorkedExplanation: '화분 여섯 개에 3개씩 심으면 모종 18개를 모두 심어요.',
    explanation: '18개를 3개씩 묶으면 6묶음이므로 필요한 화분은 6개입니다.',
    transferQuestion: '리본 20개를 4개씩 묶으면 묶음 수를 나타내는 식은?',
    transferExpression: '20÷4',
    relationSchema: 'equal-group-find-group-count',
    astShape: 'divide',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'packing-fixed-size-groups',
    unknownPosition: 'group-count',
    visualDescription:
        '모종 전체 18개, 한 화분에 3개씩이라는 묶기 상황입니다. 모종 한 개의 수가 아니라 화분 수를 묻습니다.',
  ),
  'r01-c02-s05': _Problem(
    expression: '4×3+2',
    concept: '묶음과 낱개',
    question: '연필이 4자루씩 든 상자 3개와 낱개 연필 2자루가 있습니다. 연필은 모두 몇 자루일까요?',
    objective: '같은 수의 묶음은 곱셈으로, 따로 있는 낱개는 덧셈으로 나타낸다.',
    observation: '4자루씩 세 상자와 상자 밖의 낱개 2자루를 구분하세요.',
    relationship: '상자 속은 4자루가 세 번 반복되어 곱하고, 낱개 2자루는 따로 더해요.',
    partialExpression: '먼저 4 × 3을 만들고, 낱개 2를 +로 이어 보세요.',
    firstWorkedExpression: '4×3 = 12',
    firstWorkedExplanation: '상자 속 연필은 4자루씩 세 상자이므로 12자루예요.',
    explanation: '상자 속 12자루에 낱개 2자루를 더하면 14자루입니다. 낱개를 상자 수에 더하지 않아요.',
    transferQuestion: '한 봉지에 구슬 5개씩 든 봉지 2개와 낱개 3개를 나타내는 식은?',
    transferExpression: '5×2+3',
    relationSchema: 'equal-groups-plus-remainder',
    astShape: 'multiply-add',
    contextFamily: 'bundle-items',
    visualDescription:
        '연필 4자루가 든 상자 세 개와, 상자 밖 낱개 연필 2자루입니다. 상자 내부와 외부 수량이 모두 문자로 제공됩니다.',
  ),
  'r01-c02-s06': _Problem(
    expression: '5×4-2',
    concept: '묶음에서 빠진 수',
    question: '씨앗 5개씩 든 봉지 4개를 모두 모아 2개를 썼습니다. 남은 씨앗은 몇 개일까요?',
    objective: '같은 묶음의 전체를 곱셈으로 구한 뒤 빠진 수를 뺀다.',
    observation: '봉지 안에는 5개씩 네 묶음이고, 꺼낸 씨앗은 전체에서 2개예요.',
    relationship: '처음 씨앗 수는 5를 네 번 더한 수이고, 꺼낸 2개만 전체에서 빼요.',
    partialExpression: '5 × 4로 처음 수를 만든 뒤 - 2를 이어 보세요.',
    firstWorkedExpression: '5×4 = 20',
    firstWorkedExplanation: '씨앗 5개가 든 네 봉지의 전체는 20개예요.',
    explanation: '전체 20개에서 꺼낸 2개를 빼면 남은 씨앗은 18개입니다.',
    transferQuestion: '구슬 6개씩 든 상자 3개에서 전체 중 4개를 꺼낸 뒤 남은 수를 나타내는 식은?',
    transferExpression: '6×3-4',
    relationSchema: 'equal-groups-minus-global-removal',
    astShape: 'multiply-subtract',
    contextFamily: 'bundle-inventory-removal',
    visualDescription: '한 봉지 5개, 봉지 네 개, 전체에서 꺼낸 수 2개입니다. 봉지마다 2개씩 꺼내지는 않습니다.',
  ),
  'r01-c02-s07': _Problem(
    expression: '18÷3+4',
    concept: '나눈 몫에 더하기',
    question: '사과 18개를 3명에게 똑같이 줍니다. 한 명이 사과 4개를 더 받으면 그 사람은 몇 개일까요?',
    objective: '공평하게 나눈 한 몫을 구한 뒤 그 몫에 추가 수량을 더한다.',
    observation: '18개는 세 사람이 나누고, 4개는 그중 한 사람만 더 받아요.',
    relationship: '한 사람의 몫은 18을 3으로 나눈 수이고, 그 몫에만 4를 더해요.',
    partialExpression: '18 ÷ 3으로 한 몫을 만든 뒤 + 4를 이어 보세요.',
    firstWorkedExpression: '18÷3 = 6',
    firstWorkedExplanation: '세 사람이 공평하게 받으면 각자 6개예요.',
    explanation: '한 사람의 6개에 더 받은 4개를 더하면 그 사람은 10개입니다.',
    transferQuestion: '연필 20자루를 4명에게 나누고 한 명이 3자루 더 받는 수를 나타내는 식은?',
    transferExpression: '20÷4+3',
    relationSchema: 'equal-share-plus-personal-bonus',
    astShape: 'divide-add',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'fair-sharing-with-personal-bonus',
    unknownPosition: 'one-recipient-final-quantity',
    visualDescription: '전체 사과 18개를 세 사람에게 나누며, 한 사람에게만 사과 4개를 추가합니다.',
  ),
  'r01-c02-s08': _Problem(
    expression: '24÷6×2',
    concept: '한 몫을 두 번 모으기',
    question: '꽃 24송이를 6개 화병에 똑같이 꽂습니다. 화병 2개에 꽂힌 꽃은 모두 몇 송이일까요?',
    objective: '한 묶음의 몫을 먼저 구하고 필요한 묶음 수를 곱한다.',
    observation: '24송이는 여섯 화병의 전체이고, 그중 두 화병의 수를 물어요.',
    relationship: '한 화병의 수는 24를 6으로 나누고, 같은 화병 두 개의 수는 그 몫을 두 배 해요.',
    partialExpression: '24 ÷ 6을 먼저 계산하고 그 몫에 × 2를 이어 보세요.',
    firstWorkedExpression: '24÷6 = 4',
    firstWorkedExplanation: '꽃을 공평하게 꽂으면 한 화병에 4송이예요.',
    explanation: '두 화병에는 4송이가 두 번 있으므로 24÷6×2=8송이입니다.',
    transferQuestion: '쿠키 30개를 5접시에 똑같이 놓았을 때 두 접시의 수를 나타내는 식은?',
    transferExpression: '30÷5×2',
    relationSchema: 'equal-share-total-for-selected-groups',
    astShape: 'divide-multiply',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'selected-containers-after-sharing',
    unknownPosition: 'selected-groups-total',
    visualDescription: '꽃 24송이를 화병 여섯 개에 똑같이 배분한 뒤, 그중 두 화병의 꽃을 셉니다.',
  ),
  'r01-c02-s09': _Problem(
    expression: '3×7-5',
    concept: '반복해서 늘고 줄기',
    question: '매일 꽃이 3송이씩 일주일 동안 피었습니다. 그중 5송이를 따면 남은 꽃은 몇 송이일까요?',
    objective: '기간 동안 반복된 증가를 곱셈으로 구한 뒤 한 번의 감소를 뺀다.',
    observation: '일주일은 7일이고, 3송이는 매일 반복되는 수예요. 5송이는 한 번 따요.',
    relationship: '일주일 동안 핀 꽃은 3의 일곱 묶음이고, 전체에서 딴 5송이를 빼요.',
    partialExpression: '3 × 7로 핀 꽃 수를 만들고 - 5를 이어 보세요.',
    firstWorkedExpression: '3×7 = 21',
    firstWorkedExplanation: '하루 3송이씩 7일이면 꽃은 21송이 피어요.',
    explanation: '21송이에서 5송이를 따면 16송이가 남습니다. 딴 수를 매일 빼지는 않아요.',
    transferQuestion: '하루 4개씩 엿새 동안 만든 장식에서 7개를 쓰면 남은 수를 나타내는 식은?',
    transferExpression: '4×6-7',
    relationSchema: 'repeated-inflow-minus-single-outflow',
    astShape: 'multiply-subtract',
    contextFamily: 'growth-followed-by-harvest',
    representation: 'weekly-growth-record',
    visualDescription: '매일 새 꽃 3송이, 기간 7일, 마지막 수확 5송이라는 기록입니다. 처음 핀 꽃은 없습니다.',
  ),
  'r01-c02-s10': _Problem(
    expression: '6×3+4',
    concept: '묶음과 따로 있는 수',
    question: '공방에 의자 6개씩 놓인 방 3개와 복도 의자 4개가 있습니다. 의자는 모두 몇 개일까요?',
    objective: '같은 크기의 여러 묶음과 묶음 밖의 낱개를 구분해 전체를 구한다.',
    observation: '방 세 곳에는 같은 수의 의자가 있고, 복도의 4개는 방 밖에 있어요.',
    relationship: '방 안의 의자 6개가 세 번 반복되고, 복도 의자 4개는 한 번만 더해요.',
    partialExpression: '6 × 3을 먼저 만들고, 방 밖 의자 수 4를 +로 이어 보세요.',
    firstWorkedExpression: '6×3 = 18',
    firstWorkedExplanation: '방 세 곳의 의자는 모두 18개예요.',
    explanation: '방 안 18개와 복도 4개를 합치면 전체 의자는 22개입니다.',
    transferQuestion: '한 줄 5그루인 나무 세 줄과 따로 심은 2그루를 나타내는 식은?',
    transferExpression: '5×3+2',
    relationSchema: 'repeated-room-capacity-plus-outside-part',
    astShape: 'multiply-add',
    contextFamily: 'room-and-corridor-inventory',
    representation: 'floor-inventory-description',
    visualDescription: '각 방 6개씩인 방 세 곳과 복도 4개입니다. 복도 의자를 방마다 더하지 않습니다.',
  ),
  'r01-c03-s01': _Problem(
    expression: '2+3×4',
    concept: '곱셈을 먼저 하는 합',
    question: '낱개 꽃 2송이와 꽃 3송이씩 있는 화단 4곳이 있습니다. 꽃은 모두 몇 송이일까요?',
    objective: '덧셈과 곱셈이 섞인 식에서 묶음의 곱셈을 먼저 계산한다.',
    observation: '낱개 2송이와 화단마다 3송이인 네 묶음을 구분하세요.',
    relationship: '3송이씩 네 곳의 수를 먼저 곱하고, 낱개 2송이를 더해요.',
    partialExpression: '낱개 2 + 묶음 3 × 4를 만들고, 3×4부터 계산하세요.',
    firstWorkedExpression: '3×4 = 12',
    firstWorkedExplanation: '네 화단의 꽃을 먼저 구하면 12송이예요.',
    explanation: '2+3×4에서는 3×4가 먼저입니다. 2+12=14송이며, 2까지 네 번 세지 않아요.',
    transferQuestion: '낱개 구슬 4개와 2개씩 든 상자 3개를 낱개부터 적는 식은?',
    transferExpression: '4+2×3',
    relationSchema: 'outside-part-plus-equal-groups',
    astShape: 'add-multiply',
    contextFamily: 'loose-flowers-and-flowerbeds',
    visualDescription: '낱개 꽃 2송이는 화단 밖에 있습니다. 화단 네 곳에는 각각 꽃 3송이씩 있습니다.',
  ),
  'r01-c03-s02': _Problem(
    expression: '(2+3)×4',
    concept: '합을 한 묶음으로',
    question: '각 화단에 빨간 꽃 2송이와 노란 꽃 3송이를 심습니다. 같은 화단 4곳의 꽃은 모두 몇 송이일까요?',
    objective: '한 묶음 안의 합을 괄호로 묶어 반복 수를 곱한다.',
    observation: '2송이와 3송이는 모두 화단 하나 안의 꽃이에요.',
    relationship: '한 화단의 두 꽃 수를 먼저 더한 뒤, 같은 화단 네 곳을 곱해요.',
    partialExpression: '한 화단을 (2 + 3)으로 묶은 뒤 × 4를 놓으세요.',
    firstWorkedExpression: '2+3 = 5',
    firstWorkedExplanation: '화단 하나에는 두 꽃을 합해 5송이가 있어요.',
    explanation: '한 화단 5송이의 네 묶음이므로 (2+3)×4=20송이입니다. 괄호가 묶음 범위를 알려 줘요.',
    transferQuestion: '한 상자에 연필 3자루와 펜 4자루씩 담은 상자 두 개를 나타내는 식은?',
    transferExpression: '(3+4)×2',
    relationSchema: 'sum-within-each-repeated-group',
    astShape: 'multiply-parenthesized-add',
    contextFamily: 'mixed-colors-within-each-flowerbed',
    visualDescription: '화단마다 빨간 꽃 2송이와 노란 꽃 3송이가 함께 있습니다. 이런 화단 네 곳을 셉니다.',
  ),
  'r01-c03-s03': _Problem(
    expression: '18-2×5',
    concept: '묶음 전체를 빼기',
    question: '도구 18개 중 5명에게 2개씩 줍니다. 남은 도구는 몇 개일까요?',
    objective: '남은 수를 구할 때 나누어 준 묶음의 전체를 곱셈으로 먼저 구한다.',
    observation: '2개는 한 사람이 받는 수이고, 받는 사람은 5명이에요.',
    relationship: '준 도구 전체는 2×5이므로 처음 18개에서 이 전체를 빼요.',
    partialExpression: '18 - 2 × 5를 만들고, 나누어 준 2×5부터 계산하세요.',
    firstWorkedExpression: '2×5 = 10',
    firstWorkedExplanation: '다섯 명에게 두 개씩 주면 모두 10개를 줘요.',
    explanation: '18개에서 10개를 빼면 8개가 남습니다. 18-2를 먼저 계산하지 않아요.',
    transferQuestion: '쿠폰 25장 중 네 명에게 3장씩 주고 남은 수를 나타내는 식은?',
    transferExpression: '25-3×4',
    relationSchema: 'initial-minus-equal-groups-outflow',
    astShape: 'subtract-multiply',
    operandBand: 'two-digit-initial-single-digit-factors',
    contextFamily: 'inventory-distributed-to-people',
    visualDescription: '전체 도구 18개에서 한 사람 2개씩 다섯 사람에게 줍니다. 나머지 도구를 묻습니다.',
  ),
  'r01-c03-s04': _Problem(
    expression: '24÷3+6',
    concept: '나눗셈을 먼저 하는 합',
    question: '모종 24개를 3팀에게 똑같이 줍니다. 한 팀이 6개를 더 받으면 그 팀은 몇 개일까요?',
    objective: '전체를 나눈 한 몫에 추가량을 더하며 나눗셈의 우선 순서를 적용한다.',
    observation: '24개는 세 팀의 전체이고, 6개는 한 팀에게만 추가돼요.',
    relationship: '한 팀의 몫인 24÷3을 먼저 구한 뒤, 그 팀이 더 받은 6을 더해요.',
    partialExpression: '24 ÷ 3 + 6을 만들고, 24÷3부터 계산하세요.',
    firstWorkedExpression: '24÷3 = 8',
    firstWorkedExplanation: '세 팀이 똑같이 나누면 한 팀에 모종 8개예요.',
    explanation: '한 팀의 8개에 추가 6개를 더하면 14개입니다. 3과 6을 먼저 더하지 않아요.',
    transferQuestion: '포인트 36점을 6명에게 나누고 한 명에게 2점을 더 줄 때 그 사람의 식은?',
    transferExpression: '36÷6+2',
    relationSchema: 'equal-share-before-extra-recipient-quantity',
    astShape: 'divide-add',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'team-allotment-with-additional-supply',
    visualDescription: '전체 모종 24개, 팀 세 곳, 한 팀에만 추가한 모종 6개입니다.',
  ),
  'r01-c03-s05': _Problem(
    expression: '(12-4)×3',
    concept: '남은 한 묶음을 반복',
    question: '각 상자의 씨앗 12개 중 4개를 남깁니다. 상자 3개에서 꺼낼 씨앗은 모두 몇 개일까요?',
    objective: '한 묶음에서 제외한 차이를 괄호로 묶고 반복 묶음 수를 곱한다.',
    observation: '12개와 남겨 둘 4개는 상자 하나의 수량이고, 이런 상자가 세 개예요.',
    relationship: '상자마다 꺼낼 수는 12-4이고, 같은 수를 세 번 모아요.',
    partialExpression: '상자 하나를 (12 - 4)로 묶고 × 3을 이어 보세요.',
    firstWorkedExpression: '12-4 = 8',
    firstWorkedExplanation: '상자 한 개에서는 씨앗 8개를 꺼내요.',
    explanation: '세 상자에서 8개씩 꺼내므로 (12-4)×3=24개입니다. 남겨 둘 4개는 상자마다 있어요.',
    transferQuestion: '펌프가 하루 15시간 중 6시간 멈출 때 이틀의 작동 시간을 나타내는 식은?',
    transferExpression: '(15-6)×2',
    relationSchema: 'difference-within-each-repeated-group',
    astShape: 'multiply-parenthesized-subtract',
    operandBand: 'two-digit-group-total-single-digit-removal',
    contextFamily: 'per-container-reserve-and-use',
    visualDescription: '상자마다 씨앗 12개 중 4개는 남기고 나머지를 꺼냅니다. 같은 상자 세 개가 있습니다.',
  ),
  'r01-c03-s06': _Problem(
    expression: '36÷(3+3)',
    concept: '나눌 곳의 합',
    question: '꽃 36송이를 어린이 3명과 어른 3명에게 똑같이 줍니다. 한 사람은 몇 송이를 받을까요?',
    objective: '나눌 사람 수를 합해 괄호로 묶은 뒤 전체를 그 합으로 나눈다.',
    observation: '꽃 36송이는 전체이고, 받는 사람은 두 모둠의 3명과 3명이에요.',
    relationship: '받는 사람 수를 3+3으로 먼저 합한 뒤, 꽃 전체를 같은 몫으로 나눠요.',
    partialExpression: '전체 36 뒤에 ÷ (3 + 3)을 이어 두 모둠 모두에게 나누세요.',
    firstWorkedExpression: '3+3 = 6',
    firstWorkedExplanation: '어린이와 어른을 합하면 받는 사람은 6명이에요.',
    explanation: '꽃 36송이를 6명에게 나누면 한 사람은 6송이입니다. 36÷(3+3)처럼 합이 나누는 수예요.',
    transferQuestion: '공 42개를 4명과 3명이 똑같이 나눌 때 한 사람의 몫을 나타내는 식은?',
    transferExpression: '42÷(4+3)',
    relationSchema: 'equal-share-by-combined-recipient-groups',
    astShape: 'divide-parenthesized-add',
    operandBand: 'two-digit-total-composite-divisor',
    contextFamily: 'combined-age-groups-sharing',
    unknownPosition: 'one-recipient-share',
    visualDescription: '꽃은 36송이, 어린이와 어른은 각각 3명입니다. 두 3은 별개의 사람 모둠 수입니다.',
  ),
  'r01-c03-s07': _Problem(
    expression: '6×6',
    concept: '같은 값의 다른 역할',
    question: '꽃잎이 6장씩인 꽃 6송이가 있습니다. 꽃잎은 모두 몇 장일까요?',
    objective: '값이 같아도 한 묶음의 수와 묶음 수를 서로 다른 조각으로 사용한다.',
    observation: '첫 6은 한 꽃의 꽃잎 수, 다른 6은 꽃의 송이 수예요.',
    relationship: '한 꽃의 꽃잎 6장이 여섯 번 반복되므로 두 6을 곱해요.',
    partialExpression: '꽃잎 수 6과 꽃 수 6을 각각 하나씩 놓고 ×로 연결하세요.',
    firstWorkedExpression: '6+6+6+6+6+6 = 36',
    firstWorkedExplanation: '여섯 꽃의 꽃잎을 더하면 36장이에요.',
    explanation: '6×6=36장입니다. 두 숫자의 값이 같아도 서로 다른 수량이므로 6 조각 두 개를 사용해요.',
    transferQuestion: '한 줄 8개씩인 의자 여덟 줄을 나타내는 식은?',
    transferExpression: '8×8',
    relationSchema: 'equal-valued-group-size-and-group-count',
    astShape: 'multiply',
    contextFamily: 'petals-per-flower-and-flower-count',
    visualDescription:
        '꽃 한 송이의 꽃잎 6장과 꽃 여섯 송이라는 별개의 수량입니다. 값이 같은 조각도 두 개 필요합니다.',
  ),
  'r01-c03-s08': _Problem(
    expression: '40-18÷3',
    concept: '나눈 한 몫을 빼기',
    question: '창고 씨앗 40개 중 18개를 사흘간 같은 수씩 심습니다. 첫날 뒤 남은 씨앗은 몇 개일까요?',
    objective: '나누어 쓸 전체에서 한 번의 몫을 구한 뒤 처음 수에서 그 몫을 뺀다.',
    observation: '18개를 하루에 모두 심지 않고, 사흘 동안 같은 수씩 심어요.',
    relationship: '첫날 쓴 수는 18÷3이고, 창고의 처음 수 40에서 하루 몫만 빼요.',
    partialExpression: '40 - 18 ÷ 3을 만들고, 첫날의 몫 18÷3을 먼저 구하세요.',
    firstWorkedExpression: '18÷3 = 6',
    firstWorkedExplanation: '하루에 심는 씨앗은 6개예요.',
    explanation: '첫날에는 6개만 심으므로 창고에 40-6=34개가 남습니다. 나눗셈을 뺄셈보다 먼저 해요.',
    transferQuestion: '물 50L 중 24L를 나흘간 같은 양씩 쓰면 첫날 뒤 남은 양을 나타내는 식은?',
    transferExpression: '50-24÷4',
    relationSchema: 'initial-minus-one-share-of-planned-outflow',
    astShape: 'subtract-divide',
    operandBand: 'two-digit-initial-two-digit-shared-total',
    contextFamily: 'multi-day-inventory-consumption',
    visualDescription:
        '처음 창고 수는 40개, 사흘 전체 사용량은 18개입니다. 하루 사용량과 첫날 이후 남은 수를 구합니다.',
  ),
  'r01-c03-s09': _Problem(
    expression: '3×(8-2)',
    concept: '묶음 안의 빈자리 제외',
    question: '화단 3곳에 각각 자리 8개가 있고 2자리씩 비워 둡니다. 심을 꽃은 모두 몇 송이일까요?',
    objective: '묶음 수를 앞에 놓아도 한 묶음 안의 차이를 괄호로 먼저 계산한다.',
    observation: '화단 하나마다 8자리 중 2자리를 비우며, 이런 화단이 세 곳이에요.',
    relationship: '한 화단에 심을 수는 8-2이고, 이 수를 화단 세 곳만큼 곱해요.',
    partialExpression: '화단 수 3 × (8 - 2)를 만들고 괄호 안을 먼저 계산하세요.',
    firstWorkedExpression: '8-2 = 6',
    firstWorkedExplanation: '한 화단에는 꽃을 6송이 심어요.',
    explanation: '세 화단에 6송이씩 심어 3×(8-2)=18송이입니다. 비워 둘 자리는 화단마다 두 자리예요.',
    transferQuestion: '길이 9m인 네 구간에서 각 구간 3m씩 비우는 울타리 길이를 나타내는 식은?',
    transferExpression: '4×(9-3)',
    relationSchema: 'group-count-times-usable-capacity',
    astShape: 'multiply-parenthesized-subtract',
    contextFamily: 'per-bed-capacity-with-empty-spaces',
    visualDescription:
        '화단은 세 곳이고 각 화단마다 전체 자리 8개 중 2개가 비어 있습니다. 한 자리에는 꽃 한 송이를 심습니다.',
  ),
  'r01-c03-s10': _Problem(
    expression: '(24+12)÷6',
    concept: '합친 전체를 나누기',
    question: '앞밭의 씨앗 24개와 뒷밭의 12개를 합쳐 6팀에게 똑같이 줍니다. 한 팀은 몇 개일까요?',
    objective: '두 수량을 합친 전체를 괄호로 표현한 뒤 같은 몫으로 나눈다.',
    observation: '두 밭의 씨앗을 먼저 한데 모으고, 모은 전체를 여섯 팀에게 줘요.',
    relationship: '나눌 전체는 24+12이고, 그 합을 팀 수 6으로 나눠요.',
    partialExpression: '모은 전체 (24 + 12) 뒤에 ÷ 6을 이어 보세요.',
    firstWorkedExpression: '24+12 = 36',
    firstWorkedExplanation: '두 밭에서 모은 씨앗은 전체 36개예요.',
    explanation: '36개를 여섯 팀에게 나누면 한 팀에 6개입니다. (24+12)÷6의 괄호가 모은 전체를 표시해요.',
    transferQuestion: '나무 30그루와 18그루를 합쳐 6구역에 똑같이 심는 한 구역의 수를 나타내는 식은?',
    transferExpression: '(30+18)÷6',
    relationSchema: 'combine-supplies-then-equal-share',
    astShape: 'divide-parenthesized-add',
    operandBand: 'two-digit-parts-single-digit-divisor',
    contextFamily: 'two-harvest-sources-shared-to-teams',
    visualDescription:
        '앞밭 24개와 뒷밭 12개는 전체를 이루는 두 부분입니다. 합친 씨앗을 여섯 팀에게 같은 수로 줍니다.',
  ),
  'r01-c04-s01': _Problem(
    sourceStageId: 'r01-c01-s06',
    expression: '12-5',
    concept: '전체에서 빠진 부분',
    question: '도구 기록: 전체 12개, 선반에 5개. 나머지는 모두 밭에 있습니다. 밭에 있는 도구는 몇 개일까요?',
    objective: '기록에 표시된 전체와 한 부분으로 다른 부분을 찾아 뺄셈을 전이한다.',
    observation: '도구는 선반과 밭 두 곳에만 있고, 전체와 선반의 수를 알고 있어요.',
    relationship: '전체 12개에서 선반의 5개를 제외하면 밭에 있는 나머지 부분이에요.',
    partialExpression: '전체 12에서 선반의 5를 빼세요. 두 장소의 수를 더한 값은 이미 전체예요.',
    firstWorkedExpression: '5+7 = 12',
    firstWorkedExplanation: '선반 5개와 밭 7개를 합치면 전체 12개가 돼요.',
    explanation: '밭의 수는 12-5=7개입니다. 비교의 차이뿐 아니라 빠진 부분도 뺄셈으로 찾아요.',
    transferQuestion: '전체 의자 15개 중 실내가 8개이고 나머지가 실외라면 실외 수를 나타내는 식은?',
    transferExpression: '15-8',
    relationSchema: 'part-whole-find-missing-part',
    astShape: 'subtract',
    operandBand: 'two-digit-total-single-digit-known-part',
    contextFamily: 'location-inventory',
    unknownPosition: 'missing-part',
    representation: 'inventory-record',
    visualDescription:
        '기록 카드에는 전체 12개와 선반 5개가 표시됩니다. 밭의 항목은 물음표이며, 다른 보관 장소는 없습니다.',
  ),
  'r01-c04-s02': _Problem(
    sourceStageId: 'r01-c01-s07',
    expression: '9+6',
    concept: '이동 거리의 합',
    question: '산책 기록: 집에서 분수까지 9m, 분수에서 화단까지 6m입니다. 이 길로 걸은 전체 거리는 몇 m일까요?',
    objective: '두 이동 구간을 이어 전체 거리를 구하는 덧셈으로 전이한다.',
    observation: '집에서 화단까지 두 구간을 차례로 걸었어요.',
    relationship: '이어진 두 구간의 길이 9m와 6m를 합치면 걸은 전체 거리예요.',
    partialExpression: '첫 구간의 9 뒤에 +를 놓고 다음 구간의 6을 이어 보세요.',
    firstWorkedExpression: '9+1 = 10',
    firstWorkedExplanation: '6m 중 1m를 먼저 더하면 10m가 돼요.',
    explanation: '10m에 나머지 5m를 더하면 전체 15m입니다. 길이를 합치는 식도 9+6입니다.',
    transferQuestion: '출발점에서 다리까지 8m, 다리에서 정자까지 7m인 전체 길이를 나타내는 식은?',
    transferExpression: '8+7',
    relationSchema: 'concatenate-two-measured-segments',
    astShape: 'add',
    operandBand: 'single-digit-inputs-sum-over-ten',
    contextFamily: 'journey-distance',
    representation: 'route-record',
    visualDescription:
        '집, 분수, 화단이 순서대로 연결된 두 구간입니다. 첫 길이는 9m이고 두 번째 길이는 6m이며, 그림의 비율과 무관합니다.',
  ),
  'r01-c04-s03': _Problem(
    sourceStageId: 'r01-c01-s08',
    expression: '15-7',
    concept: '빈자리 찾기',
    question: '화분 배치표: 놓을 수 있는 자리는 15곳, 놓은 화분은 7개입니다. 빈자리는 몇 곳일까요?',
    objective: '전체 용량에서 채운 부분을 빼서 빈 용량을 구한다.',
    observation: '자리는 15곳이고 그중 7곳만 화분으로 채웠어요.',
    relationship: '빈자리는 전체 15곳에서 채운 7곳을 뺀 나머지예요.',
    partialExpression: '15 - 7로 빈 부분을 구하세요. 이미 놓인 화분을 전체 자리에 더하지 않아요.',
    firstWorkedExpression: '15-5 = 10',
    firstWorkedExplanation: '채운 7곳 중 5곳을 먼저 제외하면 10곳이에요.',
    explanation: '10곳에서 나머지 2곳을 제외하면 빈자리는 8곳입니다. 따라서 15-7=8입니다.',
    transferQuestion: '상자에 14칸이 있고 6칸을 채웠다면 빈칸 수를 나타내는 식은?',
    transferExpression: '14-6',
    relationSchema: 'capacity-minus-filled-part',
    astShape: 'subtract',
    operandBand: 'two-digit-minuend-crosses-ten',
    contextFamily: 'capacity-and-occupancy',
    unknownPosition: 'unfilled-capacity',
    representation: 'capacity-record',
    visualDescription:
        '화분 자리 전체 15곳과 이미 채운 자리 7곳이 기록됩니다. 빈자리의 개수를 묻고 실제 배치 그림은 필요하지 않습니다.',
  ),
  'r01-c04-s04': _Problem(
    sourceStageId: 'r01-c01-s09',
    expression: '8+2+5',
    concept: '연속해서 늘어난 재고',
    question: '창고 기록: 처음 물뿌리개 8개, 오전에 2개 받음, 오후에 5개 받음. 지금 모두 몇 개일까요?',
    objective: '처음 수량에 두 번의 증가를 더하여 재고 기록을 식으로 옮긴다.',
    observation: '처음부터 있던 8개에 오전과 오후의 새 물건이 더해져요.',
    relationship: '두 번 모두 받은 사건이므로 처음 수 8에 2와 5를 차례로 더해요.',
    partialExpression: '먼저 8 + 2를 만들고, 두 번째 받은 수 5도 +로 이어 보세요.',
    firstWorkedExpression: '8+2 = 10',
    firstWorkedExplanation: '오전에 받고 나면 창고에는 10개가 있어요.',
    explanation: '오후에 5개를 더 받아 15개가 됩니다. 기록의 세 수량은 8+2+5로 연결됩니다.',
    transferQuestion: '처음 쿠폰 7장에 3장을 받고 다시 4장을 받았다면 가진 수를 나타내는 식은?',
    transferExpression: '7+3+4',
    relationSchema: 'initial-plus-two-inflows',
    astShape: 'add-add',
    contextFamily: 'inventory-change-events',
    representation: 'event-ledger',
    visualDescription: '처음 8개, 오전 받음 2개, 오후 받음 5개라는 재고 기록입니다. 두 사건 모두 증가입니다.',
  ),
  'r01-c04-s05': _Problem(
    sourceStageId: 'r01-c01-s10',
    expression: '20-8+5',
    concept: '사용한 뒤 채운 양',
    question: '물통 기록: 처음 20L, 물 주기에 8L 사용, 다시 5L 채움. 지금 물은 몇 L일까요?',
    objective: '재고 변화의 뺄셈과 덧셈을 물의 부피 기록으로 전이한다.',
    observation: '사용은 줄어드는 사건, 채움은 늘어나는 사건이에요.',
    relationship: '같은 단위 L로 기록한 처음 20에서 사용한 8을 빼고 채운 5를 더해요.',
    partialExpression: '먼저 20 - 8을 만들고, 다시 채운 5를 더하세요.',
    firstWorkedExpression: '20-8 = 12',
    firstWorkedExplanation: '물을 주고 나면 물통에는 12L가 남아요.',
    explanation: '남은 12L에 5L를 채워 지금 물은 17L입니다. 식은 20-8+5입니다.',
    transferQuestion: '물 18L 중 6L를 사용하고 4L를 채우면 남은 양을 나타내는 식은?',
    transferExpression: '18-6+4',
    relationSchema: 'initial-minus-outflow-plus-inflow',
    astShape: 'subtract-add',
    operandBand: 'two-digit-initial-single-digit-changes',
    contextFamily: 'measured-fluid-volume',
    representation: 'volume-ledger',
    visualDescription:
        '물통의 기록은 처음 20L, 사용 8L, 채움 5L입니다. 색이나 물 높이를 읽지 않아도 세 수량을 알 수 있습니다.',
  ),
  'r01-c04-s06': _Problem(
    sourceStageId: 'r01-c02-s01',
    expression: '6×4',
    concept: '같은 길이의 합',
    question: '공사 기록: 산책길 한 구간은 6m이고 같은 구간을 4개 잇습니다. 전체 길이는 몇 m일까요?',
    objective: '같은 묶음의 곱셈을 반복된 측정 길이로 전이한다.',
    observation: '한 구간 6m가 네 번 반복돼요.',
    relationship: '같은 길이 6m를 네 번 더하므로 한 구간 길이에 구간 수를 곱해요.',
    partialExpression: '한 구간 6 뒤에 ×를 놓고 구간 수 4를 이어 보세요.',
    firstWorkedExpression: '6+6+6+6 = 24',
    firstWorkedExplanation: '네 구간의 길이를 각각 더하면 24m예요.',
    explanation: '같은 6m 구간 4개는 6×4로 나타내며 전체 24m입니다.',
    transferQuestion: '5m인 같은 울타리 구간 3개를 잇는 전체 길이를 나타내는 식은?',
    transferExpression: '5×3',
    relationSchema: 'equal-size-groups-total',
    astShape: 'multiply',
    contextFamily: 'repeated-measured-segments',
    representation: 'construction-record',
    visualDescription:
        '길이 6m인 구간 네 개를 겹치지 않고 잇습니다. 간격이나 추가 길이는 없으며, 구간 길이와 구간 수를 문자로 제공합니다.',
  ),
  'r01-c04-s07': _Problem(
    sourceStageId: 'r01-c02-s02',
    expression: '7×3',
    concept: '선택 조합의 수',
    question: '선택표: 씨앗 종류 7가지, 화분 종류 3가지. 씨앗과 화분을 하나씩 고르는 서로 다른 조합은 몇 가지일까요?',
    objective: '배열의 행과 열 관계를 두 선택의 모든 조합으로 전이한다.',
    observation: '씨앗 하나를 정해도 화분 세 가지를 각각 고를 수 있어요.',
    relationship: '씨앗 7가지마다 화분 3가지 선택이 있으므로 7과 3을 곱해요.',
    partialExpression: '씨앗 종류 7과 화분 종류 3을 ×로 연결하세요. 선택의 합 10을 묻는 것이 아니에요.',
    firstWorkedExpression: '3+3+3+3+3+3+3 = 21',
    firstWorkedExplanation: '각 씨앗에 화분 선택 3가지씩 있으므로 일곱 묶음이 생겨요.',
    explanation: '두 선택을 하나씩 짝짓는 모든 조합은 7×3=21가지입니다.',
    transferQuestion: '상의 4가지와 하의 2가지에서 하나씩 고르는 옷 조합을 나타내는 식은?',
    transferExpression: '4×2',
    relationSchema: 'cartesian-product-two-choices',
    astShape: 'multiply',
    contextFamily: 'choice-combinations',
    representation: 'choice-record',
    visualDescription:
        '선택표의 씨앗 항목은 7가지, 화분 항목은 3가지입니다. 각 씨앗과 모든 화분을 한 번씩 짝지으며 그림 없이 문장으로 풀 수 있습니다.',
  ),
  'r01-c04-s08': _Problem(
    sourceStageId: 'r01-c02-s03',
    expression: '20÷5',
    concept: '한 개의 가격',
    question: '영수증: 같은 가격의 꽃 5송이, 합계 20원. 꽃 한 송이의 가격은 몇 원일까요?',
    objective: '전체를 같은 몫으로 나누는 관계를 한 개의 가격으로 전이한다.',
    observation: '전체 가격 20원과 같은 가격의 꽃 5송이를 알고 있어요.',
    relationship: '한 송이씩 같은 가격을 나누어 맡으므로 전체 20원을 5몫으로 나눠요.',
    partialExpression: '합계 20 뒤에 ÷를 놓고 꽃 수 5를 이어 보세요.',
    firstWorkedExpression: '4×5 = 20',
    firstWorkedExplanation: '한 송이 4원이면 다섯 송이 가격이 20원이 돼요.',
    explanation: '20원을 같은 5몫으로 나누어 20÷5=4이므로 한 송이는 4원입니다.',
    transferQuestion: '같은 공책 3권의 합계가 18원이라면 한 권 가격을 나타내는 식은?',
    transferExpression: '18÷3',
    relationSchema: 'equal-share-unit-price',
    astShape: 'divide',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'unit-price',
    unknownPosition: 'unit-rate',
    representation: 'receipt-record',
    visualDescription:
        '영수증에는 꽃 수량 5송이와 합계 가격 20원이 표시되고 각 꽃의 가격은 같습니다. 실제 돈 그림은 필요하지 않습니다.',
  ),
  'r01-c04-s09': _Problem(
    sourceStageId: 'r01-c02-s04',
    expression: '24÷4',
    concept: '같은 길이 조각의 수',
    question: '작업 기록: 끈 전체 24m를 4m씩 같은 길이로 자릅니다. 끈 조각은 몇 개가 될까요?',
    objective: '묶음 수를 찾는 나눗셈을 측정 길이의 분할로 전이한다.',
    observation: '24m는 전체 길이이고 4m는 조각 하나의 길이예요.',
    relationship: '전체 24m 안에 4m가 몇 번 들어가는지 구하므로 24를 4로 나눠요.',
    partialExpression: '전체 24 ÷ 한 조각 4를 만드세요. 자르는 횟수가 아니라 조각 수를 물어요.',
    firstWorkedExpression: '4×6 = 24',
    firstWorkedExplanation: '4m 조각 여섯 개를 이으면 전체 24m가 돼요.',
    explanation: '24÷4=6이므로 끈 조각은 6개입니다. 조각 수와 가위질 횟수는 구분해요.',
    transferQuestion: '길이 30m인 리본을 5m씩 자르면 조각 수를 나타내는 식은?',
    transferExpression: '30÷5',
    relationSchema: 'equal-group-find-group-count',
    astShape: 'divide',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'measurement-segmentation',
    unknownPosition: 'group-count',
    representation: 'measurement-record',
    visualDescription:
        '전체 끈 길이는 24m이며 남는 부분 없이 4m씩 나눕니다. 조각의 개수를 묻고 자르는 횟수는 묻지 않습니다.',
  ),
  'r01-c04-s10': _Problem(
    sourceStageId: 'r01-c02-s05',
    expression: '5×2+3',
    concept: '반복된 증가와 처음 수',
    question:
        '정원 일지: 처음 꽃 3송이가 피었고, 이후 이틀 동안 매일 5송이씩 더 피었습니다. 지금 꽃은 모두 몇 송이일까요?',
    objective: '묶음과 낱개의 곱셈·덧셈을 반복된 시간 변화와 초기 수량으로 전이한다.',
    observation: '매일 5송이는 이틀 동안 반복되고, 처음 3송이는 그 기간 밖의 수량이에요.',
    relationship: '이틀 동안 새로 핀 수는 5를 두 번 곱셈으로 나타내고, 처음 3송이를 따로 더해요.',
    partialExpression: '새로 핀 5 × 2를 먼저 만들고, 처음부터 있던 3을 +로 이어 보세요.',
    firstWorkedExpression: '5×2 = 10',
    firstWorkedExplanation: '이틀 동안 매일 5송이씩 더 피어 새 꽃은 10송이예요.',
    explanation: '새 꽃 10송이에 처음 3송이를 더하면 13송이입니다. 반복된 증가와 처음 수를 5×2+3으로 나타내요.',
    transferQuestion: '처음 나무 4그루에 사흘 동안 하루 2그루씩 심으면 전체를 나타내는 식은?',
    transferExpression: '2×3+4',
    relationSchema: 'repeated-inflow-plus-initial-amount',
    astShape: 'multiply-add',
    contextFamily: 'temporal-growth-record',
    representation: 'garden-journal',
    visualDescription:
        '일지에는 처음 3송이, 첫날 새로 5송이, 둘째 날 새로 5송이가 기록됩니다. 날짜별 그림을 보지 못해도 수량과 반복 횟수를 읽을 수 있습니다.',
  ),
  'r01-c05-s01': _Problem(
    sourceStageId: 'r01-c02-s06',
    expression: '6×3-4',
    concept: '모은 양에서 사용한 양',
    question: '물 기록: 하루 6L씩 사흘 모은 뒤 4L를 썼습니다. 남은 물은 몇 L일까요?',
    objective: '반복된 측정량의 전체에서 한 번의 사용량을 빼는 관계로 전이한다.',
    observation: '6L는 하루의 양, 3은 날짜 수, 4L는 마지막에 쓴 양이에요.',
    relationship: '하루 6L를 사흘 모아 곱셈으로 전체를 구하고, 사용한 4L를 한 번 빼요.',
    partialExpression: '모은 물 6 × 3 뒤에 사용량 - 4를 이어 보세요.',
    firstWorkedExpression: '6×3 = 18',
    firstWorkedExplanation: '사흘 동안 모은 물은 18L예요.',
    explanation: '모은 18L에서 쓴 4L를 빼면 14L입니다. 두 겹 봉인은 보드 규칙이며 물의 식은 바꾸지 않아요.',
    transferQuestion: '하루 5m씩 나흘 만든 길에서 2m를 없애면 남은 길이를 나타내는 식은?',
    transferExpression: '5×4-2',
    relationSchema: 'accumulated-measure-minus-later-use',
    astShape: 'multiply-subtract',
    contextFamily: 'measured-water-collection',
    representation: 'volume-event-ledger',
    visualDescription:
        '처음 물은 없고 하루마다 6L씩 사흘 모은 기록 뒤에 4L 사용 기록이 있습니다. 단위는 모두 L입니다.',
  ),
  'r01-c05-s02': _Problem(
    sourceStageId: 'r01-c02-s07',
    expression: '20÷4+3',
    concept: '하루 몫과 추가 물',
    question: '물 계획: 20L를 나흘간 똑같이 씁니다. 오늘만 3L를 더 쓰면 오늘 사용량은 몇 L일까요?',
    objective: '공평한 한 몫과 추가량을 시간별 측정량으로 전이한다.',
    observation: '20L는 나흘의 계획량이고, 3L는 오늘만 추가한 양이에요.',
    relationship: '보통 하루 양은 20÷4이고, 오늘은 그 하루 양에만 3L를 더해요.',
    partialExpression: '20 ÷ 4로 하루 양을 찾고 + 3을 이어 보세요.',
    firstWorkedExpression: '20÷4 = 5',
    firstWorkedExplanation: '보통 하루에 사용할 물은 5L예요.',
    explanation: '오늘은 5L와 추가 3L를 합해 8L입니다. 사람의 몫처럼 날짜별 몫도 먼저 나눠 구해요.',
    transferQuestion: '물 18L를 사흘 나눠 쓰고 하루만 4L 더 쓰는 그날 양을 나타내는 식은?',
    transferExpression: '18÷3+4',
    relationSchema: 'daily-unit-allocation-plus-one-day-extra',
    astShape: 'divide-add',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'daily-irrigation-volume',
    unknownPosition: 'one-day-total-measure',
    representation: 'daily-use-plan',
    visualDescription:
        '20L가 네 날짜에 같은 양으로 배분됩니다. 오늘 항목에만 3L가 추가되며 나흘 전체 추가량이 아닙니다.',
  ),
  'r01-c05-s03': _Problem(
    sourceStageId: 'r01-c02-s08',
    expression: '30÷5×2',
    concept: '나눈 길이 두 조각',
    question: '작업표: 끈 30m를 5조각으로 똑같이 자릅니다. 두 조각의 전체 길이는 몇 m일까요?',
    objective: '한 몫을 필요한 묶음 수만큼 모으는 관계를 길이 분할에 적용한다.',
    observation: '30m는 전체 길이이고, 5는 조각 수, 2는 사용할 조각 수예요.',
    relationship: '한 조각 길이는 30÷5이며, 같은 두 조각을 모으므로 그 몫에 2를 곱해요.',
    partialExpression: '30 ÷ 5 뒤에 × 2를 놓아 한 조각이 아닌 두 조각을 구하세요.',
    firstWorkedExpression: '30÷5 = 6',
    firstWorkedExplanation: '다섯 같은 조각으로 나누면 한 조각은 6m예요.',
    explanation: '두 조각은 6m가 두 번 있어 전체 12m입니다. 식은 30÷5×2입니다.',
    transferQuestion: '리본 24m를 6조각으로 나눈 뒤 두 조각의 길이를 나타내는 식은?',
    transferExpression: '24÷6×2',
    relationSchema: 'measure-per-part-times-selected-part-count',
    astShape: 'divide-multiply',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'cut-length-and-selected-pieces',
    unknownPosition: 'selected-parts-measure',
    representation: 'cutting-work-order',
    visualDescription:
        '끈 30m를 남김없이 같은 길이의 다섯 조각으로 자르고 그중 두 조각을 고릅니다. 자른 횟수를 묻지 않습니다.',
  ),
  'r01-c05-s04': _Problem(
    sourceStageId: 'r01-c02-s09',
    expression: '4×6-7',
    concept: '계획 길이에서 완성분 빼기',
    question: '공사표: 길이 4m인 구간 6개를 만들고, 그중 7m는 완성했습니다. 더 만들 길이는 몇 m일까요?',
    objective: '반복된 전체에서 알려진 부분을 빼는 관계를 공사 길이로 전이한다.',
    observation: '4m씩 여섯 구간은 전체 계획이고, 7m는 이미 완성한 부분이에요.',
    relationship: '전체 계획은 4×6이고, 더 할 부분은 전체에서 완성한 7m를 빼요.',
    partialExpression: '전체 4 × 6 뒤에 완성한 부분 - 7을 이어 보세요.',
    firstWorkedExpression: '4×6 = 24',
    firstWorkedExplanation: '여섯 구간의 전체 계획 길이는 24m예요.',
    explanation: '전체 24m에서 완성한 7m를 제외하면 17m를 더 만들어야 합니다. 꽃의 감소처럼 뺄셈을 사용해요.',
    transferQuestion: '3m씩 일곱 구간 중 5m를 완성했다면 남은 길이를 나타내는 식은?',
    transferExpression: '3×7-5',
    relationSchema: 'repeated-total-minus-completed-part',
    astShape: 'multiply-subtract',
    contextFamily: 'construction-progress-length',
    unknownPosition: 'unfinished-measure',
    representation: 'construction-progress-table',
    visualDescription:
        '전체 계획은 4m인 구간 여섯 개입니다. 길이 단위가 같은 완성 부분 7m를 제외하고 미완성 길이를 구합니다.',
  ),
  'r01-c05-s05': _Problem(
    sourceStageId: 'r01-c02-s10',
    expression: '3×5+2',
    concept: '같은 구간과 연결 길',
    question: '길 안내표: 3m인 구간 5개 뒤에 연결 길 2m가 있습니다. 전체 길이는 몇 m일까요?',
    objective: '묶음과 낱개의 합을 같은 길이 구간과 별도 연결 길로 전이한다.',
    observation: '3m 구간은 다섯 번 반복되지만, 연결 길 2m는 마지막에 한 번 있어요.',
    relationship: '같은 다섯 구간의 길이 3×5에 별도 연결 길 2를 더해요.',
    partialExpression: '3 × 5로 같은 구간 전체를 만들고 + 2를 이어 보세요.',
    firstWorkedExpression: '3×5 = 15',
    firstWorkedExplanation: '반복된 구간 다섯 개의 길이는 15m예요.',
    explanation: '15m에 연결 길 2m를 더하면 17m입니다. 연결 길을 다섯 번 더하지 않아요.',
    transferQuestion: '6m 구간 세 개와 따로 있는 4m 길을 잇는 전체를 나타내는 식은?',
    transferExpression: '6×3+4',
    relationSchema: 'repeated-segment-plus-one-connector',
    astShape: 'multiply-add',
    contextFamily: 'route-length-with-connector',
    representation: 'route-length-guide',
    visualDescription:
        '3m 구간 다섯 개와 별도 연결 길 2m가 이어집니다. 구간이 서로 겹치거나 간격을 두지는 않습니다.',
  ),
  'r01-c05-s06': _Problem(
    sourceStageId: 'r01-c03-s01',
    expression: '4+2×3',
    concept: '처음 양과 반복 증가',
    question: '물통 일지: 처음 4L, 이후 2L씩 세 번 채움. 지금 물은 몇 L일까요?',
    objective: '낱개와 묶음의 연산 순서를 초기 측정량과 반복 유입으로 전이한다.',
    observation: '처음 4L는 한 번 있고, 2L 채움만 세 번 반복돼요.',
    relationship: '추가한 물은 2×3이므로 먼저 곱하고, 처음 4L를 더해요.',
    partialExpression: '처음 양 4 + 추가량 2 × 3을 만들고 곱셈부터 계산하세요.',
    firstWorkedExpression: '2×3 = 6',
    firstWorkedExplanation: '세 번 채운 물의 합은 6L예요.',
    explanation:
        '처음 4L와 새로 채운 6L를 합하면 10L입니다. 직선 파워는 보드에서만 작동하고 식의 연산 순서는 같아요.',
    transferQuestion: '처음 포인트 2점에 한 번 3점씩 네 번 얻는 총점을 나타내는 식은?',
    transferExpression: '2+3×4',
    relationSchema: 'initial-measure-plus-repeated-inflow',
    astShape: 'add-multiply',
    contextFamily: 'initial-volume-and-refill-events',
    representation: 'refill-event-journal',
    visualDescription: '일지에는 처음 물 4L와 세 번의 2L 채움이 기록됩니다. 처음 물을 세 번 세지 않습니다.',
  ),
  'r01-c05-s07': _Problem(
    sourceStageId: 'r01-c03-s02',
    expression: '(3+4)×2',
    concept: '한 바퀴의 합을 반복',
    question: '산책표: 가는 길 3m, 돌아오는 길 4m입니다. 두 바퀴 걸은 거리는 몇 m일까요?',
    objective: '한 묶음 안의 합과 반복을 한 바퀴의 길이와 바퀴 수로 전이한다.',
    observation: '한 바퀴에는 가는 길과 돌아오는 길이 둘 다 있어요.',
    relationship: '한 바퀴 거리 3+4를 먼저 합친 뒤, 같은 두 바퀴를 곱해요.',
    partialExpression: '한 바퀴 (3 + 4) 뒤에 × 2를 이어 보세요.',
    firstWorkedExpression: '3+4 = 7',
    firstWorkedExplanation: '가는 길과 돌아오는 길을 합친 한 바퀴는 7m예요.',
    explanation: '한 바퀴 7m를 두 번 걸어 14m입니다. 괄호 안의 두 길이 모두 두 번 반복돼요.',
    transferQuestion: '가는 길 2m, 오는 길 3m인 길을 네 바퀴 걷는 식은?',
    transferExpression: '(2+3)×4',
    relationSchema: 'round-trip-segment-sum-times-laps',
    astShape: 'multiply-parenthesized-add',
    contextFamily: 'repeated-round-trip-distance',
    representation: 'walk-route-record',
    visualDescription: '한 바퀴는 가는 길 3m와 다른 돌아오는 길 4m로 이루어집니다. 이 경로를 두 번 걷습니다.',
  ),
  'r01-c05-s08': _Problem(
    sourceStageId: 'r01-c03-s03',
    expression: '25-3×4',
    concept: '여러 장의 가격 빼기',
    question: '영수증: 가진 돈 25원, 한 장 3원인 표 4장 구매. 남은 돈은 몇 원일까요?',
    objective: '묶음의 전체를 뺀 연산 순서를 단가와 구매 수량에 적용한다.',
    observation: '3원은 표 한 장의 가격이고, 4는 산 표의 수예요.',
    relationship: '산 표의 합계 가격은 3×4이므로 먼저 곱하고, 가진 돈 25에서 빼요.',
    partialExpression: '25 - 3 × 4를 만들고 합계 가격 3×4부터 계산하세요.',
    firstWorkedExpression: '3×4 = 12',
    firstWorkedExplanation: '3원인 표 네 장의 합계는 12원이에요.',
    explanation: '25원에서 표 가격 12원을 빼면 남은 돈은 13원입니다. 가진 돈까지 네 배 하지 않아요.',
    transferQuestion: '18원에서 한 개 2원인 물건 다섯 개를 산 뒤 남은 돈을 나타내는 식은?',
    transferExpression: '18-2×5',
    relationSchema: 'budget-minus-unit-price-times-quantity',
    astShape: 'subtract-multiply',
    operandBand: 'two-digit-initial-single-digit-factors',
    contextFamily: 'purchase-budget',
    unknownPosition: 'remaining-budget',
    representation: 'purchase-receipt',
    visualDescription:
        '구매 전 돈 25원, 표 한 장 가격 3원, 구매 수량 네 장입니다. 할인이나 추가 비용은 없습니다.',
  ),
  'r01-c05-s09': _Problem(
    sourceStageId: 'r01-c03-s04',
    expression: '36÷6+2',
    concept: '나눈 점수와 보너스',
    question: '점수표: 36점을 6명에게 똑같이 나누고 한 명에게 2점을 더 줍니다. 그 사람은 몇 점일까요?',
    objective: '한 몫의 나눗셈과 추가량을 점수 배분 기록에 적용한다.',
    observation: '전체 36점은 여섯 명의 몫이고, 추가 2점은 한 명의 보너스예요.',
    relationship: '기본 점수는 36÷6으로 구하고, 그 사람의 기본 점수에만 2를 더해요.',
    partialExpression: '36 ÷ 6 + 2를 만들고 기본 점수부터 나누세요.',
    firstWorkedExpression: '36÷6 = 6',
    firstWorkedExplanation: '여섯 명이 같은 몫을 받으면 기본 점수는 6점이에요.',
    explanation: '기본 6점에 보너스 2점을 더하면 8점입니다. 사람 수와 보너스를 먼저 합하지 않아요.',
    transferQuestion: '점수 24점을 세 명에게 나누고 한 명에게 6점을 더 줄 때 그 사람의 식은?',
    transferExpression: '24÷3+6',
    relationSchema: 'equal-point-allocation-plus-individual-bonus',
    astShape: 'divide-add',
    operandBand: 'two-digit-total-single-digit-divisor',
    contextFamily: 'score-allocation',
    unknownPosition: 'one-recipient-score',
    representation: 'score-allocation-table',
    visualDescription:
        '점수표에는 전체 36점, 인원 여섯 명, 한 사람 보너스 2점이 기록됩니다. 보너스도 다른 사람과 나누지 않습니다.',
  ),
  'r01-c05-s10': _Problem(
    sourceStageId: 'r01-c03-s05',
    expression: '(15-6)×2',
    concept: '하루의 사용 시간 반복',
    question: '작동표: 펌프를 하루 15시간 중 6시간 멈춥니다. 같은 계획으로 이틀 작동한 시간은 모두 몇 시간일까요?',
    objective: '한 묶음의 차이와 반복을 하루 작동 시간과 날짜 수로 전이한다.',
    observation: '15시간과 멈춘 6시간은 하루 안의 시간이고, 그 하루가 두 번 반복돼요.',
    relationship: '하루 작동 시간 15-6을 먼저 구한 뒤 이틀의 시간을 곱해요.',
    partialExpression: '하루 작동 (15 - 6) 뒤에 × 2를 이어 보세요.',
    firstWorkedExpression: '15-6 = 9',
    firstWorkedExplanation: '하루에 펌프가 실제로 작동하는 시간은 9시간이에요.',
    explanation: '하루 9시간씩 이틀이면 18시간입니다. 멈춘 시간도 하루마다 있으므로 괄호로 묶어요.',
    transferQuestion: '펌프가 하루 12시간 중 4시간 멈출 때 사흘의 작동 시간을 나타내는 식은?',
    transferExpression: '(12-4)×3',
    relationSchema: 'daily-available-time-minus-stops-times-days',
    astShape: 'multiply-parenthesized-subtract',
    operandBand: 'two-digit-daily-time-single-digit-stop',
    contextFamily: 'daily-device-operating-duration',
    unknownPosition: 'multi-day-operating-duration',
    representation: 'device-operating-schedule',
    visualDescription:
        '각 날짜마다 펌프 계획 시간 15시간에서 멈춘 6시간을 제외합니다. 동일한 이틀의 실제 작동 시간만 구합니다.',
  ),
  'r01-c06-s01': _Problem(
    sourceStageId: 'r01-c01-s01',
    expression: '4+3',
    concept: '이어진 길의 전체',
    question: '길 기록: 문에서 연못까지 4m, 연못에서 정자까지 3m입니다. 이 길의 전체 거리는 몇 m일까요?',
    objective: '두 모둠을 합치는 덧셈을 연속된 길이의 합으로 전이한다.',
    observation: '정자까지 두 구간을 차례로 걷고, 각 구간은 4m와 3m예요.',
    relationship: '한 길로 이어진 두 구간을 모두 걸으므로 두 길이를 더해요.',
    partialExpression: '첫 구간 4 뒤에 +를 놓고 다음 구간 3을 이어 보세요.',
    firstWorkedExpression: '4 = 4',
    firstWorkedExplanation: '문에서 연못까지 걸은 첫 구간 4m에서 시작해요.',
    explanation:
        '첫 길 4m와 다음 길 3m를 합하면 전체 7m입니다. 물건 수뿐 아니라 같은 단위의 길이도 더할 수 있어요.',
    transferQuestion: '집에서 다리까지 3m, 다리에서 밭까지 2m인 전체 길이를 나타내는 식은?',
    transferExpression: '3+2',
    relationSchema: 'sum-of-connected-lengths',
    astShape: 'add',
    contextFamily: 'connected-path-measures',
    representation: 'route-distance-ledger',
    visualDescription:
        '문, 연못, 정자가 차례로 연결되어 있고 앞 구간 4m와 다음 구간 3m를 모두 걷습니다. 그림의 비율은 단서가 아닙니다.',
  ),
  'r01-c06-s02': _Problem(
    sourceStageId: 'r01-c01-s02',
    expression: '9-2',
    concept: '채우지 않은 용량',
    question: '물통 표: 전체 용량 9L, 담긴 물 2L. 더 담을 수 있는 물은 몇 L일까요?',
    objective: '남은 수의 뺄셈을 전체 용량에서 채운 양을 제외한 빈 용량으로 전이한다.',
    observation: '9L는 물통의 전체 용량, 2L는 이미 채운 양이에요.',
    relationship: '더 담을 빈 용량은 전체 9L에서 이미 담긴 2L를 뺀 수예요.',
    partialExpression: '전체 용량 9에서 채운 양 2를 -로 빼세요.',
    firstWorkedExpression: '2+7 = 9',
    firstWorkedExplanation: '채운 2L에 빈 용량 7L를 더하면 전체 9L가 돼요.',
    explanation: '9-2=7이므로 물 7L를 더 담을 수 있습니다. 꺼낸 물이 없어도 빈 부분을 뺄셈으로 찾을 수 있어요.',
    transferQuestion: '용량 7L인 물통에 3L가 있다면 빈 용량을 나타내는 식은?',
    transferExpression: '7-3',
    relationSchema: 'total-capacity-minus-filled-measure',
    astShape: 'subtract',
    contextFamily: 'unfilled-fluid-capacity',
    unknownPosition: 'unfilled-capacity',
    representation: 'container-capacity-label',
    visualDescription:
        '물통 전체 용량 9L와 현재 물 2L가 문자로 표시됩니다. 물의 색이나 높이를 판단할 필요가 없습니다.',
  ),
  'r01-c06-s03': _Problem(
    sourceStageId: 'r01-c01-s03',
    expression: '6+5',
    concept: '두 번 받은 수',
    question: '배달 일지: 빈 창고에 오전 씨앗 6개, 오후 씨앗 5개를 받았습니다. 지금 모두 몇 개일까요?',
    objective: '서로 다른 두 모둠의 합을 서로 다른 시점의 두 증가 기록에 적용한다.',
    observation: '처음은 빈 창고이고, 오전과 오후 두 번 모두 씨앗을 받았어요.',
    relationship: '두 사건 모두 증가이므로 받은 6개와 5개를 더해요.',
    partialExpression: '오전에 받은 6과 오후에 받은 5를 +로 연결하세요.',
    firstWorkedExpression: '6 = 6',
    firstWorkedExplanation: '오전 배달 직후에는 씨앗 6개가 있어요.',
    explanation: '오후의 5개까지 합하면 11개입니다. 두 수량이 같은 시간에 있지 않아도 증가 기록을 더할 수 있어요.',
    transferQuestion: '처음 빈 상자에 오전 4개, 오후 5개를 받는 전체를 나타내는 식은?',
    transferExpression: '4+5',
    relationSchema: 'sum-of-two-inflow-events',
    astShape: 'add',
    contextFamily: 'two-event-inventory-growth',
    representation: 'delivery-event-journal',
    visualDescription:
        '처음 수량 0, 오전 받음 6개, 오후 받음 5개라는 기록입니다. 사용하거나 내보낸 물건은 없습니다.',
  ),
  'r01-c06-s04': _Problem(
    sourceStageId: 'r01-c01-s04',
    expression: '10-4',
    concept: '비어 있는 자리',
    question: '자리표: 의자 10개 중 4개에 사람이 앉았습니다. 빈 의자는 몇 개일까요?',
    objective: '옮긴 뒤 남은 수의 뺄셈을 전체에서 차지한 부분을 제외하는 관계로 전이한다.',
    observation: '전체 의자는 10개이고, 4개만 사람이 앉아 있어요.',
    relationship: '빈 의자는 전체 10개에서 차지한 4개를 뺀 다른 부분이에요.',
    partialExpression: '전체 10 뒤에 -를 놓고 차지한 의자 4를 이어 보세요.',
    firstWorkedExpression: '4+6 = 10',
    firstWorkedExplanation: '앉은 의자 4개와 빈 의자 6개를 합하면 전체 10개예요.',
    explanation: '10-4=6이므로 빈 의자는 6개입니다. 실제로 의자를 꺼내지 않아도 남은 부분을 빼서 찾아요.',
    transferQuestion: '서가 9칸 중 4칸을 채웠을 때 빈칸 수를 나타내는 식은?',
    transferExpression: '9-4',
    relationSchema: 'total-seating-minus-occupied-seats',
    astShape: 'subtract',
    contextFamily: 'seating-occupancy',
    unknownPosition: 'unoccupied-part',
    representation: 'seat-occupancy-table',
    visualDescription:
        '전체 의자 10개와 사람이 앉은 의자 4개가 표시됩니다. 빈 의자를 묻고 사람의 이동 횟수는 묻지 않습니다.',
  ),
  'r01-c06-s05': _Problem(
    sourceStageId: 'r01-c01-s05',
    expression: '7+2',
    concept: '기준보다 긴 길이',
    question: '길이표: 짧은 끈 7m, 긴 끈은 그보다 2m 더 깁니다. 긴 끈은 몇 m일까요?',
    objective: '더 많은 수를 찾는 덧셈을 기준 길이와 길이 차이로 전이한다.',
    observation: '7m는 짧은 끈의 길이이고, 2m는 두 끈의 길이 차이예요.',
    relationship: '긴 끈은 기준인 짧은 끈 7m에 차이 2m를 더한 길이예요.',
    partialExpression: '기준 길이 7 뒤에 +로 더 긴 차이 2를 연결하세요.',
    firstWorkedExpression: '7 = 7',
    firstWorkedExplanation: '비교의 기준인 짧은 끈의 7m에서 시작해요.',
    explanation: '7m보다 2m 길면 긴 끈은 9m입니다. 2m는 긴 끈의 전체 길이가 아니라 차이입니다.',
    transferQuestion: '작은 나무 높이 6m보다 큰 나무가 3m 높을 때 큰 나무의 식은?',
    transferExpression: '6+3',
    relationSchema: 'compare-longer-than-reference-length',
    astShape: 'add',
    contextFamily: 'length-comparison',
    unknownPosition: 'longer-compared-measure',
    representation: 'length-comparison-record',
    visualDescription:
        '짧은 끈 7m를 기준으로 긴 끈은 2m 더 깁니다. 두 끈의 총길이가 아니라 긴 끈 한 개의 길이를 구합니다.',
  ),
  'r01-c06-s06': _Problem(
    sourceStageId: 'r01-c03-s06',
    expression: '42÷(4+3)',
    concept: '모든 줄에 똑같이 놓기',
    question: '배치표: 화분 42개를 앞쪽 4줄, 뒤쪽 3줄에 같은 수로 놓습니다. 한 줄은 몇 개일까요?',
    objective: '나눌 곳의 합을 사람 모둠에서 공간의 줄 수로 전이한다.',
    observation: '화분은 앞뒤 모든 줄에 나누며, 전체 줄 수는 아직 합하지 않았어요.',
    relationship: '앞 4줄과 뒤 3줄을 합한 줄 수로 화분 전체 42개를 나눠요.',
    partialExpression: '전체 42 뒤에 ÷ (4 + 3)을 놓아 전체 줄 수로 나누세요.',
    firstWorkedExpression: '4+3 = 7',
    firstWorkedExplanation: '앞쪽과 뒤쪽을 합하면 배치할 줄은 일곱 줄이에요.',
    explanation: '42개를 일곱 줄에 나누면 한 줄은 6개입니다. 앞뒤 줄을 합한 괄호 전체가 나누는 수예요.',
    transferQuestion: '식물 36개를 앞 3줄과 뒤 3줄에 같은 수로 놓는 한 줄의 식은?',
    transferExpression: '36÷(3+3)',
    relationSchema: 'equal-array-by-combined-row-sections',
    astShape: 'divide-parenthesized-add',
    operandBand: 'two-digit-total-composite-divisor',
    contextFamily: 'front-and-back-row-allocation',
    unknownPosition: 'plants-per-row',
    representation: 'spatial-placement-plan',
    visualDescription:
        '전체 화분 42개를 앞쪽 네 줄과 뒤쪽 세 줄에 모두 같은 수로 배치합니다. 한 줄의 수를 묻습니다.',
  ),
  'r01-c06-s07': _Problem(
    sourceStageId: 'r01-c03-s07',
    expression: '8×8',
    concept: '정사각 배열의 같은 두 수',
    question: '배치표: 한 줄에 돌 8개씩인 줄이 8줄입니다. 돌은 모두 몇 개일까요?',
    objective: '값이 같은 두 수량을 공간 배열의 한 줄 수와 줄 수로 구분한다.',
    observation: '한 줄의 돌 수 8과 줄 수 8은 값만 같고 역할은 달라요.',
    relationship: '한 줄의 8개가 여덟 줄에 반복되므로 두 8을 각각 사용해 곱해요.',
    partialExpression: '한 줄의 8과 줄 수 8을 별개의 조각으로 놓고 ×로 연결하세요.',
    firstWorkedExpression: '8+8+8+8+8+8+8+8 = 64',
    firstWorkedExplanation: '여덟 줄의 돌을 모두 더하면 64개예요.',
    explanation: '8×8=64개입니다. 꽃잎과 꽃 수를 구분했던 것처럼 한 줄 수와 줄 수를 구분해요.',
    transferQuestion: '꽃을 한 줄 6송이씩 여섯 줄에 심는 전체 수의 식은?',
    transferExpression: '6×6',
    relationSchema: 'equal-valued-row-size-and-row-count',
    astShape: 'multiply',
    contextFamily: 'square-spatial-array',
    representation: 'square-placement-plan',
    visualDescription:
        '배치표의 한 줄에는 돌 8개, 줄은 여덟 줄입니다. 간격이나 배열의 면적이 아닌 돌의 개수를 묻습니다.',
  ),
  'r01-c06-s08': _Problem(
    sourceStageId: 'r01-c03-s08',
    expression: '50-24÷4',
    concept: '하루 비용을 먼저 빼기',
    question: '예산표: 가진 돈 50원, 나흘 비용 합계 24원입니다. 매일 같게 쓰면 첫날 뒤 몇 원이 남을까요?',
    objective: '나눈 한 몫을 빼는 순서를 여러 날의 합계 비용과 하루 예산으로 전이한다.',
    observation: '24원은 나흘 전체 비용이지 첫날에 모두 쓰는 돈은 아니에요.',
    relationship: '첫날 비용은 24÷4이므로 먼저 나눈 뒤, 가진 50원에서 하루 비용만 빼요.',
    partialExpression: '50 - 24 ÷ 4를 만들고 하루 비용 24÷4부터 계산하세요.',
    firstWorkedExpression: '24÷4 = 6',
    firstWorkedExplanation: '매일 같은 돈을 쓰면 하루 비용은 6원이에요.',
    explanation: '첫날 6원을 써서 50-6=44원이 남습니다. 전체 기간의 비용과 하루 비용을 구분하는 것이 중요해요.',
    transferQuestion: '40원에서 사흘 합계 비용 18원을 같은 양씩 쓸 때 첫날 뒤의 식은?',
    transferExpression: '40-18÷3',
    relationSchema: 'initial-budget-minus-derived-daily-cost',
    astShape: 'subtract-divide',
    operandBand: 'two-digit-initial-two-digit-shared-total',
    contextFamily: 'multi-day-expense-budget',
    unknownPosition: 'budget-after-one-day',
    representation: 'daily-expense-budget',
    visualDescription:
        '예산표에는 처음 50원과 나흘 총비용 24원이 표시됩니다. 매일 비용은 같고 다른 수입이나 지출은 없습니다.',
  ),
  'r01-c06-s09': _Problem(
    sourceStageId: 'r01-c03-s09',
    expression: '4×(9-3)',
    concept: '각 구간의 열린 부분 빼기',
    question: '울타리 도면: 9m인 구간 4곳에서 각각 3m씩 비워 둡니다. 울타리는 모두 몇 m일까요?',
    objective: '반복 묶음 안의 차이를 공간 수량에서 구간별 설치 길이로 전이한다.',
    observation: '네 구간 모두 전체 9m 중 3m를 빈 통로로 남겨요.',
    relationship: '한 구간의 설치 길이는 9-3이고, 같은 네 구간의 길이를 곱해요.',
    partialExpression: '구간 수 4 × (9 - 3)을 만들고 괄호 안부터 계산하세요.',
    firstWorkedExpression: '9-3 = 6',
    firstWorkedExplanation: '한 구간에는 울타리를 6m 설치해요.',
    explanation: '네 구간에 6m씩 설치해 24m입니다. 빈 길 3m는 전체에 한 번이 아니라 구간마다 제외해요.',
    transferQuestion: '8m인 구간 세 곳에서 각각 2m를 비우는 전체 설치 길이를 나타내는 식은?',
    transferExpression: '3×(8-2)',
    relationSchema: 'section-count-times-length-minus-opening',
    astShape: 'multiply-parenthesized-subtract',
    contextFamily: 'fence-installation-with-per-section-opening',
    unknownPosition: 'total-installed-length',
    representation: 'fence-construction-drawing',
    visualDescription:
        '같은 길이 9m인 구간 네 곳에서 매 구간 3m는 비웁니다. 울타리 두께나 모서리 겹침은 계산하지 않습니다.',
  ),
  'r01-c06-s10': _Problem(
    sourceStageId: 'r01-c03-s10',
    expression: '(30+18)÷6',
    concept: '두 길이 합쳐 같은 조각으로',
    question: '작업표: 끈 30m와 18m를 이어 6조각으로 똑같이 나눕니다. 한 조각의 길이는 몇 m일까요?',
    objective: '합친 전체를 같은 몫으로 나누는 관계를 두 측정 길이의 결합과 분할로 전이한다.',
    observation: '끈 두 개를 먼저 잇고, 그 전체 길이를 여섯 조각에 똑같이 나눠요.',
    relationship: '나눌 전체 길이는 30+18이고, 그 합을 조각 수 6으로 나눠요.',
    partialExpression: '전체 (30 + 18) 뒤에 ÷ 6을 이어 보세요.',
    firstWorkedExpression: '30+18 = 48',
    firstWorkedExplanation: '이어 붙인 두 끈의 전체 길이는 48m예요.',
    explanation:
        '48m를 같은 여섯 조각으로 나누면 한 조각은 8m입니다. 정원 전체를 완성해도 식에서는 합친 전체를 먼저 구해요.',
    transferQuestion: '끈 24m와 12m를 합쳐 여섯 같은 조각으로 나누는 한 조각의 식은?',
    transferExpression: '(24+12)÷6',
    relationSchema: 'combine-lengths-then-divide-into-equal-parts',
    astShape: 'divide-parenthesized-add',
    operandBand: 'two-digit-parts-single-digit-divisor',
    contextFamily: 'joined-length-and-equal-cutting',
    unknownPosition: 'length-per-piece',
    representation: 'joined-length-work-order',
    visualDescription:
        '끈 30m와 18m를 길이 손실 없이 이어 모두 48m로 만들고 같은 길이 여섯 조각으로 나눕니다.',
  ),
};
