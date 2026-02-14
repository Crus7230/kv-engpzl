import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class WordData {
  const WordData({
    required this.word,
    required this.meaning,
    required this.korMeaning,
    required this.pos,
    this.synonym = '',
    this.antonym = '',
  });

  final String word;
  final String meaning;
  final String korMeaning;
  final String pos;
  final String synonym;
  final String antonym;
}

class AnagramRoundData {
  const AnagramRoundData({
    required this.seedInfo,
    required this.coreWords,
    required this.generalWords,
  });

  final WordData seedInfo;
  String get seed => seedInfo.word;
  final Set<String> coreWords;
  final Set<String> generalWords;
}

class WordRepository {
  WordRepository._internal();
  static final WordRepository instance = WordRepository._internal();

  final Random _random = Random();
  static final RegExp _alphaOnly = RegExp(r'^[A-Z]+$');
  static final RegExp _hangul = RegExp(r'[가-힣]');
  static const Set<String> _allowedCluePos = {
    'Noun',
    'Verb',
    'Adjective',
    'Adverb',
  };

  // Fallback pools for test/offline startup before assets are available.
  static const List<String> _defaultWordle4Answers = [
    'BOOK',
    'TREE',
    'WIND',
    'MOON',
    'CODE',
    'NEWS',
    'QUIZ',
    'MATH',
    'NOTE',
    'CITY',
    'STAR',
    'RAIN',
    'TEAM',
    'TIME',
    'SHIP',
    'ROAD',
    'FOOD',
    'PLAN',
    'LIFE',
    'CARE',
  ];

  static const List<String> _defaultWordle5Answers = [
    'APPLE',
    'BRAVE',
    'SOLVE',
    'SHINE',
    'LEARN',
    'SMILE',
    'WATER',
    'WORLD',
    'SCORE',
    'STUDY',
    'MEDIA',
    'QUICK',
    'SMART',
    'CLEAR',
    'PLANT',
    'STORY',
    'STAGE',
    'TRAIN',
    'DREAM',
    'POWER',
    'EARTH',
    'CLOUD',
    'LIGHT',
    'GUIDE',
    'SHARE',
    'FOCUS',
    'DAILY',
    'EVENT',
    'TRUTH',
    'VALUE',
    'VOICE',
    'PHONE',
    'BRAIN',
    'YOUTH',
    'PEACE',
    'RIVER',
  ];

  static const List<WordData> _defaultClueWords = [
    WordData(word: 'MERCY', meaning: 'Compassion shown toward someone.', korMeaning: '자비', pos: 'Noun'),
    WordData(word: 'JOLLY', meaning: 'Cheerful and lively.', korMeaning: '명랑한', pos: 'Adjective'),
    WordData(word: 'THRIVE', meaning: 'To grow strongly and well.', korMeaning: '번영하다', pos: 'Verb'),
    WordData(word: 'KIND', meaning: 'Having a friendly nature.', korMeaning: '친절한', pos: 'Adjective'),
    WordData(word: 'CLARITY', meaning: 'The quality of being clear.', korMeaning: '명확함', pos: 'Noun'),
    WordData(word: 'IMPACT', meaning: 'A strong effect on something.', korMeaning: '영향', pos: 'Noun'),
    WordData(word: 'ACCESS', meaning: 'The right to use or enter.', korMeaning: '접근', pos: 'Noun'),
    WordData(word: 'POLICY', meaning: 'A plan of action by an organization.', korMeaning: '정책', pos: 'Noun'),
    WordData(word: 'GLOBAL', meaning: 'Relating to the whole world.', korMeaning: '세계적인', pos: 'Adjective'),
  ];

