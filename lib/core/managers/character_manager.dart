class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.price,
    required this.quote,
    required this.hints,
  });

  final String id;
  final String name;
  final String imagePath;
  final int price;
  final String quote;
  final Map<String, String> hints;
}

class CharacterManager {
  static final CharacterManager _instance = CharacterManager._internal();
  factory CharacterManager() => _instance;
  CharacterManager._internal();

  static const List<String> _names = [
    'Alpha',
    'Bravo',
    'Charlie',
    'Delta',
    'Echo',
    'Foxtrot',
    'Golf',
    'Hotel',
    'India',
    'Juliett',
    'Kilo',
    'Lima',
    'Mike',
    'November',
    'Oscar',
    'Papa',
    'Quebec',
    'Romeo',
    'Sierra',
    'Tango',
    'Uniform',
    'Victor',
    'Whiskey',
    'Xray',
    'Yankee',
    'Zulu',
  ];

  static const List<String> _letters = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
  ];

  List<CharacterProfile> get characters {
    return List.generate(_names.length, (index) {
      final id = 'CHAR_${_letters[index].toUpperCase()}';
      return CharacterProfile(
        id: id,
        name: _names[index],
        imagePath: 'assets/images/characters/ic_char_${_letters[index]}.png',
        price: 50,
        quote: 'Keep learning one word at a time.',
        hints: {
          'wordle': 'Try letters with different vowels first.',
          'word_clue': 'Match the meaning and part of speech together.',
          'sentence_code': 'Reveal repeated letters to open multiple slots at once.',
          'anagram': 'Core words use every letter at least once.',
          'word_crash': 'Longer words are better for combos.',
        },
      );
    });
  }

  CharacterProfile getById(String id) {
    return characters.firstWhere(
      (item) => item.id == id,
      orElse: () => characters.first,
    );
  }
}
