import 'dart:convert';

import 'package:flutter/services.dart';

class SentenceHintData {
  const SentenceHintData({
    required this.word,
    required this.description,
    required this.isHidden,
  });

  final String word;
  final String description;
  final bool isHidden;
}

class SentenceCodeLevel {
  const SentenceCodeLevel({
    required this.id,
    required this.sentence,
    required this.translation,
    required this.similarProverb,
    required this.hints,
  });

  final int id;
  final String sentence;
  final String translation;
  final String similarProverb;
  final List<SentenceHintData> hints;

  List<SentenceHintData> get visibleHints => hints.where((h) => !h.isHidden).toList(growable: false);

  SentenceHintData? get hiddenHint {
    for (final hint in hints) {
      if (hint.isHidden) return hint;
    }
    return null;
  }
}

class SentenceCodeRepository {
  SentenceCodeRepository._internal();
  static final SentenceCodeRepository instance = SentenceCodeRepository._internal();

  bool _loaded = false;
  List<SentenceCodeLevel> _levels = const [];

  int get levelCount => _levels.length;

  Future<void> preload() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/wordlists/sentence_code_levels.json');
      final decoded = jsonDecode(raw);
      final levelsRaw = decoded is Map<String, dynamic> ? decoded['levels'] : null;
      if (levelsRaw is! List) {
        _levels = const [];
        _loaded = true;
        return;
      }

      _levels = levelsRaw
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            final hintsRaw = map['hints'];
            final hints = hintsRaw is List
                ? hintsRaw
                    .whereType<Map>()
                    .map((hintItem) {
                      final h = Map<String, dynamic>.from(hintItem);
                      return SentenceHintData(
                        word: (h['word'] ?? '').toString().toUpperCase(),
                        description: (h['description'] ?? '').toString(),
                        isHidden: h['isHidden'] == true,
                      );
                    })
                    .toList(growable: false)
                : const <SentenceHintData>[];

            return SentenceCodeLevel(
              id: (map['id'] as num?)?.toInt() ?? 0,
              sentence: (map['sentence'] ?? '').toString(),
              translation: (map['translation'] ?? '').toString(),
              similarProverb: (map['similarProverb'] ?? '').toString(),
              hints: hints,
            );
          })
          .where((level) => level.id > 0 && level.sentence.trim().isNotEmpty)
          .toList(growable: false);
      _loaded = true;
    } catch (_) {
      _levels = const [];
      _loaded = true;
    }
  }

  SentenceCodeLevel getLevelForStage(int stage) {
    if (_levels.isEmpty) {
      return const SentenceCodeLevel(
        id: 1,
        sentence: 'LEARNING NEVER STOPS.',
        translation: '배움은 멈추지 않는다.',
        similarProverb: '',
        hints: [
          SentenceHintData(
            word: 'LEARN',
            description: 'To gain knowledge.',
            isHidden: false,
          ),
        ],
      );
    }
    final safeStage = stage <= 0 ? 1 : stage;
    final index = (safeStage - 1) % _levels.length;
    return _levels[index];
  }
}

