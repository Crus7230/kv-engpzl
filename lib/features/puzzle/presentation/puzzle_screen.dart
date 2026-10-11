import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/equation_token.dart';
import 'puzzle_controller.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({required this.controller, super.key});

  final PuzzleController controller;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  PuzzleController get controller => widget.controller;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.canvasTop, AppColors.canvasBottom],
              ),
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: -90,
                  right: -50,
                  child: _DecorativeOrb(size: 260, color: Color(0x1F6547D9)),
                ),
                const Positioned(
                  bottom: -110,
                  left: -80,
                  child: _DecorativeOrb(size: 300, color: Color(0x1F48BFE3)),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          _Header(
                            controller: controller,
                            compact: constraints.maxWidth < 700,
                          ),
                          Expanded(
                            child: controller.isStageComplete
                                ? _StageCompleteView(controller: controller)
                                : _PuzzleContent(
                                    controller: controller,
                                    viewport: constraints.biggest,
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.compact});

  final PuzzleController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 24, 12, compact ? 12 : 24, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: '처음부터 다시 하기',
            onPressed: controller.restartStage,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.puzzle.stageLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  controller.puzzle.concept,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (!compact) ...[
            _ProgressDots(controller: controller),
            const SizedBox(width: 18),
          ],
          _StarForecast(stars: controller.projectedStars),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.controller});

  final PuzzleController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '문제 ${controller.puzzleIndex + 1}, 전체 ${controller.totalPuzzleCount}개',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(controller.totalPuzzleCount, (index) {
          final isDone = index < controller.puzzleIndex;
          final isCurrent = index == controller.puzzleIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isCurrent ? 28 : 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isDone || isCurrent
                  ? AppColors.primary
                  : AppColors.outline,
              borderRadius: BorderRadius.circular(99),
            ),
          );
        }),
      ),
    );
  }
}

class _StarForecast extends StatelessWidget {
  const _StarForecast({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '현재 예상 별 $stars개',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 4),
            Text('$stars', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _PuzzleContent extends StatelessWidget {
  const _PuzzleContent({required this.controller, required this.viewport});

  final PuzzleController controller;
  final Size viewport;

  @override
  Widget build(BuildContext context) {
    final isWide = viewport.width >= 900;
    final contentHeight = math.max(560.0, viewport.height - 94);
    final horizontalPadding = isWide ? 24.0 : 14.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: isWide
              ? SizedBox(
                  height: contentHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: _QuestionPanel(controller: controller),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 6,
                        child: _WorkspacePanel(controller: controller),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _QuestionPanel(controller: controller),
                    const SizedBox(height: 14),
                    _WorkspacePanel(controller: controller),
                  ],
                ),
        ),
      ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({required this.controller});

  final PuzzleController controller;

  @override
  Widget build(BuildContext context) {
    final puzzle = controller.puzzle;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                puzzle.concept,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '문장을 식으로 바꿔볼까요?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _HighlightedQuestion(text: puzzle.question),
            const SizedBox(height: 24),
            const Divider(color: AppColors.outline),
            const SizedBox(height: 18),
            const _GoalCallout(),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2D7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFFD17A00),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '생각 순서',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '무엇을 먼저 계산해야 하는지 찾고, 블록을 식의 순서대로 놓아 보세요.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedQuestion extends StatelessWidget {
  const _HighlightedQuestion({required this.text});

  final String text;

  static final RegExp _importantParts = RegExp(
    r'(\d+(?:시간|분|자루|개|cm|g|kg)?|상자|낱개|합|차|가로|세로|둘레|넓이)',
  );

  @override
  Widget build(BuildContext context) {
    final normalStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500, height: 1.65);
    final highlightStyle = normalStyle?.copyWith(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w800,
      backgroundColor: const Color(0xFFFFE8A8),
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _importantParts.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: highlightStyle));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: normalStyle, children: spans));
  }
}

class _GoalCallout extends StatelessWidget {
  const _GoalCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '목표 숫자만 맞히는 것이 아니라, 문장의 관계를 그대로 나타낸 식을 만드세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  const _WorkspacePanel({required this.controller});