  static const List<AnagramRoundData> _defaultAnagramRounds = [
    AnagramRoundData(
      seedInfo: WordData(
        word: 'STREAM',
        meaning: 'A continuous flow of water or something similar.',
        korMeaning: 'A flowing line or current.',
        pos: 'Noun',
      ),
      coreWords: {'STREAM'},
      generalWords: {'TEAM', 'SEAT', 'TAME', 'RATE', 'EAST', 'MEAT', 'TEAR', 'SMART'},
    ),
    AnagramRoundData(
      seedInfo: WordData(
        word: 'SILENT',
        meaning: 'Not making or accompanied by any sound.',
        korMeaning: 'Without sound.',
        pos: 'Adjective',
      ),
      coreWords: {'SILENT', 'LISTEN'},
      generalWords: {'TILE', 'LENT', 'TINES', 'LINE', 'LIES', 'SENT', 'SITE'},
    ),
    AnagramRoundData(
      seedInfo: WordData(
        word: 'REACT',
        meaning: 'To act in response to something.',
        korMeaning: 'To respond.',
        pos: 'Verb',
      ),
      coreWords: {'REACT', 'CRATE', 'CATER'},
      generalWords: {'CARE', 'RACE', 'TEAR', 'RATE', 'CART', 'TRACE'},
    ),
  ];

  static const Set<String> _defaultCrashWords = {
    'CAT',
    'DOG',
    'SUN',
    'STAR',
    'WORD',
    'BLOCK',
    'STACK',
    'DROP',
    'POP',
    'GRID',
    'LEARN',
    'PLAY',
    'GAME',
    'TREE',
    'BOOK',
    'SMILE',
    'CRASH',
    'NOTE',
    'TILE',
    'FALL',
    'WAVE',
    'CORE',
    'QUIZ',
    'NEWS',
    'TRAIN',
    'STAGE',
    'STORY',
    'LIGHT',
    'SHARE',
  };

  static const Map<String, WordData> _wordleGlossary = {
    'BOOK': WordData(word: 'BOOK', meaning: 'A printed work of pages.', korMeaning: '책', pos: 'Noun'),
    'TREE': WordData(word: 'TREE', meaning: 'A woody perennial plant.', korMeaning: '나무', pos: 'Noun'),
    'WIND': WordData(word: 'WIND', meaning: 'Natural movement of air.', korMeaning: '바람', pos: 'Noun'),
    'MOON': WordData(word: 'MOON', meaning: "Earth's natural satellite.", korMeaning: '달', pos: 'Noun'),
    'CODE': WordData(word: 'CODE', meaning: 'Program instructions.', korMeaning: '코드', pos: 'Noun'),
    'APPLE': WordData(word: 'APPLE', meaning: 'A round fruit.', korMeaning: '사과', pos: 'Noun'),
    'BRAVE': WordData(word: 'BRAVE', meaning: 'Ready to face danger.', korMeaning: '용감한', pos: 'Adjective'),
    'SOLVE': WordData(word: 'SOLVE', meaning: 'Find an answer.', korMeaning: '해결하다', pos: 'Verb'),
    'SHINE': WordData(word: 'SHINE', meaning: 'Give out bright light.', korMeaning: '빛나다', pos: 'Verb'),
    'LEARN': WordData(word: 'LEARN', meaning: 'Gain knowledge.', korMeaning: '배우다', pos: 'Verb'),
    'SMILE': WordData(word: 'SMILE', meaning: 'Form a pleased expression.', korMeaning: '미소 짓다', pos: 'Verb'),
    'WATER': WordData(word: 'WATER', meaning: 'A transparent liquid.', korMeaning: '물', pos: 'Noun'),
  };

  List<String> _wordle4Answers = List<String>.from(_defaultWordle4Answers, growable: false);
  List<String> _wordle5Answers = List<String>.from(_defaultWordle5Answers, growable: false);
  Set<String> _wordle4Allowed = Set<String>.from(_defaultWordle4Answers);
  Set<String> _wordle5Allowed = Set<String>.from(_defaultWordle5Answers);
  Set<String> _crashWords = Set<String>.from(_defaultCrashWords);
  List<WordData> _clueWords = List<WordData>.from(_defaultClueWords, growable: false);
  List<AnagramRoundData> _anagramRounds = List<AnagramRoundData>.from(_defaultAnagramRounds, growable: false);

