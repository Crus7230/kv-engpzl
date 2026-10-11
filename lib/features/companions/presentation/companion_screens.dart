import 'package:flutter/material.dart';

import '../../progress/domain/progress_models.dart';
import '../data/companion_catalog.dart';
import '../domain/companion_models.dart';
import '../domain/companion_progress_service.dart';

const _ink = Color(0xFF193F37);
const _muted = Color(0xFF596C63);
const _paper = Color(0xFFFFF9E9);
const _gold = Color(0xFFC08B3B);

/// A reusable portrait that prefers Renewal art and retains original R1 art.
/// Planned characters without shipped art use a deliberate letter silhouette.
class CompanionPortrait extends StatelessWidget {
  const CompanionPortrait({
    required this.profile,
    this.size = 160,
    this.locked = false,
    super.key,
  });
  final CompanionProfile profile;
  final double size;
  final bool locked;

  Widget _letter() => Center(
    child: Text(
      profile.letter,
      style: TextStyle(
        fontSize: size * .57,
        fontWeight: FontWeight.w900,
        color: locked ? const Color(0xFF96A59A) : _ink,
        shadows: const [Shadow(color: Color(0x33000000), blurRadius: 8)],
      ),
    ),
  );

  Widget _legacy() => Image.asset(
    profile.legacyAsset,
    cacheWidth: (size * 3).round(),
    fit: BoxFit.contain,
    errorBuilder: (context, error, stack) => _letter(),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: locked ? '아직 만나지 않은 ${profile.name}' : '${profile.name} 동료',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: locked
                      ? const [Color(0xFFE2E7DD), Color(0x00E2E7DD)]
                      : const [Color(0xFFFFE0A1), Color(0x00FFE0A1)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size * .025,
            child: Container(
              width: size * .68,
              height: size * .085,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(60),
                boxShadow: const [
                  BoxShadow(color: Color(0x26113C2E), blurRadius: 9),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size * .025),
            child: locked
                ? _letter()
                : profile.expeditionAsset == null
                ? _legacy()
                : Image.asset(
                    profile.expeditionAsset!,
                    cacheWidth: (size * 3).round(),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => _legacy(),
                  ),
          ),
        ],
      ),
    ),
  );
}

/// The character tab is a collection, never a shop. Original profile facts are
/// available for the selected player and companions rescued in this expedition.
class CompanionCollectionScreen extends StatefulWidget {
  const CompanionCollectionScreen({
    required this.save,
    required this.onBack,
    this.onReplayArrival,
    super.key,
  });
  final SaveEnvelopeV1 save;
  final VoidCallback onBack;
  final ValueChanged<String>? onReplayArrival;

  @override
  State<CompanionCollectionScreen> createState() =>
      _CompanionCollectionScreenState();
}

class _CompanionCollectionScreenState extends State<CompanionCollectionScreen> {
  bool _showPlanned = false;
  String _selectedId = 'CHAR_D';

  @override
  void initState() {
    super.initState();
    _selectedId =
        companionRecruitmentPlan
            .where(
              (entry) =>
                  widget.save.unlockedCharacterIds.contains(entry.characterId),
            )
            .firstOrNull
            ?.characterId ??
        'CHAR_D';
  }

  List<CompanionRecruitment> get _entries => [
    for (final entry in companionRecruitmentPlan)
      if (_showPlanned ||
          widget.save.unlockedCharacterIds.contains(entry.characterId))
        entry,
  ];

