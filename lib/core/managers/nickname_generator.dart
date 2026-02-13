import 'dart:math';

class NicknameGenerator {
  static final List<String> _adjectives = [
    'Brave',
    'Lucky',
    'Happy',
    'Swift',
    'Calm',
    'Bright',
    'Bold',
    'Gentle',
    'Clever',
    'Golden',
  ];

  static final List<String> _nouns = [
    'Lion',
    'Falcon',
    'Wizard',
    'Comet',
    'Panda',
    'Knight',
    'Voyager',
    'Pixel',
    'Ranger',
    'Builder',
  ];

  static String generate() {
    final random = Random();
    final adj = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    final num = random.nextInt(1000);
    return '$adj $noun $num';
  }
}