  bool _loadedFromAssets = false;
  Future<void>? _loadTask;

  bool get loadedFromAssets => _loadedFromAssets;

  Future<void> preload() {
    return _loadTask ??= _loadFromAssets();
  }

  Future<void> _loadFromAssets() async {
    try {
      final answers4 = await _loadWordList('assets/wordlists/wordle_answers_4.txt', fixedLength: 4);
      final answers5 = await _loadWordList('assets/wordlists/wordle_answers_5.txt', fixedLength: 5);
      final allowed4 = await _loadWordList('assets/wordlists/wordle_allowed_4.txt', fixedLength: 4);
      final allowed5 = await _loadWordList('assets/wordlists/wordle_allowed_5.txt', fixedLength: 5);
      final crash = await _loadWordList(
        'assets/wordlists/crash_words.txt',
        minLength: 3,
        maxLength: 7,
      );
      final clueWords = await _loadClueWordsJson('assets/wordlists/clue_words.json');

      if (answers4.isNotEmpty) {
        _wordle4Answers = answers4.toList(growable: false);
      }
      if (answers5.isNotEmpty) {
        _wordle5Answers = answers5.toList(growable: false);
      }
      if (allowed4.isNotEmpty) {
        _wordle4Allowed = allowed4..addAll(_wordle4Answers);
      }
      if (allowed5.isNotEmpty) {
        _wordle5Allowed = allowed5..addAll(_wordle5Answers);
      }
      if (crash.isNotEmpty) {
        _crashWords = crash;
      }
      if (clueWords.isNotEmpty) {
        _clueWords = clueWords.toList(growable: false);
      }

      final anagramRounds = await _loadAnagramRoundsJson('assets/wordlists/anagram_rounds.json');
      _anagramRounds = anagramRounds.toList(growable: false);
      if (_anagramRounds.isEmpty) {
        final fallbackSeeds = _clueWords.take(180).toList(growable: false);
        _anagramRounds = _buildAnagramRounds(fallbackSeeds);
      }
      if (_anagramRounds.isEmpty) {
        _anagramRounds = List<AnagramRoundData>.from(_defaultAnagramRounds, growable: false);
      }

      _loadedFromAssets = true;
    } catch (_) {
      final fallbackSeeds = _clueWords.take(180).toList(growable: false);
      _anagramRounds = _buildAnagramRounds(fallbackSeeds);
      if (_anagramRounds.isEmpty) {
        _anagramRounds = List<AnagramRoundData>.from(_defaultAnagramRounds, growable: false);
      }
    }
  }

  Future<Set<String>> _loadWordList(
    String assetPath, {
    int? fixedLength,
    int? minLength,
    int? maxLength,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final out = <String>{};
    final lines = raw.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final value = line.trim().toUpperCase();
      if (value.isEmpty || value.startsWith('#')) continue;
      if (!_alphaOnly.hasMatch(value)) continue;
      if (fixedLength != null && value.length != fixedLength) continue;
      if (minLength != null && value.length < minLength) continue;
      if (maxLength != null && value.length > maxLength) continue;
      out.add(value);
    }
    return out;
  }

  Future<List<WordData>> _loadClueWordsJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    final entries = decoded is Map<String, dynamic> ? decoded['entries'] : null;
    if (entries is! List) return const [];

