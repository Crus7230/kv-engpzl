import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../campaign/domain/campaign_models.dart';
import '../domain/discovery_models.dart';
import 'discovery_puzzle_view_model.dart';
import 'engine_discovery_puzzle_view_model.dart';

class DiscoveryPuzzleScreen extends StatefulWidget {
  const DiscoveryPuzzleScreen({
    this.viewModel,
    this.stage,
    this.onExit,
    super.key,
  }) : assert(viewModel == null || stage == null);

  final DiscoveryPuzzleViewModel? viewModel;
  final StageDefinition? stage;
  final VoidCallback? onExit;

  @override
  State<DiscoveryPuzzleScreen> createState() => _DiscoveryPuzzleScreenState();
}

class _DiscoveryPuzzleScreenState extends State<DiscoveryPuzzleScreen> {
  DiscoveryPuzzleViewModel? _viewModel;
  bool _ownsViewModel = false;
  StageDefinition? _ownedStage;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncViewModel();
  }

  @override
  void didUpdateWidget(covariant DiscoveryPuzzleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel) ||
        !identical(oldWidget.stage, widget.stage)) {
      _syncViewModel();
    }
  }

  void _syncViewModel() {
    final injectedViewModel = widget.viewModel;
    if (injectedViewModel != null) {
      if (!identical(_viewModel, injectedViewModel)) {
        _disposeOwnedViewModel();
        _viewModel = injectedViewModel;
        _ownsViewModel = false;
        _ownedStage = null;
      }
      return;
    }

    if (_ownsViewModel && identical(_ownedStage, widget.stage)) {
      return;
    }

    final mediaQuery = MediaQuery.of(context);
    final safeWidth = mediaQuery.size.width - mediaQuery.padding.horizontal;
    final safeHeight = mediaQuery.size.height - mediaQuery.padding.vertical;
    final boardConfig = safeWidth < 720 || safeHeight < 400
        ? DiscoveryBoardConfig.compactPhone
        : DiscoveryBoardConfig.standardPhone;
    _disposeOwnedViewModel();
    _viewModel = EngineDiscoveryPuzzleViewModel(
      boardConfig: boardConfig,
      stage: widget.stage,
    );
    _ownsViewModel = true;
    _ownedStage = widget.stage;
  }

  void _disposeOwnedViewModel() {
    final viewModel = _viewModel;
    if (_ownsViewModel && viewModel != null && viewModel is ChangeNotifier) {
      (viewModel as ChangeNotifier).dispose();
    }
  }

  @override
  void dispose() {
    _disposeOwnedViewModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel!;
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF5F1FF), Color(0xFFE8F7FF)],
              ),
            ),
            child: SafeArea(
              minimum: const EdgeInsets.all(2),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scaledBodySize = MediaQuery.textScalerOf(
                    context,
                  ).scale(15);
                  final dense =
                      constraints.maxWidth < 900 ||
                      constraints.maxHeight < 430 ||
                      scaledBodySize > 17;
                  final shortHeight = constraints.maxHeight < 390;
                  final compactBoard =
                      shortHeight ||
                      viewModel.boardRows <= 5 ||
                      constraints.maxWidth < 680;
                  return Column(
                    children: [
                      SizedBox(
                        height: shortHeight
                            ? 44
                            : dense
                            ? 48
                            : 60,
                        child: _GameHeader(
                          viewModel: viewModel,
                          dense: dense,
                          shortHeight: shortHeight,
                          onExit:
                              widget.onExit ??
                              () {
                                Navigator.maybePop(context);
                              },
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            dense ? 4 : 12,
                            shortHeight
                                ? 1
                                : dense
                                ? 2
                                : 6,
                            dense ? 4 : 12,
                            shortHeight
                                ? 2
                                : dense
                                ? 4
                                : 10,
                          ),
                          child: _ThreePaneGameLayout(
                            viewModel: viewModel,
                            dense: dense,
                            compactBoard: compactBoard,
                            shortHeight: shortHeight,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.viewModel,
    required this.dense,
    required this.shortHeight,
    required this.onExit,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final bool dense;
  final bool shortHeight;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 2 : 10),
      child: Row(
        children: [
          SizedBox.square(
            dimension: shortHeight ? 44 : 48,
            child: IconButton(
              tooltip: '스테이지 나가기',
              onPressed: onExit,
              style: shortHeight
                  ? IconButton.styleFrom(
                      minimumSize: const Size.square(44),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          SizedBox(width: dense ? 2 : 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    viewModel.stageLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!dense) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      viewModel.concept,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _HeaderMetric(
            icon: Icons.tune_rounded,
            label: viewModel.difficultyLabel,
            color: AppColors.primaryDark,
            compactHeight: shortHeight,
          ),
          SizedBox(width: dense ? 4 : 8),
          if (!dense) ...[
            _HeaderMetric(
              icon: Icons.auto_awesome_rounded,
              label: '${viewModel.score}',
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
          ],
          _HeaderMetric(
            icon: Icons.inventory_2_rounded,
            label:
                '${viewModel.discoveredBlocks.length}/${viewModel.requiredBlockCount}',
            color: AppColors.primary,
            compactHeight: shortHeight,
          ),
          SizedBox(width: dense ? 4 : 8),
          _HeaderMetric(
            icon: Icons.swap_horiz_rounded,
            label: '${viewModel.movesLeft}',
            color: const Color(0xFFE56A42),
            compactHeight: shortHeight,
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.icon,
    required this.label,
    required this.color,
    this.compactHeight = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compactHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compactHeight ? 34 : 38,
      constraints: BoxConstraints(minWidth: compactHeight ? 52 : 56),
      padding: EdgeInsets.symmetric(horizontal: compactHeight ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compactHeight ? 17 : 19, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: compactHeight ? 12 : 14),
          ),
        ],
      ),
    );
  }
}

class _ThreePaneGameLayout extends StatelessWidget {
  const _ThreePaneGameLayout({
    required this.viewModel,
    required this.dense,
    required this.compactBoard,
    required this.shortHeight,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final bool dense;
  final bool compactBoard;
  final bool shortHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return _NarrowFallbackLayout(
            viewModel: viewModel,
            shortHeight: shortHeight,
          );
        }

        final compactSafe = compactBoard && constraints.maxWidth < 600;
        final gap = compactSafe
            ? 4.0
            : dense
            ? 6.0
            : 12.0;
        final boardFraction = compactBoard ? 0.38 : 0.40;
        final minimumBoardWidth = compactSafe
            ? 218.0
            : compactBoard
            ? 238.0
            : 264.0;
        final preferredBoardWidth = math.max(
          minimumBoardWidth,
          constraints.maxWidth * boardFraction,
        );
        final maximumBoardWidth =
            constraints.maxWidth -
            gap * 2 -
            (compactSafe
                ? 128
                : compactBoard
                ? 110
                : 128) -
            (compactBoard ? 218 : 230);
        final boardWidth = shortHeight
            ? math.min(
                constraints.maxHeight,
                math.min(246.0, maximumBoardWidth),
              )
            : math.min(
                constraints.maxHeight,
                math.min(preferredBoardWidth, maximumBoardWidth),
              );
        final sidePanelWidth = constraints.maxWidth - boardWidth - gap * 2;
        final preferredQuestionWidth =
            sidePanelWidth *
            (compactSafe
                ? 0.37
                : compactBoard
                ? 0.36
                : 0.33);
        const minimumQuestionWidth = 128.0;
        final minimumWorkspaceWidth = compactBoard ? 218.0 : 230.0;
        final questionWidth = math.min(
          math.max(minimumQuestionWidth, preferredQuestionWidth),
          sidePanelWidth - minimumWorkspaceWidth,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: questionWidth,
              child: _QuestionPanel(
                viewModel: viewModel,
                dense: dense,
                ultraCompact: compactBoard,
                shortHeight: shortHeight,
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: boardWidth,
              child: _DiscoveryBoardPanel(
                viewModel: viewModel,
                dense: dense,
                shortHeight: shortHeight,
                compactBoard: compactBoard,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _EquationWorkspace(
                viewModel: viewModel,
                dense: dense,
                shortHeight: shortHeight,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NarrowFallbackLayout extends StatelessWidget {
  const _NarrowFallbackLayout({
    required this.viewModel,
    required this.shortHeight,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final bool shortHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final questionHeight = math.min(88.0, constraints.maxHeight * 0.28);
        return Column(
          children: [
            SizedBox(
              height: questionHeight,
              child: _QuestionPanel(
                viewModel: viewModel,
                dense: true,
                ultraCompact: true,
                shortHeight: shortHeight,
                horizontal: true,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _DiscoveryBoardPanel(
                      viewModel: viewModel,
                      dense: true,
                      shortHeight: shortHeight,
                      compactBoard: true,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 6,
                    child: _EquationWorkspace(
                      viewModel: viewModel,
                      dense: true,
                      shortHeight: shortHeight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.viewModel,
    required this.dense,
    required this.ultraCompact,
    required this.shortHeight,
    this.horizontal = false,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final bool dense;
  final bool ultraCompact;
  final bool shortHeight;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(
          shortHeight
              ? 5
              : dense
              ? 7
              : 14,
        ),
        child: horizontal
            ? Row(
                children: [
                  _QuestionIcon(
                    size: shortHeight ? 44 : 48,
                    description: viewModel.visualDescription,
                  ),
                  SizedBox(width: shortHeight ? 5 : 8),
                  Expanded(
                    child: _HighlightedQuestion(
                      text: viewModel.question,
                      maxLines: 3,
                      compact: true,
                    ),
                  ),
                  SizedBox(width: shortHeight ? 5 : 8),
                  SizedBox(
                    width: 82,
                    child: _CollectionProgress(viewModel: viewModel),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _QuestionIcon(
                        description: viewModel.visualDescription,
                        size: shortHeight
                            ? 44
                            : ultraCompact
                            ? 48
                            : 56,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          ultraCompact ? '문제' : '문장을 읽어 보세요',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: shortHeight
                        ? 4
                        : dense
                        ? 6
                        : 12,
                  ),
                  Expanded(
                    child: _HighlightedQuestion(
                      text: viewModel.question,
                      maxLines: shortHeight
                          ? 10
                          : ultraCompact
                          ? 11
                          : 10,
                      compact: dense,
                    ),
                  ),
                  if (!dense) ...[
                    const SizedBox(height: 8),
                    Text(
                      '필요한 숫자와 기호를 중앙 보드에서 먼저 발굴하세요.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (!shortHeight) ...[
                    SizedBox(height: dense ? 5 : 10),
                    _CollectionProgress(viewModel: viewModel),
                  ],
                ],
              ),
      ),
    );
  }
}

class _QuestionIcon extends StatelessWidget {
  const _QuestionIcon({required this.size, required this.description});

  final double size;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: description,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0C8),
            borderRadius: BorderRadius.circular(size * 0.24),
          ),
          child: description.startsWith('연필이 4자루씩')
              ? const CustomPaint(painter: _PencilBundlePainter())
              : Icon(
                  Icons.menu_book_outlined,
                  size: size * .6,
                  color: const Color(0xFF9A7037),
                ),
        ),
      ),
    );
  }
}

class _PencilBundlePainter extends CustomPainter {
  const _PencilBundlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final boxFill = Paint()..color = Colors.white.withValues(alpha: 0.88);
    final boxStroke = Paint()
      ..color = const Color(0xFFB76700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * 0.025);
    final pencilPaint = Paint()
      ..color = const Color(0xFF275EA8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.5, size.width * 0.045);

    final gap = size.width * 0.055;
    final boxWidth = (size.width - gap * 4) / 3;
    final boxTop = size.height * 0.14;
    final boxHeight = size.height * 0.48;
    for (var boxIndex = 0; boxIndex < 3; boxIndex += 1) {
      final left = gap + boxIndex * (boxWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, boxTop, boxWidth, boxHeight),
        Radius.circular(size.width * 0.045),
      );
      canvas
        ..drawRRect(rect, boxFill)
        ..drawRRect(rect, boxStroke);
      for (var pencilIndex = 0; pencilIndex < 4; pencilIndex += 1) {
        final column = pencilIndex % 2;
        final row = pencilIndex ~/ 2;
        final x = left + boxWidth * (0.34 + column * 0.32);
        final y = boxTop + boxHeight * (0.3 + row * 0.4);
        canvas.drawLine(
          Offset(x, y - size.height * 0.045),
          Offset(x, y + size.height * 0.045),
          pencilPaint,
        );
      }
    }

    final looseY = size.height * 0.79;
    for (final x in [size.width * 0.43, size.width * 0.57]) {
      canvas.drawLine(
        Offset(x, looseY - size.height * 0.07),
        Offset(x, looseY + size.height * 0.07),
        pencilPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PencilBundlePainter oldDelegate) => false;
}

class _HighlightedQuestion extends StatelessWidget {
  const _HighlightedQuestion({
    required this.text,
    required this.maxLines,
    required this.compact,
  });

  final String text;
  final int maxLines;
  final bool compact;

  static final RegExp _importantParts = RegExp(
    r'(\d+(?:시간|분|자루|개|cm|g|kg)?|상자|봉지|낱개|모두|합|차|가로|세로)',
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final needsTighterCompactText =
            compact && textScaler.scale(13.5) > 16.5;
        final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: compact
              ? needsTighterCompactText
                    ? 12
                    : 13.5
              : 16,
          height: compact
              ? needsTighterCompactText
                    ? 1.25
                    : 1.35
              : 1.5,
          fontWeight: FontWeight.w600,
        );
        final highlightStyle = baseStyle?.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w900,
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

        return Text.rich(
          TextSpan(style: baseStyle, children: spans),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _CollectionProgress extends StatelessWidget {
  const _CollectionProgress({required this.viewModel});

  final DiscoveryPuzzleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final discovered = viewModel.discoveredBlocks.length;
    final total = viewModel.requiredBlockCount;
    return Semantics(
      label: '필요한 수식 블록 $total개 중 $discovered개 발굴',
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '블록 $discovered / $total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: discovered / total,
                minHeight: 5,
                backgroundColor: Colors.white,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryBoardPanel extends StatelessWidget {
  const _DiscoveryBoardPanel({
    required this.viewModel,
    required this.dense,
    required this.shortHeight,
    required this.compactBoard,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final bool dense;
  final bool shortHeight;
  final bool compactBoard;

  @override
  Widget build(BuildContext context) {
    // Compact layout changes the panel size, not the logical board. Cropping a
    // running 6x6 session after a window resize could hide a required seal.
    final visibleRows = viewModel.boardRows;
    final visibleColumns = viewModel.boardColumns;
    final boardCells = viewModel.boardCells;
    final visibleIndices = <int>[
      for (var row = 0; row < visibleRows; row += 1)
        for (var column = 0; column < visibleColumns; column += 1)
          row * viewModel.boardColumns + column,
    ];

    return Card(
      color: const Color(0xFF34305A),
      child: Padding(
        padding: EdgeInsets.all(
          shortHeight
              ? 3
              : dense
              ? 4
              : 8,
        ),
        child: Column(
          children: [
            SizedBox(
              height: shortHeight
                  ? 18
                  : dense
                  ? 24
                  : 32,
              child: Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: shortHeight ? 16 : 19,
                    color: Colors.white,
                  ),
                  SizedBox(width: shortHeight ? 3 : 5),
                  Expanded(
                    child: Text(
                      '발굴 보드',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontSize: shortHeight
                            ? 12
                            : dense
                            ? 14
                            : 17,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: shortHeight ? 5 : 7,
                      vertical: shortHeight ? 1 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${viewModel.movesLeft}회',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: shortHeight ? 10.5 : 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: shortHeight ? 1 : 2),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boardSide = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Center(
                    child: SizedBox.square(
                      dimension: boardSide,
                      child: _GemGrid(
                        viewModel: viewModel,
                        boardCells: boardCells,
                        visibleIndices: visibleIndices,
                        crossAxisCount: visibleColumns,
                        spacing: shortHeight ? 1 : 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GemGrid extends StatelessWidget {
  const _GemGrid({
    required this.viewModel,
    required this.boardCells,
    required this.visibleIndices,
    required this.crossAxisCount,
    required this.spacing,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final List<DiscoveryGemCell> boardCells;
  final List<int> visibleIndices;
  final int crossAxisCount;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GridView.builder(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibleIndices.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
        ),
        itemBuilder: (context, itemIndex) {
          final boardIndex = visibleIndices[itemIndex];
          final cell = boardCells[boardIndex];
          return _GemButton(
            cell: cell,
            row: boardIndex ~/ viewModel.boardColumns + 1,
            column: boardIndex % viewModel.boardColumns + 1,
            selected: viewModel.selectedCellIndex == boardIndex,
            onPressed: () => viewModel.selectGem(boardIndex),
          );
        },
      ),
    );
  }
}

class _GemButton extends StatelessWidget {
  const _GemButton({
    required this.cell,
    required this.row,
    required this.column,
    required this.selected,
    required this.onPressed,
  });

  final DiscoveryGemCell cell;
  final int row;
  final int column;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = _gemStyle(cell.kind);
    final colorAssist = MediaQuery.highContrastOf(context);
    final sealKind = cell.sealKind;
    final sealLabel = switch (sealKind) {
      DiscoverySealKind.number => '숫자 봉인',
      DiscoverySealKind.operatorSymbol => '연산자 봉인',
      DiscoverySealKind.parenthesis => '괄호 봉인',
      null => null,
    };
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$row행 $column열, ${style.name} 보석${sealLabel == null ? '' : ', $sealLabel 있음'}'
          '${cell.sealLayers > 1 ? ', ${cell.sealLayers}층 봉인' : ''}'
          '${cell.linePowerKind == null
              ? ''
              : cell.linePowerKind == DiscoveryLinePowerKind.row
              ? ', 가로 직선 파워'
              : ', 세로 직선 파워'}'
          '${selected ? ', 선택됨' : ', 선택하기'}',
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF242144),
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x99FFFFFF),
                    blurRadius: 7,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            color: selected || colorAssist ? Colors.white : Colors.transparent,
            width: selected
                ? 3
                : colorAssist
                ? 2
                : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [style.lightColor, style.color],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: onPressed,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final iconSize =
                      math.min(constraints.maxWidth, constraints.maxHeight) *
                      0.58;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Icon(
                          style.icon,
                          color: Colors.white,
                          size: iconSize,
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 3),
                          ],
                        ),
                      ),
                      if (cell.linePowerKind != null)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xCC202744),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              cell.linePowerKind == DiscoveryLinePowerKind.row
                                  ? Icons.swap_horiz_rounded
                                  : Icons.swap_vert_rounded,
                              color: Colors.white,
                              size: iconSize * .8,
                            ),
                          ),
                        ),
                      if (cell.sealLayers > 1)
                        Positioned(
                          left: 2,
                          bottom: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF202744),
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                '${cell.sealLayers}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (sealKind != null)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF202744),
                              border: Border.all(color: Colors.white, width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              switch (sealKind) {
                                DiscoverySealKind.number => Icons.pin_rounded,
                                DiscoverySealKind.operatorSymbol =>
                                  Icons.calculate_rounded,
                                DiscoverySealKind.parenthesis =>
                                  Icons.data_object_rounded,
                              },
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  _GemStyle _gemStyle(DiscoveryGemKind kind) {
    return switch (kind) {
      DiscoveryGemKind.berry => const _GemStyle(
        name: '베리색',
        color: Color(0xFFE44867),
        lightColor: Color(0xFFFF7C93),
        icon: Icons.favorite_rounded,
      ),
      DiscoveryGemKind.ocean => const _GemStyle(
        name: '바다색',
        color: Color(0xFF2E74D1),
        lightColor: Color(0xFF6EB8FF),
        icon: Icons.water_drop_rounded,
      ),
      DiscoveryGemKind.citrus => const _GemStyle(
        name: '귤색',
        color: Color(0xFFE87928),
        lightColor: Color(0xFFFFB13D),
        icon: Icons.circle,
      ),
      DiscoveryGemKind.grape => const _GemStyle(
        name: '포도색',
        color: Color(0xFF7751D1),
        lightColor: Color(0xFFA888F2),
        icon: Icons.auto_awesome_rounded,
      ),
      DiscoveryGemKind.leaf => const _GemStyle(
        name: '잎색',
        color: Color(0xFF2F966E),
        lightColor: Color(0xFF69C79F),
        icon: Icons.eco_rounded,
      ),
      DiscoveryGemKind.sun => const _GemStyle(
        name: '햇빛색',
        color: Color(0xFFE0A51B),
        lightColor: Color(0xFFFFD84E),
        icon: Icons.star_rounded,
      ),
    };
  }
}

class _GemStyle {
  const _GemStyle({
    required this.name,
    required this.color,
    required this.lightColor,
    required this.icon,
  });

  final String name;
  final Color color;
  final Color lightColor;
  final IconData icon;
}

class _EquationWorkspace extends StatelessWidget {
  const _EquationWorkspace({
    required this.viewModel,
    required this.dense,
    required this.shortHeight,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final bool dense;
  final bool shortHeight;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final veryTight = shortHeight || constraints.maxHeight < 290;
          final tight =
              dense ||
              constraints.maxWidth < 290 ||
              constraints.maxHeight < 340;
          final rowHeight = veryTight
              ? 44.0
              : tight
              ? 50.0
              : 58.0;
          return Padding(
            padding: EdgeInsets.all(
              veryTight
                  ? 4
                  : tight
                  ? 6
                  : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: veryTight
                      ? 20
                      : tight
                      ? 24
                      : 30,
                  child: Row(
                    children: [
                      Icon(
                        Icons.construction_rounded,
                        color: AppColors.primary,
                        size: veryTight ? 17 : 20,
                      ),
                      SizedBox(width: veryTight ? 3 : 5),
                      Expanded(
                        child: Text(
                          '획득 블록 → 식 만들기',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: veryTight
                                    ? 12
                                    : tight
                                    ? 14
                                    : 17,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                _WorkspaceSectionLabel(
                  label: '획득 보관함',
                  trailing:
                      '${viewModel.discoveredBlocks.length}/${viewModel.requiredBlockCount}',
                  compact: veryTight,
                ),
                SizedBox(
                  height: rowHeight,
                  child: _DiscoveredBlockRow(viewModel: viewModel),
                ),
                _WorkspaceSectionLabel(label: '나의 식', compact: veryTight),
                SizedBox(
                  height: rowHeight,
                  child: _AnswerBlockRow(viewModel: viewModel),
                ),
                SizedBox(
                  height: veryTight
                      ? 1
                      : tight
                      ? 3
                      : 6,
                ),
                Expanded(
                  child: _FeedbackStrip(
                    message: viewModel.feedbackMessage,
                    tone: viewModel.feedbackTone,
                    dense: tight,
                    maxLines: 3,
                  ),
                ),
                SizedBox(
                  height: veryTight
                      ? 1
                      : tight
                      ? 3
                      : 6,
                ),
                _WorkspaceActions(
                  viewModel: viewModel,
                  dense: tight,
                  compactHeight: veryTight,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WorkspaceSectionLabel extends StatelessWidget {
  const _WorkspaceSectionLabel({
    required this.label,
    this.trailing,
    this.compact = false,
  });

  final String label;
  final String? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 16 : 21,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: compact ? 10.5 : 12.5),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: compact ? 10 : 12),
            ),
        ],
      ),
    );
  }
}

class _DiscoveredBlockRow extends StatelessWidget {
  const _DiscoveredBlockRow({required this.viewModel});

  final DiscoveryPuzzleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final discoveredBlocks = viewModel.discoveredBlocks;
    final answerBlockIds = viewModel.answerBlocks
        .map((block) => block.id)
        .toSet();
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotSize = _tokenSlotSize(
          constraints.maxWidth,
          viewModel.requiredBlockCount,
        ).clamp(0, constraints.maxHeight).toDouble();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(viewModel.requiredBlockCount, (index) {
            if (index >= discoveredBlocks.length) {
              return _LockedBlockSlot(size: slotSize);
            }
            final block = discoveredBlocks[index];
            final inAnswer = answerBlockIds.contains(block.id);
            if (inAnswer) {
              return _MovedBlockSlot(size: slotSize);
            }
            return _EquationBlockButton(
              block: block,
              size: slotSize,
              semanticAction: '식에 추가',
              onPressed: () => viewModel.addBlockToAnswer(block.id),
            );
          }),
        );
      },
    );
  }
}

class _AnswerBlockRow extends StatelessWidget {
  const _AnswerBlockRow({required this.viewModel});

  final DiscoveryPuzzleViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final answerBlocks = viewModel.answerBlocks;
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotSize = _tokenSlotSize(
          constraints.maxWidth,
          viewModel.requiredBlockCount,
        ).clamp(0, constraints.maxHeight).toDouble();
        return Semantics(
          container: true,
          liveRegion: true,
          label: answerBlocks.isEmpty
              ? '현재 식이 비어 있습니다.'
              : '현재 식 ${answerBlocks.map((block) => block.label).join(' ')}',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(viewModel.requiredBlockCount, (index) {
              if (index >= answerBlocks.length) {
                return _EmptyAnswerSlot(
                  size: slotSize,
                  indexLabel: '${index + 1}',
                );
              }
              final block = answerBlocks[index];
              return _EquationBlockButton(
                block: block,
                size: slotSize,
                semanticAction: '보관함으로 돌려보내기',
                selected: true,
                onPressed: () => viewModel.removeBlockFromAnswer(block.id),
              );
            }),
          ),
        );
      },
    );
  }
}

double _tokenSlotSize(double width, int count) {
  const gapBudget = 2.0;
  return ((width - gapBudget * (count - 1)) / count)
      .clamp(0.0, 52.0)
      .toDouble();
}

class _EquationBlockButton extends StatelessWidget {
  const _EquationBlockButton({
    required this.block,
    required this.size,
    required this.semanticAction,
    required this.onPressed,
    this.selected = false,
  });

  final DiscoveryEquationBlock block;
  final double size;
  final String semanticAction;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = switch (block.kind) {
      DiscoveryEquationBlockKind.number => AppColors.number,
      DiscoveryEquationBlockKind.operatorSymbol => AppColors.operator,
      DiscoveryEquationBlockKind.parenthesis => AppColors.parenthesis,
    };
    return Semantics(
      button: true,
      label: '${block.label} 블록, $semanticAction',
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              decoration: selected
                  ? BoxDecoration(
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  block.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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

class _LockedBlockSlot extends StatelessWidget {
  const _LockedBlockSlot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '아직 발굴하지 않은 블록',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F6),
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.lock_rounded,
          size: size * 0.42,
          color: AppColors.mutedInk,
        ),
      ),
    );
  }
}

class _MovedBlockSlot extends StatelessWidget {
  const _MovedBlockSlot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '식으로 옮긴 블록',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F5EF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.north_east_rounded,
          size: size * 0.44,
          color: AppColors.success,
        ),
      ),
    );
  }
}

class _EmptyAnswerSlot extends StatelessWidget {
  const _EmptyAnswerSlot({required this.size, required this.indexLabel});

  final double size;
  final String indexLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$indexLabel번 식 자리, 비어 있음',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          border: Border.all(color: AppColors.outline, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          indexLabel,
          style: const TextStyle(
            color: AppColors.outline,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FeedbackStrip extends StatelessWidget {
  const _FeedbackStrip({
    required this.message,
    required this.tone,
    required this.dense,
    required this.maxLines,
  });

  final String message;
  final DiscoveryFeedbackTone tone;
  final bool dense;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (tone) {
      DiscoveryFeedbackTone.neutral => (
        const Color(0xFFF1EFFF),
        AppColors.primaryDark,
        Icons.info_outline_rounded,
      ),
      DiscoveryFeedbackTone.reward => (
        const Color(0xFFFFF1CA),
        const Color(0xFF9A5800),
        Icons.auto_awesome_rounded,
      ),
      DiscoveryFeedbackTone.warning => (
        const Color(0xFFFDEBEC),
        const Color(0xFF8A1C2E),
        Icons.lightbulb_outline_rounded,
      ),
      DiscoveryFeedbackTone.success => (
        const Color(0xFFE6F4EC),
        const Color(0xFF125C3F),
        Icons.check_circle_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: '$message. 안내 전체 보기',
      button: true,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('풀이 도움'),
            content: SingleChildScrollView(child: Text(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minHeight: 26),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 9,
            vertical: dense ? 2 : 5,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Icon(icon, size: dense ? 16 : 19, color: foreground),
              const SizedBox(width: 5),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final style = Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(
                          color: foreground,
                          fontSize: dense ? 11.5 : 13,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        );
                    final measure = TextPainter(
                      text: TextSpan(text: '가', style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final lineHeight = measure.height;
                    measure.dispose();
                    final visibleLines =
                        constraints.maxHeight.isFinite && lineHeight > 0
                        ? (constraints.maxHeight / lineHeight).floor().clamp(
                            1,
                            maxLines,
                          )
                        : maxLines;
                    return Text(
                      message,
                      maxLines: visibleLines,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    );
                  },
                ),
              ),
              Icon(
                Icons.open_in_full,
                size: dense ? 11 : 13,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceActions extends StatelessWidget {
  const _WorkspaceActions({
    required this.viewModel,
    required this.dense,
    required this.compactHeight,
  });

  final DiscoveryPuzzleViewModel viewModel;
  final bool dense;
  final bool compactHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compactHeight ? 44 : 48,
      child: Row(
        children: [
          SizedBox.square(
            dimension: compactHeight ? 44 : 48,
            child: IconButton.filledTonal(
              tooltip: '이 스테이지 처음부터 다시 도전',
              onPressed: viewModel.resetRound,
              style: compactHeight
                  ? IconButton.styleFrom(
                      minimumSize: const Size.square(44),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox.square(
            dimension: compactHeight ? 44 : 48,
            child: IconButton.filledTonal(
              tooltip: '힌트 보기',
              onPressed: viewModel.canRevealHint ? viewModel.revealHint : null,
              style: compactHeight
                  ? IconButton.styleFrom(
                      minimumSize: const Size.square(44),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              icon: const Icon(Icons.lightbulb_outline_rounded),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FilledButton.icon(
              onPressed: viewModel.isAnswerCorrect
                  ? viewModel is DiscoveryCompletionHandler
                        ? (viewModel as DiscoveryCompletionHandler)
                              .continueToResult
                        : () => _showLearningReviewDialog(context, viewModel)
                  : viewModel.canCheckAnswer
                  ? viewModel.checkAnswer
                  : null,
              icon: Icon(
                viewModel.isAnswerCorrect
                    ? Icons.menu_book_rounded
                    : Icons.check_rounded,
                size: 20,
              ),
              style: compactHeight
                  ? FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              label: Text(
                viewModel.isAnswerCorrect
                    ? viewModel is DiscoveryCompletionHandler
                          ? '결과 보기'
                          : '풀이 보기'
                    : dense
                    ? '확인'
                    : '식 확인',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showLearningReviewDialog(
  BuildContext context,
  DiscoveryPuzzleViewModel viewModel,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('풀이와 다음 생각')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '배운 점',
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(viewModel.learningObjective),
              const SizedBox(height: 14),
              Text(
                '풀이 단계',
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              for (
                var index = 0;
                index < viewModel.workedSolutionSteps.length;
                index += 1
              ) ...[
                _WorkedSolutionCard(
                  number: index + 1,
                  expression: viewModel.workedSolutionSteps[index].expression,
                  explanation: viewModel.workedSolutionSteps[index].explanation,
                ),
                if (index < viewModel.workedSolutionSteps.length - 1)
                  const SizedBox(height: 6),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다음 생각',
                      style: Theme.of(dialogContext).textTheme.titleMedium
                          ?.copyWith(color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 4),
                    Text(viewModel.transferPrompt.question),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
        ],
      );
    },
  );
}

class _WorkedSolutionCard extends StatelessWidget {
  const _WorkedSolutionCard({
    required this.number,
    required this.expression,
    required this.explanation,
  });

  final int number;
  final String expression;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expression,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(explanation),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
