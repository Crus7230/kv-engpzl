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
    this.themeGroup = 'Word',
    this.themeCategory = 'General',
    this.difficulty = 3,
    this.isEssential = false,
    this.frequencyZipf = 0,
  });

  final String word;
  final String meaning;
  final String korMeaning;
  final String pos;
  final String synonym;
  final String antonym;
  final String themeGroup;
  final String themeCategory;
  final int difficulty;
  final bool isEssential;
  final double frequencyZipf;
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
  static final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3]');
  static final RegExp _vowel = RegExp(r'[AEIOUY]');
  static const Set<String> _crashWordBlocklist = {
    'ANAL',
    'ANUS',
    'ARSE',
    'ASS',
    'ASSHOLE',
    'BASTARD',
    'BITCH',
    'BITCHY',
    'BLOWJOB',
    'BOOB',
    'BOOBS',
    'COCK',
    'CUNT',
    'DICK',
    'FAG',
    'FAGGOT',
    'FUCK',
    'FUCKED',
    'FUCKING',
    'NIGGER',
    'PENIS',
    'PORN',
    'PUSSY',
    'RAPE',
    'RAPED',
    'RAPES',
    'SHIT',
    'SLUT',
    'WHORE',
  };
  static const Set<String> _allowedCluePos = {
    'Noun',
    'Verb',
    'Adjective',
    'Adverb',
    'Word',
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
    WordData(
      word: 'MERCY',
      meaning: 'Compassion shown toward someone.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    WordData(
      word: 'JOLLY',
      meaning: 'Cheerful and lively.',
      korMeaning: 'Korean meaning pending',
      pos: 'Adjective',
    ),
    WordData(
      word: 'THRIVE',
      meaning: 'To grow strongly and well.',
      korMeaning: 'Korean meaning pending',
      pos: 'Verb',
    ),
    WordData(
      word: 'KIND',
      meaning: 'Having a friendly nature.',
      korMeaning: 'Korean meaning pending',
      pos: 'Adjective',
    ),
    WordData(
      word: 'CLARITY',
      meaning: 'The quality of being clear.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    WordData(
      word: 'IMPACT',
      meaning: 'A strong effect on something.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    WordData(
      word: 'ACCESS',
      meaning: 'The right to use or enter.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    WordData(
      word: 'POLICY',
      meaning: 'A plan of action by an organization.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    WordData(
      word: 'GLOBAL',
      meaning: 'Relating to the whole world.',
      korMeaning: 'Korean meaning pending',
      pos: 'Adjective',
    ),
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
    'BOOK': WordData(
      word: 'BOOK',
      meaning: 'A printed work of pages.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    'TREE': WordData(
      word: 'TREE',
      meaning: 'A woody perennial plant.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    'WIND': WordData(
      word: 'WIND',
      meaning: 'Natural movement of air.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    'MOON': WordData(
      word: 'MOON',
      meaning: "Earth's natural satellite.",
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    'CODE': WordData(
      word: 'CODE',
      meaning: 'Program instructions.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    'APPLE': WordData(
      word: 'APPLE',
      meaning: 'A round fruit.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
    'BRAVE': WordData(
      word: 'BRAVE',
      meaning: 'Ready to face danger.',
      korMeaning: 'Korean meaning pending',
      pos: 'Adjective',
    ),
    'SOLVE': WordData(
      word: 'SOLVE',
      meaning: 'Find an answer.',
      korMeaning: 'Korean meaning pending',
      pos: 'Verb',
    ),
    'SHINE': WordData(
      word: 'SHINE',
      meaning: 'Give out bright light.',
      korMeaning: 'Korean meaning pending',
      pos: 'Verb',
    ),
    'LEARN': WordData(
      word: 'LEARN',
      meaning: 'Gain knowledge.',
      korMeaning: 'Korean meaning pending',
      pos: 'Verb',
    ),
    'SMILE': WordData(
      word: 'SMILE',
      meaning: 'Form a pleased expression.',
      korMeaning: 'Korean meaning pending',
      pos: 'Verb',
    ),
    'WATER': WordData(
      word: 'WATER',
      meaning: 'A transparent liquid.',
      korMeaning: 'Korean meaning pending',
      pos: 'Noun',
    ),
  };

  List<String> _wordle4Answers = List<String>.from(_defaultWordle4Answers, growable: false);
  List<String> _wordle5Answers = List<String>.from(_defaultWordle5Answers, growable: false);
  Set<String> _wordle4Allowed = Set<String>.from(_defaultWordle4Answers);
  Set<String> _wordle5Allowed = Set<String>.from(_defaultWordle5Answers);
  Set<String> _crashWords = Set<String>.from(_defaultCrashWords);
  Set<String> _playableCrashWords = _buildPlayableCrashWords(_defaultCrashWords);
  List<WordData> _clueWords = List<WordData>.from(_defaultClueWords, growable: false);
  List<AnagramRoundData> _anagramRounds = List<AnagramRoundData>.from(_defaultAnagramRounds, growable: false);
  List<WordData> _localDictionaryWords = List<WordData>.from(_defaultClueWords, growable: false);
  List<AnagramRoundData> _playableAnagramRounds = List<AnagramRoundData>.from(_defaultAnagramRounds, growable: false);
  List<WordData> _wordle4AnswerEntries = List<WordData>.empty(growable: false);
  List<WordData> _wordle5AnswerEntries = List<WordData>.empty(growable: false);
  Set<String> _anagramLexicon = const <String>{};
  Set<String> _validWords = const <String>{};
  Map<String, WordData> _dictionaryByWord = {};
  final Map<String, WordData> _generatedDictionaryByWord = <String, WordData>{};

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
      final localDictionary = await _loadLocalDictionaryJson('assets/wordlists/local_dictionary.json');
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
      if (localDictionary.isNotEmpty) {
        _localDictionaryWords = localDictionary.toList(growable: false);
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
      _buildPlayableAnagramRounds();
      _rebuildDictionary();
      _rebuildPlayableCrashWords();
      _buildWordleAnswerEntries();
      _rebuildAnagramLexicon();
      _loadedFromAssets = true;
    } catch (_) {
      final fallbackSeeds = _clueWords.take(180).toList(growable: false);
      _anagramRounds = _buildAnagramRounds(fallbackSeeds);
      if (_anagramRounds.isEmpty) {
        _anagramRounds = List<AnagramRoundData>.from(_defaultAnagramRounds, growable: false);
      }
      _localDictionaryWords = List<WordData>.from(_defaultClueWords, growable: false);
      _buildPlayableAnagramRounds();
      _rebuildDictionary();
      _rebuildPlayableCrashWords();
      _buildWordleAnswerEntries();
      _rebuildAnagramLexicon();
    }
  }

  void _rebuildDictionary() {
    final map = <String, WordData>{};
    for (final entry in _localDictionaryWords) {
      map[entry.word.toUpperCase()] = entry;
    }
    for (final entry in _clueWords) {
      map.putIfAbsent(entry.word.toUpperCase(), () => entry);
    }
    for (final entry in _wordleGlossary.values) {
      map[entry.word.toUpperCase()] = entry;
    }
    for (final round in _anagramRounds) {
      final seed = round.seedInfo;
      map[seed.word.toUpperCase()] = seed;
    }
    _dictionaryByWord = map;
  }

  void _rebuildPlayableCrashWords() {
    // Prefer the curated crash source list directly so newly added safe words
    // become playable without being blocked by dictionary intersection filters.
    final direct = _buildPlayableCrashWords(_crashWords);
    if (direct.isNotEmpty) {
      _playableCrashWords = direct;
      return;
    }

    final fallbackLexicon = <String>{
      ..._validWords,
      ..._dictionaryByWord.keys,
    };
    final fallback = _buildPlayableCrashWords(
      _crashWords,
      curatedLexicon: fallbackLexicon,
    );
    if (fallback.isNotEmpty) {
      _playableCrashWords = fallback;
      return;
    }
    _playableCrashWords = _buildPlayableCrashWords(_defaultCrashWords);
  }

  void _buildPlayableAnagramRounds() {
    final byWord = <String, WordData>{
      for (final item in _localDictionaryWords) item.word.toUpperCase(): item,
    };
    final filtered = <AnagramRoundData>[];
    for (final round in _anagramRounds) {
      final seed = round.seed.toUpperCase();
      final seedInfo = byWord[seed];
      if (seedInfo == null) continue;
      filtered.add(
        AnagramRoundData(
          seedInfo: seedInfo,
          coreWords: round.coreWords,
          generalWords: round.generalWords,
        ),
      );
    }
    if (filtered.isNotEmpty) {
      _playableAnagramRounds = filtered;
      return;
    }

    final generated = _buildAnagramRounds(_localDictionaryWords);
    if (generated.isNotEmpty) {
      _playableAnagramRounds = generated;
    } else {
      _playableAnagramRounds = List<AnagramRoundData>.from(_defaultAnagramRounds, growable: false);
    }
  }

  void _buildWordleAnswerEntries() {
    _wordle4AnswerEntries = _buildAnswerEntriesForLength(4);
    _wordle5AnswerEntries = _buildAnswerEntriesForLength(5);
  }


  void _rebuildAnagramLexicon() {
    final set = <String>{
      ..._wordle4Allowed,
      ..._wordle5Allowed,
      ..._playableCrashWords,
      ..._validWords,
      ..._dictionaryByWord.keys,
    };
    for (final round in _playableAnagramRounds) {
      set.addAll(round.coreWords);
      set.addAll(round.generalWords);
    }
    _anagramLexicon = set;
  }

  List<WordData> _buildAnswerEntriesForLength(int length) {
    final source = length == 4 ? _wordle4Answers : _wordle5Answers;
    final out = <WordData>[];
    for (final word in source) {
      final info = _dictionaryByWord[word];
      if (info != null) {
        out.add(info);
        continue;
      }
      out.add(
        WordData(
          word: word,
          meaning: 'Common English word.',
          korMeaning: 'Korean meaning pending',
          pos: 'Word',
          themeGroup: 'Word',
          themeCategory: 'General',
          difficulty: length == 4 ? 2 : 3,
        ),
      );
    }
    return out;
  }

  int getWaveDifficultyLevel(int stage) {
    final s = stage < 1 ? 1 : stage;
    final baseline = 1 + ((s - 1) ~/ 6);
    const wave = [0, 1, 2, 1, 0, -1, 1, 2];
    final value = baseline + wave[(s - 1) % wave.length];
    return value.clamp(1, 6);
  }

  T _pickByDifficulty<T>({
    required List<T> source,
    required int stageDifficulty,
    required int Function(T item) difficultyOf,
  }) {
    if (source.isEmpty) {
      throw StateError('Cannot pick from empty source');
    }
    final sorted = List<T>.from(source)
      ..sort((a, b) {
        final da = (difficultyOf(a) - stageDifficulty).abs();
        final db = (difficultyOf(b) - stageDifficulty).abs();
        if (da != db) return da.compareTo(db);
        return _random.nextInt(3) - 1;
      });
    final window = sorted.take(sorted.length < 14 ? sorted.length : 14).toList(growable: false);
    return window[_random.nextInt(window.length)];
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
      final pos = _normalizePos((map['pos'] as String? ?? '').trim());
      final meaning = _normalizeMeaning(
        (map['meaning'] as String? ?? '').trim(),
        word: word,
        pos: pos,
      );
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
          themeGroup: pos,
          themeCategory: 'General',
          difficulty: word.length <= 4 ? 2 : (word.length <= 6 ? 3 : 4),
        ),
      );
    }
    return out;
  }

  Future<List<WordData>> _loadLocalDictionaryJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final validWords = decoded['validWords'];
      if (validWords is List) {
        _validWords = validWords
            .whereType<String>()
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty && _alphaOnly.hasMatch(e))
            .toSet();
      }
    }
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
      final pos = _normalizePos((map['pos'] as String? ?? '').trim());
      final definition = (map['definition'] as String? ?? '').trim();
      if (!_isDictionaryStyleMeaning(definition)) continue;
      final korMeaning = _normalizeKorMeaning((map['korDefinition'] as String? ?? '').trim());
      final synonyms = map['synonyms'];
      final antonyms = map['antonyms'];
      final synonymText = synonyms is List ? synonyms.whereType<String>().join(', ') : '';
      final antonymText = antonyms is List ? antonyms.whereType<String>().join(', ') : '';
      out.add(
        WordData(
          word: word,
          meaning: definition,
          korMeaning: korMeaning,
          pos: pos,
          synonym: synonymText,
          antonym: antonymText,
          themeGroup: (map['themeGroup'] as String? ?? pos).trim(),
          themeCategory: (map['themeCategory'] as String? ?? 'General').trim(),
          difficulty: ((map['difficulty'] as num?)?.toInt() ?? 3).clamp(1, 6),
          isEssential: (map['isEssential'] as bool?) ?? false,
          frequencyZipf: ((map['frequencyZipf'] as num?)?.toDouble() ?? 0),
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
    if (text.length < 10 || text.length > 220) return false;
    final lower = text.toLowerCase();
    if (lower.contains('in grammar')) return false;
    return true;
  }

  bool _isTemplateMeaning(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('a commonly used english word with')) return true;
    if (lower.contains('starting with') && lower.contains('ending with')) return true;
    return false;
  }

  String _normalizeMeaning(
    String raw, {
    required String word,
    required String pos,
  }) {
    final text = raw.trim();
    if (text.isNotEmpty && !_isTemplateMeaning(text)) {
      return text;
    }
    switch (pos) {
      case 'Verb':
        return 'To perform an action related to "$word" in everyday English usage.';
      case 'Adjective':
        return 'Describing a quality associated with "$word" in common usage.';
      case 'Adverb':
        return 'Used to modify an action or state in a way related to "$word".';
      case 'Noun':
        return 'A commonly recognized English noun represented by "$word".';
      default:
        return 'A commonly used English word represented by "$word".';
    }
  }

  static bool _isPlayableCrashWord(String word) {
    if (!_alphaOnly.hasMatch(word)) return false;
    if (word.length < 3 || word.length > 7) return false;
    final uniqueChars = word.split('').toSet().length;
    if (uniqueChars < 2) return false;
    final hasVowel = _vowel.hasMatch(word);
    return hasVowel;
  }

  static bool _isNoVowelCrashWordCandidate(String word) {
    if (!_alphaOnly.hasMatch(word)) return false;
    if (word.length < 3 || word.length > 7) return false;
    if (_vowel.hasMatch(word)) return false;
    final uniqueChars = word.split('').toSet().length;
    if (uniqueChars < 2) return false;
    if (!RegExp(r'[RSTLN]').hasMatch(word)) return false;
    if (RegExp(r'(.)\1\1').hasMatch(word)) return false;
    return true;
  }

  static bool _isBlockedCrashWord(String word) {
    return _crashWordBlocklist.contains(word);
  }

  static bool _looksLikeSafeCrashWord(String word) {
    if (_isBlockedCrashWord(word)) return false;
    if (!_alphaOnly.hasMatch(word)) return false;
    if (word.length < 3 || word.length > 7) return false;
    if (RegExp(r'(.)\1\1').hasMatch(word)) return false;
    if (word.length == 3 && !_vowel.hasMatch(word)) return false;
    return true;
  }

  static Set<String> _buildPlayableCrashWords(
    Set<String> source, {
    Set<String>? curatedLexicon,
  }) {
    final base = <String>{};
    final extraNoVowel = <String>[];
    final useLexiconFilter = curatedLexicon != null && curatedLexicon.isNotEmpty;
    final sorted = source.toList(growable: false)..sort();
    for (final word in sorted) {
      if (!_looksLikeSafeCrashWord(word)) continue;
      if (useLexiconFilter && !curatedLexicon.contains(word)) continue;
      if (_isPlayableCrashWord(word)) {
        base.add(word);
        continue;
      }
      if (_isNoVowelCrashWordCandidate(word)) {
        extraNoVowel.add(word);
      }
    }
    const bonusLimit = 220;
    for (int i = 0; i < extraNoVowel.length && i < bonusLimit; i++) {
      base.add(extraNoVowel[i]);
    }
    return base;
  }

  String _normalizeKorMeaning(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (text.contains('\uFFFD')) return '';
    if (!_hangul.hasMatch(text)) return '';
    return text;
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

      final dictionarySeed = clueByWord[seed];
      late final WordData seedInfo;
      if (dictionarySeed != null) {
        seedInfo = dictionarySeed;
      } else {
        final fallbackPos = _normalizePos((map['pos'] as String? ?? 'Word').trim());
        final fallbackMeaning = _normalizeMeaning(
          (map['meaning'] as String? ?? '').trim(),
          word: seed,
          pos: fallbackPos,
        );
        if (!_isDictionaryStyleMeaning(fallbackMeaning)) continue;
        seedInfo = WordData(
          word: seed,
          meaning: fallbackMeaning,
          korMeaning: (map['korMeaning'] as String? ?? 'Korean meaning pending').trim(),
          pos: fallbackPos,
        );
      }

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
        : (getWaveDifficultyLevel(stage) <= 2 ? 4 : 5);
    final source = selectedLength == 4 ? _wordle4AnswerEntries : _wordle5AnswerEntries;
    if (source.isNotEmpty) {
      return _pickByDifficulty<WordData>(
        source: source,
        stageDifficulty: getWaveDifficultyLevel(stage),
        difficultyOf: (item) => item.difficulty,
      );
    }
    final fallback = selectedLength == 4 ? _defaultWordle4Answers : _defaultWordle5Answers;
    final chosen = fallback[_random.nextInt(fallback.length)];
    return WordData(
      word: chosen,
      meaning: 'Common English word.',
      korMeaning: 'Korean meaning pending',
      pos: 'Word',
      difficulty: selectedLength == 4 ? 2 : 3,
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
    return getWordClueRoundForStage(1);
  }

  WordData getWordClueRoundForStage(int stage) {
    final source = _localDictionaryWords.isNotEmpty ? _localDictionaryWords : _clueWords;
    if (source.isEmpty) {
      return _defaultClueWords[_random.nextInt(_defaultClueWords.length)];
    }
    return _pickByDifficulty<WordData>(
      source: source,
      stageDifficulty: getWaveDifficultyLevel(stage),
      difficultyOf: (item) => item.difficulty,
    );
  }

  AnagramRoundData getAnagramRound() {
    return getAnagramRoundForStage(1);
  }

  AnagramRoundData getAnagramRoundForStage(int stage) {
    final source = _playableAnagramRounds.isNotEmpty ? _playableAnagramRounds : _anagramRounds;
    if (source.isEmpty) {
      return _defaultAnagramRounds[_random.nextInt(_defaultAnagramRounds.length)];
    }
    return _pickByDifficulty<AnagramRoundData>(
      source: source,
      stageDifficulty: getWaveDifficultyLevel(stage),
      difficultyOf: (item) => item.seedInfo.difficulty,
    );
  }

  WordData? getDictionaryEntry(String word) {
    final normalized = word.trim().toUpperCase();
    if (normalized.isEmpty || !_alphaOnly.hasMatch(normalized)) return null;
    final direct = _dictionaryByWord[normalized];
    if (direct != null) return direct;
    if (!_validWords.contains(normalized) && !_playableCrashWords.contains(normalized)) {
      return null;
    }
    return _generatedDictionaryByWord.putIfAbsent(
      normalized,
      () => _buildGeneratedDictionaryEntry(normalized),
    );
  }

  bool hasKoreanMeaning(String text) {
    final value = text.trim();
    if (value.isEmpty) return false;
    if (value.toLowerCase().contains('korean meaning pending')) return false;
    return _hangul.hasMatch(value);
  }

  WordData _buildGeneratedDictionaryEntry(String word) {
    final pos = _inferPos(word);
    return WordData(
      word: word,
      meaning: _buildFallbackMeaning(word, pos),
      korMeaning: 'Korean meaning pending',
      pos: pos,
      themeGroup: pos,
      themeCategory: 'General',
      difficulty: _estimateDifficultyFromLength(word.length),
      frequencyZipf: 0,
    );
  }

  static int _estimateDifficultyFromLength(int length) {
    if (length <= 4) return 2;
    if (length <= 6) return 3;
    return 4;
  }

  String _inferPos(String word) {
    if (word.endsWith('LY')) return 'Adverb';
    if (word.endsWith('ING') || word.endsWith('ED') || word.endsWith('EN')) return 'Verb';
    if (word.endsWith('IZE') || word.endsWith('ISE') || word.endsWith('FY')) return 'Verb';
    if (word.endsWith('OUS') ||
        word.endsWith('FUL') ||
        word.endsWith('ABLE') ||
        word.endsWith('IBLE') ||
        word.endsWith('AL') ||
        word.endsWith('IVE') ||
        word.endsWith('IC') ||
        word.endsWith('LESS') ||
        word.endsWith('ISH') ||
        word.endsWith('Y')) {
      return 'Adjective';
    }
    if (word.endsWith('TION') ||
        word.endsWith('SION') ||
        word.endsWith('MENT') ||
        word.endsWith('NESS') ||
        word.endsWith('ITY') ||
        word.endsWith('SHIP') ||
        word.endsWith('AGE') ||
        word.endsWith('ER') ||
        word.endsWith('OR')) {
      return 'Noun';
    }
    return 'Word';
  }

  String _buildFallbackMeaning(String word, String pos) {
    switch (pos) {
      case 'Verb':
        return 'To perform an action represented by "$word" in common English usage.';
      case 'Adjective':
        return 'Describing a quality related to "$word" in common English usage.';
      case 'Adverb':
        return 'Used to modify an action or state in a way related to "$word".';
      case 'Noun':
        return 'A noun used in English, represented by "$word".';
      default:
        return 'A commonly used English word represented by "$word".';
    }
  }

  bool isValidAnagramWordForSeed({
    required String seed,
    required String candidate,
  }) {
    final seedWord = seed.trim().toUpperCase();
    final word = candidate.trim().toUpperCase();
    if (seedWord.isEmpty || word.isEmpty) return false;
    if (!_alphaOnly.hasMatch(seedWord) || !_alphaOnly.hasMatch(word)) return false;
    if (word.length < 3 || word.length > seedWord.length) return false;
    if (!_anagramLexicon.contains(word)) return false;
    return _canBuildFromSeed(word, _charCount(seedWord));
  }


  bool isCrashWord(String word) {
    return _playableCrashWords.contains(word.toUpperCase());
  }

  List<String> getCrashWords({
    int minLength = 3,
    int maxLength = 7,
  }) {
    final words = _playableCrashWords
        .where((w) => w.length >= minLength && w.length <= maxLength)
        .toList(growable: false);
    return words;
  }

  String? findCrashWordByPattern(
    String pattern, {
    String wildcard = '*',
    bool requireUnique = false,
  }) {
    final normalized = pattern.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final wildcardCount = wildcard.isEmpty ? 0 : wildcard.allMatches(normalized).length;
    final lettersOnly = normalized.replaceAll(wildcard, '');
    if (lettersOnly.isEmpty || !_alphaOnly.hasMatch(lettersOnly)) return null;
    if (wildcardCount > 2) return null;
    final matches = <String>[];
    for (final word in _playableCrashWords) {
      if (word.length != normalized.length) continue;
      var match = true;
      for (int i = 0; i < word.length; i++) {
        final ch = normalized[i];
        if (ch == wildcard) continue;
        if (word[i] != ch) {
          match = false;
          break;
        }
      }
      if (match) {
        matches.add(word);
      }
    }
    if (matches.isEmpty) return null;
    if (requireUnique && matches.length > 1) return null;
    if (matches.length == 1) return matches.first;
    matches.sort((a, b) {
      final scoreCompare = _scoreCrashWord(b).compareTo(_scoreCrashWord(a));
      if (scoreCompare != 0) return scoreCompare;
      return a.compareTo(b);
    });
    return matches.first;
  }

  double _scoreCrashWord(String word) {
    final entry = getDictionaryEntry(word);
    if (entry != null) {
      final koreanBonus = hasKoreanMeaning(entry.korMeaning) ? 0.5 : 0.0;
      return 30 + (entry.frequencyZipf * 5.0) - (entry.difficulty * 1.5) + koreanBonus;
    }
    var score = 0.0;
    if (_validWords.contains(word)) score += 12;
    if (_vowel.hasMatch(word)) score += 2;
    score += word.length * 0.15;
    return score;
  }
}
