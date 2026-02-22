import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/managers/auth_service.dart';
import '../../core/managers/character_manager.dart';
import '../../core/managers/friend_service.dart';
import '../../core/managers/cloud_sync_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/ranking_service.dart';
import '../../core/managers/settings_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/sound_manager.dart';
import '../../core/managers/user_profile_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/attendance_checkin_dialog.dart';
import '../../core/widgets/app_safe_area.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService.instance;
  final FriendService _friends = FriendService();
  final RankingService _ranking = RankingService();
  final Map<String, String> _badgeAchievedAt = <String, String>{};
  bool _badgeSyncScheduled = false;
  bool _badgeStoreLoaded = false;

  static const List<int> _attendanceTierTargets = [7, 30, 90, 180, 365];
  static const List<int> _starsTierTargets = [300, 1200, 3000, 5500, 9000];
  static const List<int> _characterTierTargets = [3, 8, 14, 20, 26];
  static const List<int> _stageTierTargets = [5, 20, 50, 90, 140];
  static const List<String> _stageBadgeGames = ['wordle', 'word_clue', 'sentence_code', 'anagram', 'word_crash'];
  static const List<String> _tierNames = ['브론즈', '실버', '골드', '플래티넘', '미틱'];
  static const List<int> _badgeTierStarRewards = [5, 10, 15, 20, 25];
  static const List<Color> _tierColors = [
    Color(0xFFB87333),
    Color(0xFFA0A8B3),
    Color(0xFFD4AF37),
    Color(0xFF6FB7FF),
    Color(0xFFFF5FA2),
  ];
  static const List<_GameDef> _gameDefs = [
    _GameDef(
      id: 'wordle',
      route: '/wordle',
      title: 'WORDLE',
      subtitle: '6번 기회, 색상 피드백으로 정답 추론',
      guide: '6번 안에 정답 단어를 맞히는 게임입니다. 색상 피드백으로 위치와 포함 여부를 파악하세요.',
      icon: Icons.grid_view_rounded,
      color: Color(0xFF37B24D),
    ),
    _GameDef(
      id: 'word_clue',
      route: '/word-clue',
      title: 'WORD CLUE',
      subtitle: '뜻과 품사를 보고 알파벳 타일 조합',
      guide: '의미와 품사를 보고 알파벳 타일을 조합해 단어를 완성하는 모드입니다.',
      icon: Icons.quiz_rounded,
      color: Color(0xFFF08C00),
    ),
    _GameDef(
      id: 'sentence_code',
      route: '/sentence-code',
      title: 'SENTENCE CODE',
      subtitle: '숫자 암호를 해독해 문장 복원',
      guide: '문장 속 알파벳이 번호로 암호화되어 있습니다. 단서 단어를 활용해 전체 문장을 복원하세요.',
      icon: Icons.lock_open_rounded,
      color: Color(0xFF1D4ED8),
    ),
    _GameDef(
      id: 'anagram',
      route: '/anagram',
      title: 'ANAGRAM',
      subtitle: '핵심 단어 + 일반 단어 보너스 점수',
      guide: '주어진 글자 조합으로 핵심 단어를 찾고, 추가 단어로 보너스 점수를 얻는 모드입니다.',
      icon: Icons.shuffle_rounded,
      color: Color(0xFF7B2CBF),
    ),
    _GameDef(
      id: 'word_crash',
      route: '/word-crash',
      title: 'WORD CRASH',
      subtitle: '연결, 폭탄, 중력, 콤보로 고득점',
      guide: '인접한 글자를 연결해 단어를 만들고, 폭탄/콤보를 활용해 고득점을 노리세요.',
      icon: Icons.auto_awesome_motion_rounded,
      color: Color(0xFF1C7ED6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBadgeStore();
  }

  Future<void> _loadBadgeStore() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('badge_achieved_keys') ?? const [];
    final map = <String, String>{};
    for (final key in keys) {
      final stamp = prefs.getString('badge_achieved_at::$key');
      if (stamp != null && stamp.isNotEmpty) {
        map[key] = stamp;
      }
    }
    if (!mounted) return;
    setState(() {
      _badgeAchievedAt
        ..clear()
        ..addAll(map);
      _badgeStoreLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    final gameState = context.watch<GameStateManager>();
    _scheduleBadgeSync(gameState);
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
          AppSafeArea(
            child: Row(
              children: [
                _buildSideBar(
                  context,
                  gameState: gameState,
                  width: sidebarWidth,
                  compact: compactSidebar,
                ),
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
                                    await _openGameWithHeartGuard(
                                      context,
                                      gameId: g.id,
                                      route: g.route,
                                    );
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

  Future<void> _openGameWithHeartGuard(
    BuildContext context, {
    required String gameId,
    required String route,
  }) async {
    final gameState = context.read<GameStateManager>();
    if (!gameState.hasPlayableHeart) {
      final refillText = gameState.hearts >= GameStateManager.maxHearts
          ? 'FULL'
          : gameState.nextHeartCountdownText;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hearts left. Next refill: $refillText')),
      );
      return;
    }
    await gameState.increasePlayCount(gameId);
    if (!context.mounted) return;
    context.push(route);
  }

  Future<void> _openAttendanceRecapDialog(
    BuildContext context,
    GameStateManager gameState,
  ) async {
    if (gameState.attendanceStreak <= 0 || gameState.attendanceHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 출석 기록이 없어요.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AttendanceCheckinDialog(
        streak: gameState.attendanceStreak,
        starsGained: _latestAttendanceReward(gameState.attendanceStreak),
        today: _latestAttendanceDay(gameState.lastAttendanceDate),
        attendanceHistory: gameState.attendanceHistory,
        animateTodayStamp: false,
      ),
    );
  }

  int _latestAttendanceReward(int streak) {
    if (streak <= 0) return 0;
    final streakBonus = streak % 7 == 0 ? 5 : 0;
    final milestoneBonus = streak % 100 == 0 ? streak : 0;
    return 1 + streakBonus + milestoneBonus;
  }

  DateTime _latestAttendanceDay(String? isoDay) {
    final parsed = isoDay == null ? null : DateTime.tryParse(isoDay);
    if (parsed == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _openAttendanceFromMenu(
    BuildContext context,
    GameStateManager gameState,
  ) async {
    final attendance = await gameState.claimAttendanceIfNeeded();
    if (!mounted) return;
    if (attendance != null && attendance.claimed) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AttendanceCheckinDialog(
          streak: attendance.streak,
          starsGained: attendance.starsGained,
          today: DateTime.now(),
          attendanceHistory: gameState.attendanceHistory,
          animateTodayStamp: true,
        ),
      );
      return;
    }
    await _openAttendanceRecapDialog(context, gameState);
  }

  EdgeInsets _sheetBottomPadding(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return EdgeInsets.only(bottom: bottom + 12);
  }

  void _openWordSuggestionSheet(BuildContext context) {
    final wordController = TextEditingController();
    final reasonController = TextEditingController();
    String gameId = 'all';
    bool submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + _sheetBottomPadding(context).bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('단어 제안', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                    '누락된 단어를 간단히 제안해 주세요.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: wordController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: '제안 단어 (영어)',
                      hintText: 'example: TREE',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: gameId,
                    decoration: const InputDecoration(labelText: '적용 게임'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('전체')),
                      DropdownMenuItem(value: 'wordle', child: Text('Wordle')),
                      DropdownMenuItem(value: 'word_clue', child: Text('Word Clue')),
                      DropdownMenuItem(value: 'sentence_code', child: Text('Sentence Code')),
                      DropdownMenuItem(value: 'anagram', child: Text('Anagram')),
                      DropdownMenuItem(value: 'word_crash', child: Text('Word Crash')),
                    ],
                    onChanged: submitting
                        ? null
                        : (v) {
                            if (v == null) return;
                            setSheetState(() => gameId = v);
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '추가 이유',
                      hintText: '예: 자주 나오는데 사전에 없어요.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting ? null : () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: submitting
                              ? null
                              : () async {
                                  final sheetNav = Navigator.of(context);
                                  final rootMessenger = ScaffoldMessenger.of(this.context);
                                  setSheetState(() => submitting = true);
                                  final result = await CloudSyncManager.instance.submitWordSuggestion(
                                    word: wordController.text,
                                    description: reasonController.text,
                                    gameId: gameId,
                                  );
                                  if (!mounted) return;
                                  if (result.ok) {
                                    sheetNav.pop();
                                  } else {
                                    setSheetState(() => submitting = false);
                                  }
                                  rootMessenger.showSnackBar(
                                    SnackBar(content: Text(result.message)),
                                  );
                                },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('보내기'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSideBar(
    BuildContext context, {
    required GameStateManager gameState,
    required double width,
    required bool compact,
  }) {
    final attendanceDone = !gameState.canCheckInToday;
    final attendanceLabel = '${gameState.attendanceStreak}d';
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
          _sideButton(icon: Icons.storefront_rounded, label: '상점', compact: compact, onTap: () => _openShopSheet(context)),
          _sideButton(
            icon: Icons.calendar_month_rounded,
            label: attendanceLabel,
            compact: compact,
            muted: !attendanceDone,
            onTap: () => _openAttendanceFromMenu(context, gameState),
          ),
          _sideButton(icon: Icons.workspace_premium_rounded, label: '뱃지', compact: compact, onTap: () => _openBadgesSheet(context)),
          _sideButton(icon: Icons.emoji_events_rounded, label: '랭킹', compact: compact, onTap: () => _openRankingSheet(context)),
          _sideButton(icon: Icons.group_rounded, label: '친구', compact: compact, onTap: () => _openFriendsSheet(context)),
          _sideButton(icon: Icons.help_outline_rounded, label: '도움말', compact: compact, onTap: () => _openGameGuideSheet(context)),
          _sideButton(icon: Icons.settings_rounded, label: '설정', compact: compact, onTap: () => _openSettingsSheet(context)),
        ],
      ),
    );
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    required bool compact,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    final iconSize = compact ? 20.0 : 22.0;
    final circleSize = compact ? 38.0 : 42.0;
    final iconColor = muted ? const Color(0xFF868E96) : AppColors.primary;
    final chipColor = muted ? const Color(0xFFF1F3F5) : AppColors.background;
    final borderColor = muted ? const Color(0xFFD0D7DE) : AppColors.primary.withValues(alpha: 0.22);
    final labelColor = muted ? const Color(0xFF868E96) : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: labelColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CharacterProfile character, GameStateManager gameState) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user == null || user.isAnonymous ? '게스트 모드' : (user.displayName ?? 'Google 로그인');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: compact ? 22 : 24, backgroundImage: AssetImage(character.imagePath)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '안녕하세요, ${character.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 15 : 17, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statChip(
                    icon: Icons.favorite,
                    color: AppColors.error,
                    text: '${gameState.hearts}',
                    subText: gameState.hearts >= GameStateManager.maxHearts
                        ? 'FULL'
                        : '다음 +1 ${gameState.nextHeartCountdownText}',
                  ),
                  const SizedBox(height: 6),
                  _statChip(icon: Icons.star, color: AppColors.secondary, text: '${gameState.stars}'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required Color color,
    required String text,
    String? subText,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (subText != null)
                Text(
                  subText,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
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

  void _openShopSheet(BuildContext context) {
    final gameState = context.read<GameStateManager>();
    final skinManager = context.read<SkinManager>();
    final allCharacters = CharacterManager().characters;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => Padding(
        padding: _sheetBottomPadding(sheetContext),
        child: DefaultTabController(
          length: 2,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    _sheetHeader('상점'),
                    const SizedBox(height: 6),
                    Text('보유 별: ${gameState.stars}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const TabBar(
                      tabs: [
                        Tab(text: '캐릭터'),
                        Tab(text: '스킨'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCharacterShopTab(
                            context,
                            gameState: gameState,
                            allCharacters: allCharacters,
                            setSheetState: setSheetState,
                          ),
                          _buildSkinShopTab(
                            context,
                            gameState: gameState,
                            skinManager: skinManager,
                            setSheetState: setSheetState,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterShopTab(
    BuildContext context, {
    required GameStateManager gameState,
    required List<CharacterProfile> allCharacters,
    required StateSetter setSheetState,
  }) {
    return Column(
      children: [
        const SizedBox(height: 4),
        const Text('캐릭터는 모두 50별로 구매할 수 있어요.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: allCharacters.length,
            itemBuilder: (context, index) {
              final item = allCharacters[index];
              final owned = gameState.unlockedCharacters.contains(item.id);
              final selected = item.id == gameState.selectedCharacterId;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE7F0FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
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
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text(success ? '${item.name} 잠금 해제 완료' : '별이 부족합니다.')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(30),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('50별'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () async {
                          await gameState.equipCharacter(item.id);
                          setSheetState(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(30),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: Text(selected ? '착용 중' : '착용'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkinShopTab(
    BuildContext context, {
    required GameStateManager gameState,
    required SkinManager skinManager,
    required StateSetter setSheetState,
  }) {
    final currentId = skinManager.currentSkin.id;
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    return Column(
      children: [
        const SizedBox(height: 4),
        const Text('원하는 배경 스킨을 구매하거나 착용하세요.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
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
                          ? const Text('착용 중', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w800))
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
                                    child: const Text('착용', style: TextStyle(fontSize: 11)),
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
                                        SnackBar(content: Text(ok ? '${skin.name} 구매 완료' : '${skin.price}별이 필요합니다.')),
                                      );
                                      setSheetState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                                    child: Text('${skin.price}별', style: const TextStyle(fontSize: 11)),
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
    );
  }

  void _openGameGuideSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: _sheetBottomPadding(context),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
          children: [
            _sheetHeader('게임 가이드'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _gameDefs.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final game = _gameDefs[index];
                  return _sheetCard(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: game.color.withValues(alpha: 0.18),
                              child: Icon(game.icon, color: game.color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                game.title,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(game.guide, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          _guideTip(game.id),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        _buildGuideExample(game.id),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  String _guideTip(String gameId) {
    switch (gameId) {
      case 'wordle':
        return '초반에는 모음과 자주 쓰는 자음을 섞어 입력하면 정답 후보를 빠르게 줄일 수 있습니다.';
      case 'word_clue':
        return '품사와 의미를 먼저 확인하고, 길이가 짧은 단어부터 맞히면 진행이 쉬워집니다.';
      case 'sentence_code':
        return '반복되는 번호를 먼저 찾아 같은 알파벳을 추론하면 문장 복원 속도가 크게 올라갑니다.';
      case 'anagram':
        return '2~3글자 단어를 먼저 확보하고, 핵심 단어 길이를 늘려가며 조합해 보세요.';
      case 'word_crash':
        return '긴 단어와 특수 블록을 연계하면 콤보 점수가 크게 올라갑니다.';
      default:
        return '';
    }
  }

  Widget _buildGuideExample(String gameId) {
    switch (gameId) {
      case 'wordle':
        return _buildWordleGuideExample();
      case 'word_clue':
        return _buildWordClueGuideExample();
      case 'sentence_code':
        return _buildSentenceCodeGuideExample();
      case 'anagram':
        return _buildAnagramGuideExample();
      case 'word_crash':
        return _buildWordCrashGuideExample();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWordleGuideExample() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA9DDB2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('예시: 정답 TRAIN, 입력 TRAIL'),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GuideTile('T', background: Color(0xFF2F9E44), foreground: Colors.white),
              _GuideTile('R', background: Color(0xFF2F9E44), foreground: Colors.white),
              _GuideTile('A', background: Color(0xFF2F9E44), foreground: Colors.white),
              _GuideTile('I', background: Color(0xFF2F9E44), foreground: Colors.white),
              _GuideTile('L', background: Color(0xFFADB5BD), foreground: Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          const Text('초록: 위치 일치  |  주황: 포함  |  회색: 없음', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildWordClueGuideExample() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF6CE8A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('예시 뜻: 구름에서 내리는 물'),
          const SizedBox(height: 8),
          const Row(
            children: [
              _GuideTile('R'),
              SizedBox(width: 4),
              _GuideTile('A'),
              SizedBox(width: 4),
              _GuideTile('I'),
              SizedBox(width: 4),
              _GuideTile('N'),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _GuideOptionChip('R'),
              _GuideOptionChip('B'),
              _GuideOptionChip('I'),
              _GuideOptionChip('N'),
              _GuideOptionChip('T'),
            ],
          ),
          const SizedBox(height: 8),
          const Text('글자를 순서대로 눌러 목표 단어를 완성하세요.', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSentenceCodeGuideExample() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA9C6FF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('문장 알파벳이 숫자로 치환됩니다.'),
          SizedBox(height: 8),
          Text('1 2 3 4   5 2 6 7 8   9 10 6 11'),
          SizedBox(height: 8),
          Text('단서 단어를 바탕으로 알파벳을 추론해 문장을 복원하세요.', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildAnagramGuideExample() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4B8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('시드 글자: C A R E'),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _GuideWordBadge('CARE'),
              _GuideWordBadge('RACE'),
              _GuideWordBadge('ACRE'),
            ],
          ),
          const SizedBox(height: 8),
          const Text('핵심 단어를 먼저 채우고, 보너스 단어로 추가 점수를 얻으세요.', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildWordCrashGuideExample() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB7D3FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('인접 블록을 연결해 단어를 만드세요.'),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GuideTile('S'),
              _GuideTile('T'),
              _GuideTile('A'),
              _GuideTile('R'),
              _GuideTile('B', background: Color(0xFFFFD43B)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('팁: STAR + 폭탄(B) 정리 조합은 콤보 점수가 높아요.', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _openSettingsSheet(BuildContext context) {
    final settings = context.read<SettingsManager>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + _sheetBottomPadding(context).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.74,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sheetHeader('설정'),
                    const SizedBox(height: 12),
                    _sheetCard(
                      Column(
                        children: [
                          SwitchListTile(
                            value: settings.bgmOn,
                            title: const Text('배경음악 사용'),
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
                              const Text('배경음악 트랙', style: TextStyle(fontWeight: FontWeight.w700)),
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
                            title: const Text('효과음 사용'),
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
                    const SizedBox(height: 10),
                    _sheetCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('포스트', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          const Text(
                            '누락 단어나 개선 의견을 보내고 싶다면 포스트를 열어 제안해 주세요.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Future<void>.delayed(const Duration(milliseconds: 120), () {
                                  if (!mounted) return;
                                  _openWordSuggestionSheet(this.context);
                                });
                              },
                              icon: const Icon(Icons.post_add_rounded),
                              label: const Text('포스트 열기'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFriendsSheet(BuildContext context) {
    final gameState = context.read<GameStateManager>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isAnon = _auth.currentUser?.isAnonymous ?? true;
            return Padding(
              padding: _sheetBottomPadding(context),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    _sheetHeader('친구'),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, String>>(
                      future: UserProfileService.instance.getMyProfile(),
                      builder: (context, snapshot) {
                        final profile = snapshot.data ?? {'nickname': '로딩 중...', 'handle': '....#0000'};
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(profile['nickname']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(profile['handle']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                    if (isAnon) ...[
                                      const SizedBox(height: 6),
                                      const Text(
                                        '현재 게스트 계정입니다. 친구 추가는 가능하며, Google 로그인 시 친구 목록을 병합합니다.',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _openAddFriendDialog(context),
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('친구 추가'),
                                  ),
                                  const SizedBox(height: 6),
                                  if (isAnon)
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final user = await _auth.linkWithGoogle(gameState);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              user != null
                                                  ? 'Google 로그인 완료. 친구 목록을 병합했습니다.'
                                                  : 'Google 로그인 실패: Firebase 설정을 확인해 주세요.',
                                            ),
                                          ),
                                        );
                                        setSheetState(() {});
                                      },
                                      icon: const Icon(Icons.login_rounded),
                                      label: const Text('Google 로그인'),
                                    )
                                  else
                                    OutlinedButton(
                                      onPressed: () async {
                                        await _auth.signOutToAnonymous(gameState);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          const SnackBar(content: Text('로그아웃 완료. 게스트 모드로 전환됐습니다.')),
                                        );
                                        setSheetState(() {});
                                      },
                                      child: const Text('로그아웃'),
                                    ),
                                ],
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
                            return const Center(child: Text('저장된 친구가 없습니다. 친구 코드를 입력해 추가해 보세요.'));
                          }
                          return ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final f = list[index];
                              final online = _friends.isUserOnline(f['lastActive'] as Timestamp?);
                              return ListTile(
                                title: Text(f['nickname'] as String? ?? '알 수 없음'),
                                subtitle: Text('${f['handle']} | ${online ? '온라인' : '오프라인'}'),
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
              ),
            );
          },
        );
      },
    );
  }

  void _openAddFriendDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('친구 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '친구 코드 입력 (예: abcd#1234)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final dialogNav = Navigator.of(dialogContext);
              final rootMessenger = ScaffoldMessenger.of(this.context);
              final code = controller.text.trim();
              final target = await _friends.searchUserByHandle(code);
              if (target == null) {
                rootMessenger.showSnackBar(const SnackBar(content: Text('사용자를 찾을 수 없습니다.')));
                return;
              }
              final result = await _friends.addFriend(target);
              if (!mounted) return;
              dialogNav.pop();
              rootMessenger.showSnackBar(SnackBar(content: Text(_friendResultText(result))));
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  String _friendResultText(String raw) {
    switch (raw) {
      case 'Login required.':
        return '로그인이 필요합니다.';
      case 'Invalid target user.':
        return '잘못된 친구 정보입니다.';
      case 'You cannot add yourself.':
        return '자기 자신은 추가할 수 없습니다.';
      case 'Already added.':
        return '이미 추가된 친구입니다.';
      case 'Added':
        return '친구가 추가되었습니다.';
      default:
        return raw;
    }
  }

  void _openBadgesSheet(BuildContext context) {
    final gameState = context.read<GameStateManager>();
    final cards = _buildBadgeCards(gameState);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: _sheetBottomPadding(context),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.84,
          child: Column(
            children: [
              _sheetHeader('뱃지'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final tier = _currentTier(card.currentValue, card.targets);
                    return _sheetCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: card.color.withValues(alpha: 0.16),
                                child: Icon(card.icon, color: card.color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(card.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                    Text(
                                      '${card.currentValue} / ${card.targets.last}  |  티어 ${tier + 1}/5',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(5, (tierIndex) {
                              final reached = card.currentValue >= card.targets[tierIndex];
                              final key = '${card.id}:$tierIndex';
                              final isMilestone = tierIndex == 4;
                              final isAchieved = _badgeAchievedAt.containsKey(key);
                              final color = _tierColors[tierIndex];
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _openBadgeTierDetail(context, card, tierIndex),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 240),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: reached ? color.withValues(alpha: 0.18) : const Color(0xFFF1F3F5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: reached ? color : const Color(0xFFCED4DA),
                                          width: reached ? 1.6 : 1.1,
                                        ),
                                        boxShadow: reached
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(alpha: isMilestone ? 0.38 : 0.18),
                                                  blurRadius: isMilestone ? 13 : 8,
                                                  spreadRadius: isMilestone ? 1 : 0,
                                                ),
                                              ]
                                            : const [],
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            isAchieved ? Icons.verified_rounded : Icons.shield_outlined,
                                            size: isMilestone ? 20 : 18,
                                            color: reached ? color : const Color(0xFF868E96),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'T${tierIndex + 1}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: reached ? color : const Color(0xFF868E96),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBadgeTierDetail(BuildContext context, _BadgeCard card, int tierIndex) {
    final target = card.targets[tierIndex];
    final reached = card.currentValue >= target;
    final key = '${card.id}:$tierIndex';
    final achievedAt = _badgeAchievedAt[key];
    final nextTarget = tierIndex < 4 ? card.targets[tierIndex + 1] : null;
    final remain = reached ? 0 : (target - card.currentValue);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: _sheetBottomPadding(context).add(const EdgeInsets.all(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${card.title} · ${_tierNames[tierIndex]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('조건: ${card.description} $target', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('현재: ${card.currentValue}', style: const TextStyle(color: AppColors.textSecondary)),
            if (nextTarget != null) ...[
              const SizedBox(height: 4),
              Text('다음 티어 목표: $nextTarget', style: const TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 6),
            Text(
              reached ? '상태: 달성' : '상태: 미달성 (남음 $remain)',
              style: TextStyle(fontWeight: FontWeight.w800, color: reached ? const Color(0xFF2B8A3E) : AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '티어 보상: +${_badgeTierStarRewards[tierIndex]}별',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            if (achievedAt != null) ...[
              const SizedBox(height: 6),
              Text('달성일: ${_shortDate(achievedAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  List<_BadgeCard> _buildBadgeCards(GameStateManager gameState) {
    final list = <_BadgeCard>[
      _BadgeCard(
        id: 'attendance',
        title: '출석',
        description: '연속 출석 일수',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2F9E44),
        currentValue: gameState.attendanceStreak,
        targets: _attendanceTierTargets,
      ),
      _BadgeCard(
        id: 'stars',
        title: '별 수집가',
        description: '누적 획득 별',
        icon: Icons.star_rounded,
        color: const Color(0xFFF08C00),
        currentValue: gameState.totalStarsEarned,
        targets: _starsTierTargets,
      ),
      _BadgeCard(
        id: 'characters',
        title: '캐릭터 수집가',
        description: '잠금 해제 캐릭터 수',
        icon: Icons.pets_rounded,
        color: const Color(0xFF7048E8),
        currentValue: gameState.unlockedCharacters.length,
        targets: _characterTierTargets,
      ),
    ];
    for (final gameId in _stageBadgeGames) {
      final game = _gameDefs.firstWhere((g) => g.id == gameId);
      list.add(
        _BadgeCard(
          id: 'stage_$gameId',
          title: '${game.title} 스테이지',
          description: '최고 도달 스테이지',
          icon: game.icon,
          color: game.color,
          currentValue: gameState.getBestStage(gameId),
          targets: _stageTierTargets,
        ),
      );
    }
    return list;
  }

  void _scheduleBadgeSync(GameStateManager gameState) {
    if (!_badgeStoreLoaded || _badgeSyncScheduled) return;
    _badgeSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _badgeSyncScheduled = false;
      if (!mounted) return;
      final cards = _buildBadgeCards(gameState);
      final unlockedNow = <String>[];
      for (final card in cards) {
        final tier = _currentTier(card.currentValue, card.targets);
        for (int i = 0; i <= tier; i++) {
          final key = '${card.id}:$i';
          if (_badgeAchievedAt.containsKey(key)) continue;
          unlockedNow.add(key);
        }
      }
      if (unlockedNow.isEmpty) return;
      final now = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      int starBonus = 0;
      for (final key in unlockedNow) {
        final parts = key.split(':');
        final tierIndex = int.tryParse(parts.last) ?? 0;
        final safeTier = tierIndex < 0
            ? 0
            : (tierIndex >= _badgeTierStarRewards.length ? _badgeTierStarRewards.length - 1 : tierIndex);
        starBonus += _badgeTierStarRewards[safeTier];
        _badgeAchievedAt[key] = now;
        await prefs.setString('badge_achieved_at::$key', now);
      }
      await prefs.setStringList('badge_achieved_keys', _badgeAchievedAt.keys.toList());
      if (starBonus > 0) {
        await gameState.addStars(starBonus);
      }
      if (!mounted) return;
      final first = unlockedNow.first;
      final parts = first.split(':');
      final cardId = parts.first;
      final tierIndex = int.tryParse(parts.last) ?? 0;
      final card = cards.firstWhere((c) => c.id == cardId, orElse: () => cards.first);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('뱃지 달성 ${unlockedNow.length}개 · 보너스 +$starBonus별 (${card.title} · ${_tierNames[tierIndex]})'),
        ),
      );
      setState(() {});
    });
  }

  int _currentTier(int value, List<int> targets) {
    int tier = -1;
    for (int i = 0; i < targets.length; i++) {
      if (value >= targets[i]) {
        tier = i;
      }
    }
    return tier;
  }

  String _shortDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  void _openRankingSheet(BuildContext context) {
    const gameIds = ['wordle', 'word_clue', 'sentence_code', 'anagram', 'word_crash'];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: _sheetBottomPadding(context),
        child: DefaultTabController(
          length: 1 + gameIds.length,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Column(
            children: [
              _sheetHeader('랭킹'),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: '별'),
                  Tab(text: 'Wordle'),
                  Tab(text: 'Word Clue'),
                  Tab(text: 'Sentence Code'),
                  Tab(text: 'Anagram'),
                  Tab(text: 'Word Crash'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _rankingListView(future: _ranking.getTotalStarRanking(), valueKey: 'keTotalStars'),
                    _rankingListView(future: _ranking.getGameRanking('wordle'), valueKey: 'score'),
                    _rankingListView(future: _ranking.getGameRanking('word_clue'), valueKey: 'score'),
                    _rankingListView(future: _ranking.getGameRanking('sentence_code'), valueKey: 'score'),
                    _rankingListView(future: _ranking.getGameRanking('anagram'), valueKey: 'score'),
                    _rankingListView(future: _ranking.getGameRanking('word_crash'), valueKey: 'score'),
                  ],
                ),
              ),
            ],
          ),
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
          return const Center(child: Text('아직 랭킹 데이터가 없습니다.'));
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = list[index];
            final nick = (item['nickname'] as String?) ?? '알 수 없음';
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

class _GuideTile extends StatelessWidget {
  const _GuideTile(
    this.text, {
    this.background = Colors.white,
    this.foreground = AppColors.textPrimary,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: foreground,
        ),
      ),
    );
  }
}

class _GuideOptionChip extends StatelessWidget {
  const _GuideOptionChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9C46A)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _GuideWordBadge extends StatelessWidget {
  const _GuideWordBadge(this.word);

  final String word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7A8FF)),
      ),
      child: Text(
        word,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
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

class _BadgeCard {
  const _BadgeCard({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentValue,
    required this.targets,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int currentValue;
  final List<int> targets;
}


