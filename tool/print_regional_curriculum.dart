import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';

void main() {
  stdout.writeln('# 7리전 스테이지 카탈로그');
  stdout.writeln();
  stdout.writeln(
    '> 자동 출력입니다. 원본은 '
    '`lib/features/campaign/data/regional_campaign.dart`입니다.',
  );
  for (final region in initialCampaign.regions) {
    stdout.writeln();
    stdout.writeln('## R${region.number} ${region.title}');
    for (final chapter in region.chapters) {
      stdout.writeln();
      stdout.writeln('### C${chapter.number} ${chapter.title}');
      stdout.writeln();
      stdout.writeln('| ID | 스테이지 | skillId | 대표 문제·식 | M/B/C/R | W/P/L |');
      stdout.writeln('| --- | --- | --- | --- | --- | --- |');
      for (final stage in chapter.stages) {
        final math = stage.mathDifficulty;
        final moves = stage.moveBudget;
        stdout.writeln(
          '| ${stage.id} | ${_escape(stage.title)} | '
          '`${_escape(stage.skillId)}` | `${_escape(stage.conceptLabel)}` | '
          '${math.tier.name.toUpperCase()}/'
          '${stage.matchDifficulty.tier.name.toUpperCase()}/'
          '${math.compositionTier.name.toUpperCase()}/'
          '${math.readingTier.name.toUpperCase()} | '
          '${moves.referenceMoves}/${moves.parMoves}/${moves.moveLimit} |',
        );
      }
    }
  }
}

String _escape(String value) => value.replaceAll('|', r'\|');