    final out = <WordData>[];
    final seen = <String>{};
    for (final item in entries) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final word = (map['word'] as String? ?? '').trim().toUpperCase();
      if (word.isEmpty || !_alphaOnly.hasMatch(word)) continue;
      if (!seen.add(word)) continue;
      final meaning = (map['meaning'] as String? ?? '').trim();
      final pos = _normalizePos((map['pos'] as String? ?? '').trim());
      if (!_isDictionaryStyleMeaning(meaning)) continue;
      if (!_allowedCluePos.contains(pos)) continue;
      final korMeaning = _normalizeKorMeaning((map['korMeaning'] as String? ?? '').trim());
      out.add(
        WordData(
          word: word,
          meaning: meaning,
          korMeaning: korMeaning,
          pos: pos,
          synonym: (map['synonym'] as String? ?? '').trim(),
          antonym: (map['antonym'] as String? ?? '').trim(),
        ),
      );
    }
    return out;
  }

  String _normalizePos(String raw) {
    final lower = raw.toLowerCase();
    if (lower.startsWith('noun')) return 'Noun';
    if (lower.startsWith('verb')) return 'Verb';
    if (lower.startsWith('adjective')) return 'Adjective';
    if (lower.startsWith('adverb')) return 'Adverb';
    return 'Word';
  }

  bool _isDictionaryStyleMeaning(String meaning) {
    final text = meaning.trim();
    if (text.length < 16 || text.length > 160) return false;
    final lower = text.toLowerCase();
    if (lower.startsWith('used to ')) return false;
    if (lower.startsWith('used for ')) return false;
    if (lower.contains('in grammar')) return false;
    return true;
  }

  String _normalizeKorMeaning(String raw) {
    if (raw.isEmpty) return '의미 정보 준비중';
    if (raw.contains('�')) return '의미 정보 준비중';
    if (!_hangul.hasMatch(raw)) return '의미 정보 준비중';
    return raw;
  }

  Future<List<AnagramRoundData>> _loadAnagramRoundsJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    final entries = decoded is Map<String, dynamic> ? decoded['entries'] : null;
    if (entries is! List) return const [];

    final clueByWord = <String, WordData>{
      for (final item in _clueWords) item.word.toUpperCase(): item,
    };
    final out = <AnagramRoundData>[];
    final seenSeeds = <String>{};
    for (final item in entries) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final seed = (map['seed'] as String? ?? '').trim().toUpperCase();
      if (seed.isEmpty || !_alphaOnly.hasMatch(seed)) continue;
      if (!seenSeeds.add(seed)) continue;

      final coreWords = _parseWordSet(map['coreWords'], minLength: seed.length, maxLength: seed.length);
      final generalWords = _parseWordSet(map['generalWords'], minLength: 3, maxLength: seed.length - 1);
      if (coreWords.isEmpty || generalWords.length < 4) continue;

      final seedInfo = clueByWord[seed] ??
          WordData(
            word: seed,
            meaning: (map['meaning'] as String? ?? 'Common English word.').trim(),
            korMeaning: (map['korMeaning'] as String? ?? '기본 영어 단어').trim(),
            pos: (map['pos'] as String? ?? 'Word').trim(),
          );

      out.add(
        AnagramRoundData(
          seedInfo: seedInfo,
          coreWords: coreWords,
          generalWords: generalWords,
        ),
      );
    }
    return out;
  }

  Set<String> _parseWordSet(
    Object? raw, {
    int? minLength,
    int? maxLength,
  }) {
    if (raw is! List) return const <String>{};
    final out = <String>{};
    for (final item in raw) {
      if (item is! String) continue;
      final word = item.trim().toUpperCase();
      if (word.isEmpty || !_alphaOnly.hasMatch(word)) continue;
      if (minLength != null && word.length < minLength) continue;
      if (maxLength != null && word.length > maxLength) continue;
      out.add(word);
    }
    return out;
  }

  List<AnagramRoundData> _buildAnagramRounds(List<WordData> sources) {
    final dictionary = <String>{
      ..._wordle4Allowed,
      ..._wordle5Allowed,
      ..._crashWords,
      ...sources.map((e) => e.word.toUpperCase()),
    };
    final rounds = <AnagramRoundData>[];
    for (final item in sources) {
      final seed = item.word.toUpperCase();
      if (seed.length < 5 || seed.length > 7) continue;
      final seedCount = _charCount(seed);

      final core = <String>{seed};
      for (final candidate in dictionary) {
        if (candidate == seed || candidate.length != seed.length) continue;
        if (_isExactAnagram(candidate, seedCount)) {
          core.add(candidate);
          if (core.length >= 3) break;
        }
      }

      final general = <String>[];
      for (final candidate in dictionary) {
        if (candidate == seed) continue;
        if (candidate.length < 3 || candidate.length >= seed.length) continue;
        if (_canBuildFromSeed(candidate, seedCount)) {
          general.add(candidate);
        }
      }
      general.sort((a, b) {
        final len = a.length.compareTo(b.length);
        if (len != 0) return len;
        return a.compareTo(b);
      });
      final generalUnique = <String>{};
      for (final g in general) {
        generalUnique.add(g);
        if (generalUnique.length >= 24) break;
      }

      if (generalUnique.length >= 4) {
        rounds.add(
          AnagramRoundData(
            seedInfo: item,
            coreWords: core,
            generalWords: generalUnique,
          ),
        );
      }
    }
    return rounds;
  }

  Map<String, int> _charCount(String word) {
    final out = <String, int>{};
    for (final ch in word.split('')) {
      out[ch] = (out[ch] ?? 0) + 1;
    }
    return out;
  }

  bool _isExactAnagram(String word, Map<String, int> seedCount) {
    if (word.length != seedCount.values.fold<int>(0, (a, b) => a + b)) return false;
    final copy = Map<String, int>.from(seedCount);
    for (final ch in word.split('')) {
      final left = copy[ch] ?? 0;
      if (left == 0) return false;
      copy[ch] = left - 1;
    }
    return copy.values.every((v) => v == 0);
  }

  bool _canBuildFromSeed(String word, Map<String, int> seedCount) {
    final copy = Map<String, int>.from(seedCount);
    for (final ch in word.split('')) {
      final left = copy[ch] ?? 0;
      if (left == 0) return false;
      copy[ch] = left - 1;
    }
    return true;
  }

  Future<WordData> getWordleWordForStage(int stage, {int? preferredLength}) async {
    await preload();
    final selectedLength = preferredLength == 4 || preferredLength == 5
        ? preferredLength!
        : (_random.nextBool() ? 4 : 5);
    final source = selectedLength == 4 ? _wordle4Answers : _wordle5Answers;
    final chosen = source[_random.nextInt(source.length)];
    final glossary = _wordleGlossary[chosen];
    if (glossary != null) {
      return glossary;
    }
    return WordData(
      word: chosen,
      meaning: 'Common English word.',
      korMeaning: '기본 영어 단어',
      pos: 'Word',
    );
  }

  bool isValidWordleGuess(String guess) {
    final word = guess.trim().toUpperCase();
    if (!_alphaOnly.hasMatch(word)) return false;
    if (word.length == 4) {
      return _wordle4Allowed.contains(word);
    }
    if (word.length == 5) {
      return _wordle5Allowed.contains(word);
    }
    return false;
  }

  Set<String> getAllowedWordleGuesses(int length) {
    if (length == 4) return {..._wordle4Allowed};
    if (length == 5) return {..._wordle5Allowed};
    return const <String>{};
  }

  Map<String, int> getPoolStats() {
    return {
      'wordle4_answers': _wordle4Answers.length,
      'wordle4_allowed': _wordle4Allowed.length,
      'wordle5_answers': _wordle5Answers.length,
      'wordle5_allowed': _wordle5Allowed.length,
      'clue_words': _clueWords.length,
      'anagram_rounds': _anagramRounds.length,
      'crash_words': _crashWords.length,
    };
  }

  WordData getWordClueRound() {
    return _clueWords[_random.nextInt(_clueWords.length)];
  }

  AnagramRoundData getAnagramRound() {
    return _anagramRounds[_random.nextInt(_anagramRounds.length)];
  }

  bool isCrashWord(String word) {
    return _crashWords.contains(word.toUpperCase());
  }
}
