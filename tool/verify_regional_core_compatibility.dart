import 'dart:io';

import '../lib/features/campaign/data/regional_campaign.dart';
import '../lib/features/campaign/domain/campaign_models.dart';

void main() {
  final coreStages = <StageDefinition>[];
  final stageIds = <String>{};

  _expect(
    regionalCampaign.regions.length == 7,
    'The regional campaign must retain its seven legacy regions.',
  );

  for (
    var regionIndex = 0;
    regionIndex < regionalCampaign.regions.length;
    regionIndex += 1
  ) {
    final region = regionalCampaign.regions[regionIndex];
    final regionNumber = regionIndex + 1;
    _expect(
      region.number == regionNumber,
      '${region.id} must remain region $regionNumber.',
    );

    final coreChapters = region.chapters
        .where((chapter) => chapter.number >= 1 && chapter.number <= 3)
        .toList(growable: false);
    _expect(
      coreChapters.length == 3,
      '${region.id} must retain exactly one C01, C02, and C03.',
    );

    for (
      var chapterIndex = 0;
      chapterIndex < coreChapters.length;
      chapterIndex += 1
    ) {
      final chapter = coreChapters[chapterIndex];
      final chapterNumber = chapterIndex + 1;
      final expectedChapterId = _chapterId(regionNumber, chapterNumber);
      _expect(
        chapter.number == chapterNumber && chapter.id == expectedChapterId,
        '${region.id} core chapter $chapterNumber must remain '
        '$expectedChapterId.',
      );
      _expect(
        chapter.stages.length == 10,
        '$expectedChapterId must retain its ten core stages.',
      );

      for (
        var stageIndex = 0;
        stageIndex < chapter.stages.length;
        stageIndex += 1
      ) {
        final stage = chapter.stages[stageIndex];
        final stageNumber = stageIndex + 1;
        final expectedStageId = _stageId(
          regionNumber,
          chapterNumber,
          stageNumber,
        );
        _expect(
          stage.number == stageNumber && stage.id == expectedStageId,
          '$expectedChapterId stage $stageNumber must remain '
          '$expectedStageId.',
        );
        _expect(
          stageIds.add(stage.id),
          'Core stage ID ${stage.id} is duplicated.',
        );
        _verifyGeneratedIdentity(
          stage,
          regionNumber: regionNumber,
          chapterNumber: chapterNumber,
          stageNumber: stageNumber,
        );
        coreStages.add(stage);
      }
    }
  }

  _expect(
    coreStages.length == 210 && stageIds.length == 210,
    'C01-C03 must retain exactly 210 unique core stages.',
  );

  final actualSkillManifest = coreStages
      .map((stage) => '${stage.id}|${stage.skillId}')
      .join('\n');
  _expect(
    actualSkillManifest == _coreSkillManifest.trim(),
    'The ordered C01-C03 stage ID and skillId manifest changed.',
  );

  stdout.writeln(
    'Regional core compatibility verification passed: 210 C01-C03 stages '
    'retain their IDs, skill IDs, puzzle IDs, seeds, and phone fixture '
    'identities.',
  );
}

void _verifyGeneratedIdentity(
  StageDefinition stage, {
  required int regionNumber,
  required int chapterNumber,
  required int stageNumber,
}) {
  final expectedSeed =
      202600000 + regionNumber * 10000 + chapterNumber * 100 + stageNumber;
  _expect(
    stage.seed == expectedSeed,
    '${stage.id} seed changed: expected $expectedSeed, got ${stage.seed}.',
  );

  final expectedPuzzleId = 'planned.${stage.skillId}.${stage.id}';
  _expect(
    stage.puzzleId == expectedPuzzleId,
    '${stage.id} puzzleId changed: expected $expectedPuzzleId, got '
    '${stage.puzzleId}.',
  );

  final variants = stage.boardVariants.variants;
  _expect(
    variants.length == 2,
    '${stage.id} must retain exactly its 5x5 and 6x6 fixtures.',
  );
  final compact = variants
      .where(
        (variant) => variant.config.rows == 5 && variant.config.columns == 5,
      )
      .toList(growable: false);
  final standard = variants
      .where(
        (variant) => variant.config.rows == 6 && variant.config.columns == 6,
      )
      .toList(growable: false);
  _expect(
    compact.length == 1 && standard.length == 1,
    '${stage.id} must retain one 5x5 and one 6x6 fixture.',
  );
  _expect(
    compact.single.fixtureId == '${stage.id}-5x5-v1' &&
        compact.single.seed == expectedSeed * 10 + 5,
    '${stage.id} 5x5 fixture identity changed.',
  );
  _expect(
    standard.single.fixtureId == '${stage.id}-6x6-v1' &&
        standard.single.seed == expectedSeed * 10 + 6,
    '${stage.id} 6x6 fixture identity changed.',
  );
}