  final PuzzleController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '나의 식',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${controller.puzzleIndex + 1} / ${controller.totalPuzzleCount}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EquationBoard(controller: controller),
            if (controller.expression.isNotEmpty && !controller.isCorrect) ...[
              const SizedBox(height: 10),
              _SelectedTokenControls(controller: controller),
            ],
            const SizedBox(height: 8),
            Text(
              '블록을 선택한 뒤 버튼이나 키보드 화살표로 옮길 수 있어요. 길게 눌러 끌어도 됩니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('블록 보관함', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${controller.availableTokens.length}개 남음',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _TokenTray(controller: controller),
            if (controller.currentHint case final hint?) ...[
              const SizedBox(height: 14),
              _HintBanner(
                level: controller.hintLevel,
                totalLevels: controller.puzzle.effectiveHints.length,
                text: hint,
              ),
            ],
            if (controller.feedbackMessage case final message?) ...[
              const SizedBox(height: 14),
              _FeedbackBanner(tone: controller.feedbackTone, message: message),
            ],
            const SizedBox(height: 18),
            _ActionBar(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _EquationBoard extends StatelessWidget {
  const _EquationBoard({required this.controller});

  final PuzzleController controller;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            controller.moveSelectedTokenLeft,
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            controller.moveSelectedTokenRight,
        const SingleActivator(LogicalKeyboardKey.delete):
            controller.removeSelectedToken,
        const SingleActivator(LogicalKeyboardKey.backspace):
            controller.removeSelectedToken,
      },
      child: Focus(
        canRequestFocus: !controller.isCorrect,
        child: Semantics(
          container: true,
          label: controller.expression.isEmpty
              ? '현재 식이 비어 있습니다.'
              : '현재 식 ${controller.expression.map((token) => token.label).join(' ')}',
          liveRegion: true,
          child: Container(
            height: 108,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: controller.isCorrect
                    ? AppColors.success
                    : AppColors.outline,
                width: controller.isCorrect ? 2 : 1,
              ),
            ),
            child: controller.expression.isEmpty
                ? Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app_outlined,
                          color: AppColors.mutedInk,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '아래 블록을 눌러 식을 시작하세요',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                : IgnorePointer(
                    ignoring: controller.isCorrect,
                    child: ExcludeSemantics(
                      excluding: controller.isCorrect,
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 18,
                        ),
                        buildDefaultDragHandles: false,
                        itemCount: controller.expression.length,
                        onReorderItem: (oldIndex, newIndex) =>
                            controller.reorderToken(
                              oldIndex,
                              newIndex > oldIndex ? newIndex + 1 : newIndex,
                            ),
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, _) => Transform.scale(
                              scale: 1.04,
                              child: Material(
                                color: Colors.transparent,
                                elevation: 8,
                                borderRadius: BorderRadius.circular(16),
                                child: child,
                              ),
                            ),
                          );
                        },
                        itemBuilder: (context, index) {
                          final token = controller.expression[index];
                          final isSelected =
                              token.id == controller.selectedToken?.id;
                          final tile = Padding(
                            key: ValueKey(token.id),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _TokenTile(
                              token: token,
                              inExpression: true,
                              selected: isSelected,
                              enabled: !controller.isCorrect,
                              onTap: () => controller.selectTokenAt(index),
                              onFocusChange: (hasFocus) {
                                if (hasFocus) {
                                  controller.selectTokenAt(index);
                                }
                              },
                            ),
                          );
                          if (controller.isCorrect) {
                            return tile;
                          }
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey(token.id),
                            index: index,
                            child: tile,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SelectedTokenControls extends StatelessWidget {
  const _SelectedTokenControls({required this.controller});

  final PuzzleController controller;

  @override
  Widget build(BuildContext context) {
    final selectedToken = controller.selectedToken;
    return Semantics(
      container: true,
      label: selectedToken == null
          ? '이동할 블록이 선택되지 않았습니다.'
          : '${selectedToken.label} 블록이 선택되었습니다.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            selectedToken == null
                ? '옮길 블록을 선택하세요'
                : '${selectedToken.label} 블록 선택됨',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          OutlinedButton.icon(
            onPressed: controller.canMoveSelectedTokenLeft
                ? controller.moveSelectedTokenLeft
                : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('왼쪽'),
          ),
          OutlinedButton.icon(
            onPressed: controller.canMoveSelectedTokenRight
                ? controller.moveSelectedTokenRight
                : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('오른쪽'),
          ),
          OutlinedButton.icon(
            onPressed: controller.canRemoveSelectedToken
                ? controller.removeSelectedToken
                : null,
            icon: const Icon(Icons.move_to_inbox_outlined),
            label: const Text('보관함으로'),
          ),
        ],
      ),
    );
  }
}

class _TokenTray extends StatelessWidget {
  const _TokenTray({required this.controller});

