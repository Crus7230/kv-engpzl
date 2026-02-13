import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_state_manager.dart';

class GameSkin {
  const GameSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.backgroundPath,
    required this.primaryColor,
    required this.textColor,
  });

  final int id;
  final String name;
  final int price;
  final String backgroundPath;
  final Color primaryColor;
  final Color textColor;
}

class SkinManager extends ChangeNotifier {
  static const int _economyVersion = 2;
  int _currentIndex = 0;
  late SharedPreferences _prefs;
  final Set<int> _unlockedSkinIds = {1};

  final List<GameSkin> _skins = const [
    GameSkin(
      id: 1,
      name: '바다 친구들',
      price: 0,
      backgroundPath: 'assets/images/skins/bg_01.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 2,
      name: '딸기 요정',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_02.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
    GameSkin(
      id: 3,
      name: '숲 속 탐험',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_03.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 4,
      name: '바나나 타임',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_04.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
    GameSkin(
      id: 5,
      name: '구름 나라',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_05.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 6,
      name: '우주 토끼',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_06.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
    GameSkin(
      id: 7,
      name: '공룡 놀이터',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_07.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 8,
      name: '젤리 캔디',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_08.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
    GameSkin(
      id: 9,
      name: '공주 성',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_09.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 10,
      name: '레인보우 파티',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_10.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
    GameSkin(
      id: 11,
      name: '슈퍼 마리오#1',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_11.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 12,
      name: '슈퍼 마리오#2',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_12.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
    GameSkin(
      id: 13,
      name: '별의 커비',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_13.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 14,
      name: '커비와 친구들',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_14.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
    GameSkin(
      id: 15,
      name: '마인크래프트',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_15.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 16,
      name: '알파벳 로어',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_16.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
    GameSkin(
      id: 17,
      name: '쿠로미',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_17.png',
      primaryColor: Color(0xFF2455D6),
      textColor: Color(0xFF1E2430),
    ),
    GameSkin(
      id: 18,
      name: 'K-POP 데몬헌터스',
      price: 30,
      backgroundPath: 'assets/images/skins/bg_18.png',
      primaryColor: Color(0xFFF4B400),
      textColor: Colors.white,
    ),
  ];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final storedVersion = _prefs.getInt('skin_economy_version') ?? 0;
    if (storedVersion < _economyVersion) {
      _unlockedSkinIds
        ..clear()
        ..add(1);
      _currentIndex = 0;
      await _prefs.setStringList('unlocked_skin_ids', const ['1']);
      await _prefs.setInt('current_skin_index', _currentIndex);
      await _prefs.setInt('skin_economy_version', _economyVersion);
      return;
    }

    final rawUnlocked = _prefs.getStringList('unlocked_skin_ids') ?? const ['1'];
    _unlockedSkinIds
      ..clear()
      ..addAll(rawUnlocked.map(int.tryParse).whereType<int>());
    if (_unlockedSkinIds.isEmpty) {
      _unlockedSkinIds.add(1);
    }

    final storedIndex = _prefs.getInt('current_skin_index') ?? 0;
    final safeIndex = storedIndex.clamp(0, _skins.length - 1);
    _currentIndex = safeIndex;
    if (!isUnlocked(_skins[_currentIndex].id)) {
      _currentIndex = 0;
      await _prefs.setInt('current_skin_index', _currentIndex);
    }
  }

  Future<void> _saveUnlocked() async {
    await _prefs.setStringList(
      'unlocked_skin_ids',
      _unlockedSkinIds.map((id) => '$id').toList(),
    );
  }

  GameSkin get currentSkin => _skins[_currentIndex];
  List<GameSkin> get skins => _skins;
  bool isUnlocked(int skinId) => _unlockedSkinIds.contains(skinId);

  Future<void> nextSkin() async {
    _currentIndex = (_currentIndex + 1) % _skins.length;
    if (!isUnlocked(_skins[_currentIndex].id)) {
      _currentIndex = 0;
    }
    await _prefs.setInt('current_skin_index', _currentIndex);
    notifyListeners();
  }

  Future<bool> setSkinByIndex(int index) async {
    if (index < 0 || index >= _skins.length) {
      return false;
    }
    if (!isUnlocked(_skins[index].id)) {
      return false;
    }
    _currentIndex = index;
    await _prefs.setInt('current_skin_index', _currentIndex);
    notifyListeners();
    return true;
  }

  Future<bool> purchaseAndEquipByIndex(int index, GameStateManager gameState) async {
    if (index < 0 || index >= _skins.length) return false;
    final skin = _skins[index];
    if (!isUnlocked(skin.id)) {
      final paid = await gameState.spendStars(skin.price);
      if (!paid) return false;
      _unlockedSkinIds.add(skin.id);
      await _saveUnlocked();
    }
    _currentIndex = index;
    await _prefs.setInt('current_skin_index', _currentIndex);
    notifyListeners();
    return true;
  }
}