  @override
  Widget build(BuildContext context) {
    final profile = companionProfileById(_selectedId)!;
    final recruitment = companionRecruitmentById(_selectedId)!;
    final owned = widget.save.unlockedCharacterIds.contains(profile.id);
    final knownOwnedCount = companionProfiles
        .where((entry) => widget.save.unlockedCharacterIds.contains(entry.id))
        .length;
    return _CompanionFrame(
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  tooltip: '탐험 지도로',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Text(
                  '동료 도감',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                Text(
                  '탐험대 인원 $knownOwnedCount / 26',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 630 ? 146 : 170,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 40,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _RosterFilter(
                                    label: '합류',
                                    selected: !_showPlanned,
                                    onTap: () =>
                                        setState(() => _showPlanned = false),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _RosterFilter(
                                    label: '전체',
                                    selected: _showPlanned,
                                    onTap: () =>
                                        setState(() => _showPlanned = true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: _entries.isEmpty
                                ? const Center(
                                    child: Text(
                                      '첫 탐험에서\n동료를 만나 보세요.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _muted,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    key: const Key('companion-roster'),
                                    itemCount: _entries.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 5),
                                    itemBuilder: (context, index) {
                                      final entry = _entries[index];
                                      final p = companionProfileById(
                                        entry.characterId,
                                      )!;
                                      final isOwned = widget
                                          .save
                                          .unlockedCharacterIds
                                          .contains(p.id);
                                      return _RosterTile(
                                        profile: p,
                                        selected: _selectedId == p.id,
                                        owned: isOwned,
                                        subtitle:
                                            p.id ==
                                                widget.save.playerCharacterId
                                            ? '내 캐릭터 · ${entry.expeditionRole}'
                                            : isOwned
                                            ? entry.expeditionRole
                                            : 'R${entry.regionNumber} · 아직 만나지 못함',
                                        onTap: () =>
                                            setState(() => _selectedId = p.id),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfilePanel(
                        profile: profile,
                        recruitment: recruitment,
                        owned: owned,
                        isPlayer: profile.id == widget.save.playerCharacterId,
                        canReplay:
                            owned &&
                            profile.id != widget.save.playerCharacterId &&
                            isCompanionRecruitmentEligible(
                              recruitment,
                              widget.save.completedStageIds,
                            ),
                        onReplay: widget.onReplayArrival == null
                            ? null
                            : () => widget.onReplayArrival!(profile.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.profile,
    required this.recruitment,
    required this.owned,
    required this.isPlayer,
    required this.canReplay,
    this.onReplay,
  });
  final CompanionProfile profile;
  final CompanionRecruitment recruitment;
  final bool owned;
  final bool isPlayer;
  final bool canReplay;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _paper.withValues(alpha: .97),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD9CDB4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x101D4433),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final portraitSize = constraints.maxWidth < 480 ? 98.0 : 124.0;
        return Row(
          children: [
            SizedBox(
              width: portraitSize + 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CompanionPortrait(
                    profile: profile,
                    size: portraitSize,
                    locked: !owned,
                  ),
                  Text(
                    profile.letter,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: _gold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPlayer
                        ? '내 캐릭터'
                        : owned
                        ? '탐험대 동료'
                        : '발견 예정',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('companion-profile-details'),
                padding: const EdgeInsets.fromLTRB(4, 13, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    Text(
                      recruitment.expeditionRole,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (owned) ...[
                      _ProfileFact('MBTI', profile.mbti),
                      _ProfileFact('좋아하는 음식', profile.favoriteFood),
                      _ProfileFact('좋아하는 수학 분야', profile.favoriteMathField),
                      _ProfileFact('좋아하는 숫자', profile.favoriteNumber),
                      const SizedBox(height: 4),
                      Text(
                        '기존 앱의 캐릭터 정보 계승 · 탐험 역할은 Renewal 이야기',
                        style: TextStyle(
                          fontSize: 10,
                          color: _muted.withValues(alpha: .85),
                        ),
                      ),
                      if (canReplay && onReplay != null)
                        TextButton.icon(
                          onPressed: onReplay,
                          icon: const Icon(
                            Icons.auto_stories_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            '첫 만남 다시 보기',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      if (isPlayer)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '내가 선택한 탐험가입니다. 캐릭터에 따라 진행이나 힌트가 달라지지 않아요.',
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ),
                      if (!canReplay && !isPlayer)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '합류한 동료의 정보입니다. 만남 이야기는 해당 탐험 지점에서 열려요.',
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ),
                    ] else ...[
                      _ProfileFact('만날 장소', recruitment.location),
                      _ProfileFact('합류 조건', recruitment.requirementLabel),
                      const Text(
                        '탐험을 이어 가면 이 동료의 정보를 알아볼 수 있어요. 별을 쓰거나 뽑기를 할 필요가 없어요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _RosterFilter extends StatelessWidget {
  const _RosterFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _ink : const Color(0xFFE6E6D8),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? _paper : _ink,
          ),
        ),
      ),
    ),
  );
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({
    required this.profile,
    required this.selected,
    required this.owned,
    required this.subtitle,
    required this.onTap,
  });
  final CompanionProfile profile;
  final bool selected;
  final bool owned;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: '${profile.name}, ${owned ? "합류한 동료" : "아직 만나지 않은 동료"}',
    child: Material(
      color: selected ? const Color(0xFFE8DFC3) : _paper.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('companion-${profile.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: owned ? _ink : const Color(0xFF9FA99C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profile.letter,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _paper,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: _muted),
                    ),
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

/// A milestone scene; acknowledging it is persisted by the app shell, never by
/// this widget. Replay and first viewing cannot grant campaign rewards.
class CompanionArrivalScreen extends StatelessWidget {
  const CompanionArrivalScreen({
    required this.recruitment,
    required this.onContinue,
    this.replay = false,
    this.saving = false,
    this.errorMessage,
    this.backgroundAsset = 'assets/expedition/r1-trail.png',
    super.key,
  });
  final CompanionRecruitment recruitment;
  final VoidCallback onContinue;
  final bool replay;
  final bool saving;
  final String? errorMessage;
  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
    final profile = companionProfileById(recruitment.characterId)!;
    return _CompanionFrame(
      backgroundAsset: backgroundAsset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 340;
          final portraitWidth = constraints.maxWidth * .32;
          return Padding(
            padding: EdgeInsets.all(compact ? 12 : 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: portraitWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _ink.withValues(alpha: .93),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          replay ? '첫 만남 다시 보기' : '구조한 동료',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _paper,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: CompanionPortrait(
                            profile: profile,
                            size: compact ? 170 : 220,
                          ),
                        ),
                      ),
                      Text(
                        '${profile.letter} · ${profile.name}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(color: _ink, blurRadius: 8)],
                        ),
                      ),
                      Text(
                        recruitment.expeditionRole,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _paper,
                          shadows: [Shadow(color: _ink, blurRadius: 5)],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _paper.withValues(alpha: .97),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2CAA0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33153629),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'R${recruitment.regionNumber} 탐험 · ${recruitment.location}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _gold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  recruitment.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  recruitment.story,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.55,
                                    color: _muted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAE9D7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '“${recruitment.dialogue}”',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.45,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                                if (errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      errorMessage!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF973B34),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          key: const Key('companion-arrival-continue'),
                          onPressed: saving ? null : onContinue,
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            saving
                                ? Icons.hourglass_top_rounded
                                : Icons.explore_outlined,
                            size: 18,
                          ),
                          label: Text(
                            saving
                                ? '기록하는 중'
                                : replay
                                ? '동료 도감으로'
                                : '함께 탐험하기',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CompanionFrame extends StatelessWidget {
  const _CompanionFrame({required this.child, this.backgroundAsset});
  final Widget child;
  final String? backgroundAsset;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFDDE8D5),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFCADCCE), Color(0xFFEBE1C8)],
            ),
          ),
        ),
        if (backgroundAsset != null)
          Image.asset(
            backgroundAsset!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        if (backgroundAsset != null)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x33204433), Color(0x663E5C42)],
              ),
            ),
          ),
        SafeArea(child: child),
      ],
    ),
  );
}