  final PuzzleController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = controller.availableTokens;
    return IgnorePointer(
      ignoring: controller.isCorrect,
      child: ExcludeSemantics(
        excluding: controller.isCorrect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFF),
            border: Border.all(color: AppColors.outline),
            borderRadius: BorderRadius.circular(18),
          ),
          child: tokens.isEmpty
              ? Center(
                  child: Text(
                    '모든 블록을 식에 놓았어요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final token in tokens)
                      _TokenTile(
                        key: ValueKey(token.id),
                        token: token,
                        enabled: !controller.isCorrect,
                        onTap: () => controller.addToken(token),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TokenTile extends StatelessWidget {
  const _TokenTile({
    required this.token,
    required this.onTap,
    this.inExpression = false,
    this.selected = false,
    this.enabled = true,
    this.onFocusChange,
    super.key,
  });

  final EquationToken token;
  final VoidCallback? onTap;
  final bool inExpression;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    final color = switch (token.kind) {
      EquationTokenKind.number => AppColors.number,
      EquationTokenKind.operator => AppColors.operator,
      EquationTokenKind.leftParenthesis ||
      EquationTokenKind.rightParenthesis => AppColors.parenthesis,
    };

    return IgnorePointer(
      ignoring: !enabled,
      child: ExcludeSemantics(
        excluding: !enabled,
        child: Semantics(
          button: true,
          selected: inExpression ? selected : null,
          label: inExpression
              ? '${token.label} 블록, ${selected ? '선택됨' : '선택하기'}'
              : '${token.label} 블록, 식에 추가',
          child: Material(
            color: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: selected
                  ? const BorderSide(color: AppColors.ink, width: 3)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              onFocusChange: enabled ? onFocusChange : null,
              borderRadius: BorderRadius.circular(15),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 54, minHeight: 54),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  child: Center(
                    child: Text(
                      token.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({
    required this.level,
    required this.totalLevels,
    required this.text,
  });

  final int level;
  final int totalLevels;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '힌트 $level단계. $text',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6DF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_rounded, color: Color(0xFFD17A00)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '힌트 $level / $totalLevels',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF8C5200),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(text, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.tone, required this.message});

  final FeedbackTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isSuccess = tone == FeedbackTone.success;
    final foreground = isSuccess
        ? const Color(0xFF125C3F)
        : const Color(0xFF8A1C2E);
    final background = isSuccess
        ? const Color(0xFFE8F5EE)
        : const Color(0xFFFDEBEC);
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.info_rounded,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.controller});

  final PuzzleController controller;

  @override
  Widget build(BuildContext context) {
    final utilityActions = <Widget>[
      OutlinedButton.icon(
        onPressed: controller.canUndo ? controller.undo : null,
        icon: const Icon(Icons.undo_rounded),
        label: const Text('되돌리기'),
      ),
      OutlinedButton.icon(
        onPressed: controller.canReset ? controller.resetExpression : null,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('초기화'),
      ),
      OutlinedButton.icon(
        onPressed: controller.canRevealHint ? controller.revealHint : null,
        icon: const Icon(Icons.lightbulb_outline_rounded),
        label: Text(controller.hintLevel == 0 ? '힌트' : '다음 힌트'),
      ),
    ];
    final primaryAction = FilledButton.icon(
      onPressed: controller.isCorrect
          ? controller.goToNextPuzzle
          : controller.submit,
      icon: Icon(
        controller.isCorrect
            ? Icons.arrow_forward_rounded
            : Icons.check_rounded,
      ),
      label: Text(controller.isCorrect ? '다음 문제' : '식 확인하기'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledLabelSize = MediaQuery.textScalerOf(context).scale(16);
        final useColumn = constraints.maxWidth < 720 || scaledLabelSize > 20;
        if (useColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final action in utilityActions) ...[
                SizedBox(width: double.infinity, child: action),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              SizedBox(width: double.infinity, child: primaryAction),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: utilityActions),
            ),
            const SizedBox(width: 12),
            primaryAction,
          ],
        );
      },
    );
  }
}

class _StageCompleteView extends StatelessWidget {
  const _StageCompleteView({required this.controller});

  final PuzzleController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF1C9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 46,
                      color: Color(0xFFD17A00),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '스테이지 완료',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '문장을 식으로 바꾸는 핵심 5문제를 해결했어요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Icon(
                        index < controller.projectedStars
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 46,
                        color: AppColors.accent,
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '오답 ${controller.wrongAnswerCount}회 · 힌트 ${controller.usedHintCount}회',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: controller.restartStage,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('다시 도전하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
