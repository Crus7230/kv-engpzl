import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/auth_service.dart';
import '../../core/managers/character_manager.dart';
import '../../core/managers/friend_service.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/ranking_service.dart';
import '../../core/managers/settings_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/sound_manager.dart';
import '../../core/managers/user_profile_service.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService.instance;
  final FriendService _friends = FriendService();
  final RankingService _ranking = RankingService();
  static const List<_GameDef> _gameDefs = [
    _GameDef(
      id: 'wordle',
      route: '/wordle',
      title: 'WORDLE',
      subtitle: 'Wave difficulty, 6 tries, keyboard feedback',
      guide: 'Guess the hidden word in six attempts and read instant letter feedback.',
      icon: Icons.grid_view_rounded,
      color: Color(0xFF37B24D),
    ),
    _GameDef(
      id: 'word_clue',
      route: '/word-clue',
      title: 'WORD CLUE',
      subtitle: 'Definition master with touch letter tiles',
      guide: 'Use definitions to complete each vocabulary word with tile taps.',
      icon: Icons.quiz_rounded,
      color: Color(0xFFF08C00),
    ),
    _GameDef(
      id: 'anagram',
      route: '/anagram',
      title: 'ANAGRAM',
      subtitle: 'Core word clear + general word bonus',
      guide: 'Build words from a seed string to clear core targets and collect bonuses.',
      icon: Icons.shuffle_rounded,
      color: Color(0xFF7B2CBF),
    ),
    _GameDef(
      id: 'word_crash',
      route: '/word-crash',
      title: 'WORD CRASH',
      subtitle: 'Swipe, pop, gravity, combo',
      guide: 'Link adjacent letters, pop valid words, and chain combos with bomb tiles.',
      icon: Icons.auto_awesome_motion_rounded,
      color: Color(0xFF1C7ED6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    final gameState = context.watch<GameStateManager>();
    final character = CharacterManager().getById(gameState.selectedCharacterId);
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height >= size.width;
    final sidebarWidth = (size.width * 0.16).clamp(72.0, 108.0);
    final compactSidebar = size.shortestSide < 370;
    final crossAxisCount = size.width >= 1200 ? 3 : (size.width >= 760 ? 2 : 1);
    final cardRatio = size.width < 390 ? 1.95 : (isPortrait ? 2.45 : 2.2);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(skin.backgroundPath, fit: BoxFit.cover)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.78),
                    Colors.white.withValues(alpha: 0.88),
                    const Color(0xFFEFF4FF).withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                _buildSideBar(context, width: sidebarWidth, compact: compactSidebar),
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(character, gameState),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 4, 18, 2),
                        child: Row(
                          children: [
                            Text(
                              'Choose Your Game',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: isPortrait ? 1 : crossAxisCount,
                          padding: const EdgeInsets.all(16),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: cardRatio,
                          children: _gameDefs
                              .map(
                                (g) => _GameCard(
                                  title: g.title,
                                  subtitle: g.subtitle,
                                  icon: g.icon,
                                  color: g.color,
                                  bestStage: gameState.getBestStage(g.id),
                                  playCount: gameState.getPlayCount(g.id),
                                  onTap: () async {
                                    await gameState.increasePlayCount(g.id);
                                    if (!context.mounted) return;
                                    context.push(g.route);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBar(
    BuildContext context, {
    required double width,
    required bool compact,
  }) {
    return Container(
      width: width,
      margin: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _sideButton(icon: Icons.pets_rounded, label: 'Chars', compact: compact, onTap: () => _openCharacterShop(context)),
          _sideButton(icon: Icons.wallpaper_rounded, label: 'Skins', compact: compact, onTap: () => _openSkinPicker(context)),
          _sideButton(icon: Icons.help_outline_rounded, label: 'Guide', compact: compact, onTap: () => _openGameGuideSheet(context)),
          _sideButton(icon: Icons.group_rounded, label: 'Friends', compact: compact, onTap: () => _openFriendsSheet(context)),
          _sideButton(icon: Icons.emoji_events_rounded, label: 'Rank', compact: compact, onTap: () => _openRankingSheet(context)),
          _sideButton(icon: Icons.settings_rounded, label: 'Settings', compact: compact, onTap: () => _openSettingsSheet(context)),
        ],
      ),
    );
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    required bool compact,
    required VoidCallback onTap,
  }) {
    final iconSize = compact ? 20.0 : 22.0;
    final circleSize = compact ? 38.0 : 42.0;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: AppColors.primary, size: iconSize),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CharacterProfile character, GameStateManager gameState) {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundImage: AssetImage(character.imagePath)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, ${character.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(
                  user == null || user.isAnonymous ? 'Guest Mode' : (user.displayName ?? 'Signed In'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _statChip(icon: Icons.favorite, color: AppColors.error, text: '${gameState.hearts}'),
          const SizedBox(width: 8),
          _statChip(icon: Icons.star, color: AppColors.secondary, text: '${gameState.stars}'),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sheetHeader(String title) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _sheetCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  void _openCharacterShop(BuildContext context) {
    final gameState = context.read<GameStateManager>();
    final all = CharacterManager().characters;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.74,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text('Character Collection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Stars: ${gameState.stars}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('All characters cost 50 stars', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: all.length,
                    itemBuilder: (context, index) {
                      final item = all[index];
                      final owned = gameState.unlockedCharacters.contains(item.id);
                      final selected = item.id == gameState.selectedCharacterId;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFE7F0FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300, width: selected ? 2 : 1),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(radius: 24, backgroundImage: AssetImage(item.imagePath)),
                            const SizedBox(height: 6),
                            Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (!owned)
                              ElevatedButton(
                                onPressed: () async {
                                  final success = await gameState.unlockCharacter(item.id, 50);
                                  setSheetState(() {});
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(success ? '${item.name} unlocked.' : 'Not enough stars.')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(30), textStyle: const TextStyle(fontSize: 11)),
                                child: const Text('50 stars'),
                              )
                            else
                              OutlinedButton(
                                onPressed: () async {
                                  await gameState.equipCharacter(item.id);
                                  setSheetState(() {});
                                },
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(30), textStyle: const TextStyle(fontSize: 11)),
                                child: Text(selected ? 'Equipped' : 'Equip'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openSkinPicker(BuildContext context) {
    final skinManager = context.read<SkinManager>();
    final gameState = context.read<GameStateManager>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentId = skinManager.currentSkin.id;
          final width = MediaQuery.of(context).size.width;
          final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text('Choose Skin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Stars: ${gameState.stars}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: skinManager.skins.length,
                    itemBuilder: (context, index) {
                      final skin = skinManager.skins[index];
                      final selected = skin.id == currentId;
                      final owned = skinManager.isUnlocked(skin.id);
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppColors.primary : Colors.grey.shade300,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                child: Image.asset(skin.backgroundPath, fit: BoxFit.cover, width: double.infinity),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                              child: Text(
                                skin.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                              child: selected
                                  ? const Text('Equipped', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w800))
                                  : owned
                                      ? SizedBox(
                                          width: double.infinity,
                                          height: 28,
                                          child: OutlinedButton(
                                            onPressed: () async {
                                              await skinManager.setSkinByIndex(index);
                                              setSheetState(() {});
                                            },
                                            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                                            child: const Text('Equip', style: TextStyle(fontSize: 11)),
                                          ),
                                        )
                                      : SizedBox(
                                          width: double.infinity,
                                          height: 28,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final ok = await skinManager.purchaseAndEquipByIndex(index, gameState);
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(this.context).showSnackBar(
                                                SnackBar(
                                                  content: Text(ok ? '${skin.name} purchased.' : 'Need ${skin.price} stars.'),
                                                ),
                                              );
                                              setSheetState(() {});
                                            },
                                            style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                                            child: Text('${skin.price}★', style: const TextStyle(fontSize: 11)),
                                          ),
                                        ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openGameGuideSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            _sheetHeader('Game Guide'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _gameDefs.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final game = _gameDefs[index];
                  return _sheetCard(
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: game.color.withValues(alpha: 0.18),
                        child: Icon(game.icon, color: game.color),
                      ),
                      title: Text(game.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(game.guide),
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

  void _openSettingsSheet(BuildContext context) {
    final gameState = context.read<GameStateManager>();
    final settings = context.read<SettingsManager>();
    final nicknameController = TextEditingController();
    var nicknameInitialized = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: FutureBuilder<Map<String, String>>(
                  future: UserProfileService.instance.getMyProfile(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data ?? {'nickname': 'Loading...', 'handle': '....#0000'};
                    if (!nicknameInitialized && snapshot.hasData) {
                      nicknameController.text = profile['nickname']!;
                      nicknameInitialized = true;
                    }
                    final isAnon = _auth.currentUser?.isAnonymous ?? true;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _sheetHeader('Settings'),
                        const SizedBox(height: 12),
                        _sheetCard(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('User ID: ${_auth.currentUser?.uid ?? 'none'}', style: const TextStyle(fontSize: 12)),
                              Text('Friend Code: ${profile['handle']}'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: nicknameController,
                                decoration: const InputDecoration(labelText: 'Nickname'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final name = nicknameController.text.trim();
                            if (name.isEmpty) return;
                            await UserProfileService.instance.updateNickname(name);
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Nickname updated.')),
                            );
                            setSheetState(() {});
                          },
                          child: const Text('Save Nickname'),
                        ),
                        const Divider(height: 30),
                        _sheetCard(
                          Column(
                            children: [
                        SwitchListTile(
                          value: settings.bgmOn,
                          title: const Text('BGM On'),
                          onChanged: (v) async {
                            await settings.setBgmOn(v);
                            await SoundManager.instance.applySettings();
                            if (v) {
                              await SoundManager.instance.playBgm(settings.bgmTrackIndex);
                            } else {
                              await SoundManager.instance.stopBgm();
                            }
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('BGM Track', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: settings.bgmTrackIndex,
                                items: List.generate(
                                  SoundManager.instance.bgmTitles.length,
                                  (index) => DropdownMenuItem<int>(
                                    value: index,
                                    child: Text(
                                      '${index + 1}. ${SoundManager.instance.bgmTitles[index]}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  await settings.setBgmTrackIndex(value);
                                  if (settings.bgmOn) {
                                    await SoundManager.instance.playBgm(value);
                                  }
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: settings.bgmVolume,
                          onChanged: settings.bgmOn
                              ? (v) async {
                                  await settings.setBgmVolume(v);
                                  await SoundManager.instance.applySettings();
                                  setSheetState(() {});
                                }
                              : null,
                        ),
                        SwitchListTile(
                          value: settings.sfxOn,
                          title: const Text('SFX On'),
                          onChanged: (v) async {
                            await settings.setSfxOn(v);
                            await SoundManager.instance.applySettings();
                            setSheetState(() {});
                          },
                        ),
                        Slider(
                          value: settings.sfxVolume,
                          onChanged: settings.sfxOn
                              ? (v) async {
                                  await settings.setSfxVolume(v);
                                  await SoundManager.instance.applySettings();
                                  setSheetState(() {});
                                }
                              : null,
                        ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isAnon)
                          ElevatedButton(
                            onPressed: () async {
                              final user = await _auth.linkWithGoogle(gameState);
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    user != null
                                        ? 'Signed in with Google.'
                                        : 'Google login failed. Check Firebase setup.',
                                  ),
                                ),
                              );
                              setSheetState(() {});
                            },
                            child: const Text('Google Login (Optional)'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () async {
                              await _auth.signOutToAnonymous(gameState);
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Signed out. Guest mode active.')),
                              );
                              setSheetState(() {});
                            },
                            child: const Text('Sign Out'),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFriendsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _sheetHeader('Friends'),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, String>>(
                future: UserProfileService.instance.getMyProfile(),
                builder: (context, snapshot) {
                  final profile = snapshot.data ?? {'nickname': 'Loading...', 'handle': '....#0000'};
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile['nickname']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
                                child: Text(profile['handle']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openAddFriendDialog(context),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _friends.getMyFriendsStream(),
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? const [];
                    if (list.isEmpty) {
                      return const Center(child: Text('No friends yet. Add with friend code.'));
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final f = list[index];
                        final online = _friends.isUserOnline(f['lastActive'] as Timestamp?);
                        return ListTile(
                          title: Text(f['nickname'] as String? ?? 'Unknown'),
                          subtitle: Text('${f['handle']} | ${online ? 'Online' : 'Offline'}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _friends.removeFriend(f['uid'] as String),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAddFriendDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'abcd#1234'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final dialogNav = Navigator.of(dialogContext);
              final rootMessenger = ScaffoldMessenger.of(this.context);
              final code = controller.text.trim();
              final target = await _friends.searchUserByHandle(code);
              if (target == null) {
                rootMessenger.showSnackBar(const SnackBar(content: Text('User not found.')));
                return;
              }
              final result = await _friends.addFriend(target);
              if (!mounted) return;
              dialogNav.pop();
              rootMessenger.showSnackBar(SnackBar(content: Text(result)));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _openRankingSheet(BuildContext context) {
    const gameIds = ['wordle', 'word_clue', 'anagram', 'word_crash'];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DefaultTabController(
        length: 1 + gameIds.length,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              _sheetHeader('Ranking'),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Stars'),
                  Tab(text: 'Wordle'),
                  Tab(text: 'Clue'),
                  Tab(text: 'Anagram'),
                  Tab(text: 'Crash'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _rankingListView(future: _ranking.getTotalStarRanking(), valueKey: 'totalStars'),
                    _rankingListView(future: _ranking.getGameRanking('wordle'), valueKey: 'score'),
                    _rankingListView(future: _ranking.getGameRanking('word_clue'), valueKey: 'score'),
                    _rankingListView(future: _ranking.getGameRanking('anagram'), valueKey: 'score'),
                    _rankingListView(future: _ranking.getGameRanking('word_crash'), valueKey: 'score'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rankingListView({
    required Future<List<Map<String, dynamic>>> future,
    required String valueKey,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final list = snapshot.data ?? const [];
        if (list.isEmpty) {
          return const Center(child: Text('No ranking data yet.'));
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = list[index];
            final nick = (item['nickname'] as String?) ?? 'Unknown';
            final value = (item[valueKey] as num?)?.toInt() ?? 0;
            return ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(nick),
              trailing: Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
            );
          },
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bestStage,
    required this.playCount,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int bestStage;
  final int playCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 30),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'BEST $bestStage',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'PLAYS $playCount',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Icon(Icons.play_arrow_rounded, size: 30, color: Colors.black26),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'PLAY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameDef {
  const _GameDef({
    required this.id,
    required this.route,
    required this.title,
    required this.subtitle,
    required this.guide,
    required this.icon,
    required this.color,
  });

  final String id;
  final String route;
  final String title;
  final String subtitle;
  final String guide;
  final IconData icon;
  final Color color;
}