String _chapterId(int region, int chapter) =>
    'r${_twoDigits(region)}-c${_twoDigits(chapter)}';

String _stageId(int region, int chapter, int stage) =>
    '${_chapterId(region, chapter)}-s${_twoDigits(stage)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

const String _coreSkillManifest = '''
r01-c01-s01|arith.add.combine.10
r01-c01-s02|arith.sub.takeaway.10
r01-c01-s03|arith.add.combine.10
r01-c01-s04|arith.sub.takeaway.10
r01-c01-s05|arith.add.compare_more
r01-c01-s06|arith.sub.difference
r01-c01-s07|arith.add.bridge_10
r01-c01-s08|arith.sub.bridge_10
r01-c01-s09|arith.mixed.add_two_step
r01-c01-s10|arith.mixed.add_sub_two_step
r01-c02-s01|arith.mul.equal_groups
r01-c02-s02|arith.mul.array
r01-c02-s03|arith.div.equal_share
r01-c02-s04|arith.div.equal_group
r01-c02-s05|arith.mixed.mul_add
r01-c02-s06|arith.mixed.mul_sub
r01-c02-s07|arith.mixed.div_add
r01-c02-s08|arith.mixed.div_mul
r01-c02-s09|arith.mixed.mul_sub
r01-c02-s10|arith.mixed.chapter_check
r01-c03-s01|arith.order.mul_before_add
r01-c03-s02|arith.parentheses.grouping
r01-c03-s03|arith.order.mul_before_sub
r01-c03-s04|arith.order.div_before_add
r01-c03-s05|arith.parentheses.difference_group
r01-c03-s06|arith.parentheses.divisor_group
r01-c03-s07|arith.token.duplicate_value
r01-c03-s08|arith.order.div_before_sub
r01-c03-s09|arith.parentheses.transfer
r01-c03-s10|arith.order.region_mastery
r02-c01-s01|pattern.additive.next_small
r02-c01-s02|pattern.subtractive.next_small
r02-c01-s03|pattern.additive.infer_step
r02-c01-s04|pattern.subtractive.infer_step
r02-c01-s05|pattern.additive.transfer
r02-c01-s06|pattern.subtractive.transfer
r02-c01-s07|pattern.additive.nth_term
r02-c01-s08|pattern.subtractive.nth_term
r02-c01-s09|pattern.compare.next_values
r02-c01-s10|pattern.additive.nth_term_mastery
r02-c02-s01|pattern.geometric.double
r02-c02-s02|pattern.geometric.half
r02-c02-s03|pattern.alternate.add_steps
r02-c02-s04|pattern.alternate.mul_add
r02-c02-s05|pattern.paired_growth
r02-c02-s06|pattern.additive.next_review
r02-c02-s07|pattern.geometric.double_review
r02-c02-s08|pattern.subtractive.next_review
r02-c02-s09|pattern.recursive.mul_add
r02-c02-s10|pattern.recursive.mul_add_transfer
r02-c03-s01|pattern.table.forward_mul_add
r02-c03-s02|pattern.table.forward_transfer
r02-c03-s03|pattern.table.inverse_mul_add
r02-c03-s04|pattern.machine.parenthesized
r02-c03-s05|pattern.second_difference.next
r02-c03-s06|pattern.square_numbers
r02-c03-s07|pattern.triangular_numbers
r02-c03-s08|pattern.additive.power_tile_intro
r02-c03-s09|pattern.square_plus_one
r02-c03-s10|pattern.square_plus_one_mastery
r03-c01-s01|unit.time.hour_to_min
r03-c01-s02|unit.time.hour_min_to_min
r03-c01-s03|unit.time.min_to_hour
r03-c01-s04|unit.time.elapsed_cross_hour
r03-c01-s05|unit.length.m_to_cm
r03-c01-s06|unit.length.m_cm_to_cm
r03-c01-s07|unit.length.cm_to_m
r03-c01-s08|unit.length.mixed_subtract
r03-c01-s09|unit.length.km_to_m
r03-c01-s10|unit.length.km_m_to_m
r03-c02-s01|unit.mass.kg_to_g
r03-c02-s02|unit.mass.kg_g_to_g
r03-c02-s03|unit.mass.multi_step_subtract
r03-c02-s04|unit.mass.equal_packages
r03-c02-s05|unit.capacity.l_to_ml
r03-c02-s06|unit.capacity.l_ml_to_ml
r03-c02-s07|unit.capacity.multi_step_subtract
r03-c02-s08|unit.capacity.equal_bottles
r03-c02-s09|unit.capacity.compare_mixed
r03-c02-s10|unit.capacity.mixed_total
r03-c03-s01|unit.rate.distance_from_speed_time
r03-c03-s02|unit.rate.distance_transfer
r03-c03-s03|unit.rate.time_from_distance_speed
r03-c03-s04|unit.rate.speed_from_distance_time
r03-c03-s05|unit.rate.hour_to_min_context
r03-c03-s06|unit.rate.per_minute_distance
r03-c03-s07|unit.rate.two_leg_total
r03-c03-s08|unit.rate.remaining_distance
r03-c03-s09|unit.rate.mixed_distance
r03-c03-s10|unit.rate.region_mastery
r04-c01-s01|rel.inverse.add
r04-c01-s02|rel.inverse.subtract
r04-c01-s03|rel.inverse.start
r04-c01-s04|rel.inverse.additive-two-step
r04-c01-s05|eq.balance.mixed-side
r04-c01-s06|rel.additive-comparison
r04-c01-s07|rel.sum-difference.large
r04-c01-s08|rel.sum-difference.small
r04-c01-s09|rel.consecutive-pair
r04-c01-s10|eq.additive-group-check
r04-c02-s01|rel.inverse.multiply
r04-c02-s02|rel.inverse.factor
r04-c02-s03|rel.inverse.dividend
r04-c02-s04|eq.two-step.add
r04-c02-s05|eq.two-step.subtract
r04-c02-s06|eq.grouped-factor
r04-c02-s07|rel.multiplicative.large
r04-c02-s08|rel.multiplicative.small
r04-c02-s09|eq.group-total-offset
r04-c02-s10|eq.group-total-check
r04-c03-s01|eq.balance.evaluate-side
r04-c03-s02|eq.balance.divide-side
r04-c03-s03|eq.balance.offset
r04-c03-s04|eq.linear.add
r04-c03-s05|eq.linear.subtract
r04-c03-s06|eq.factor.sum
r04-c03-s07|eq.linear.review
r04-c03-s08|rel.sum-difference.large-transfer
r04-c03-s09|rel.sum-difference.small-transfer
r04-c03-s10|eq.balance.multiplicative-check
r05-c01-s01|geo.perimeter.equilateral
r05-c01-s02|geo.perimeter.square
r05-c01-s03|geo.perimeter.rectangle
r05-c01-s04|geo.perimeter.missing-side
r05-c01-s05|geo.perimeter.triangle-missing
r05-c01-s06|geo.perimeter.regular-polygon
r05-c01-s07|geo.length.segment-sum
r05-c01-s08|geo.perimeter.square-inverse
r05-c01-s09|geo.perimeter.hexagon
r05-c01-s10|geo.perimeter.irregular
r05-c02-s01|geo.area.rectangle
r05-c02-s02|geo.area.square
r05-c02-s03|geo.area.missing-side
r05-c02-s04|geo.area.compose-add
r05-c02-s05|geo.area.compose-subtract
r05-c02-s06|geo.area.decompose
r05-c02-s07|geo.area.scale-one-side
r05-c02-s08|geo.area.tile-count
r05-c02-s09|geo.area.shaded-difference
r05-c02-s10|geo.area.composite-check
r05-c03-s01|geo.angle.complement
r05-c03-s02|geo.angle.triangle-sum
r05-c03-s03|geo.angle.supplement
r05-c03-s04|geo.angle.quadrilateral-sum
r05-c03-s05|geo.symmetry.square-axes
r05-c03-s06|geo.grid.manhattan-distance
r05-c03-s07|geo.coordinate.axis-distance
r05-c03-s08|geo.volume.rectangular-prism
r05-c03-s09|geo.solid.edge-total
r05-c03-s10|geo.area.composite-final
r06-c01-s01|ratio.scale.double
r06-c01-s02|ratio.scale.triple
r06-c01-s03|ratio.unit-rate
r06-c01-s04|ratio.unit-rate.scale
r06-c01-s05|ratio.map-scale
r06-c01-s06|ratio.equivalent.find-fourth
r06-c01-s07|ratio.partition.unit
r06-c01-s08|ratio.partition.large
r06-c01-s09|ratio.proportion.scale
r06-c01-s10|ratio.proportion.check
r06-c02-s01|fraction.of-set.half
r06-c02-s02|fraction.of-set.quarter
r06-c02-s03|fraction.of-set.three-quarters
r06-c02-s04|percent.ten
r06-c02-s05|percent.twenty
r06-c02-s06|percent.twenty-five
r06-c02-s07|percent.increase.fifty
r06-c02-s08|percent.discount.twenty
r06-c02-s09|percent.increase.ten
r06-c02-s10|percent.fraction-equivalence
r06-c03-s01|data.pictograph.total
r06-c03-s02|data.bar.difference
r06-c03-s03|data.table.total
r06-c03-s04|data.mean.two-values
r06-c03-s05|data.range
r06-c03-s06|data.table.missing-from-total
r06-c03-s07|data.weighted.total
r06-c03-s08|data.mode.difference-from-min
r06-c03-s09|data.median.even-count
r06-c03-s10|data.rate.projection
r07-c01-s01|review.r1.add-sub
r07-c01-s02|review.r1.mul-add
r07-c01-s03|review.r1.order
r07-c01-s04|review.r1.parentheses
r07-c01-s05|review.r2.arithmetic-pattern
r07-c01-s06|review.r2.repeat-unit
r07-c01-s07|review.r3.time-conversion
r07-c01-s08|review.r3.length-conversion
r07-c01-s09|review.r3.mass-conversion
r07-c01-s10|review.r1-r3.integrated
r07-c02-s01|review.r4.inverse
r07-c02-s02|review.r4.two-step-equation
r07-c02-s03|review.r4.sum-difference
r07-c02-s04|review.r5.perimeter
r07-c02-s05|review.r5.area
r07-c02-s06|review.r5.missing-side
r07-c02-s07|review.r5.angle
r07-c02-s08|review.r5.composite-area
r07-c02-s09|review.r5.grid-distance
r07-c02-s10|review.r4-r5.integrated
r07-c03-s01|review.r6.proportion
r07-c03-s02|review.r6.fraction
r07-c03-s03|review.r6.percent
r07-c03-s04|review.r6.mean
r07-c03-s05|review.r6.data-rate
r07-c03-s06|review.r3-r6.unit-ratio
r07-c03-s07|review.r5-r6.area-fraction
r07-c03-s08|review.r4-r6.partition
r07-c03-s09|review.r1.order-transfer
r07-c03-s10|review.all-regions.final
''';
