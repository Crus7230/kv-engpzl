import 'package:flutter/material.dart';

import '../../companions/data/companion_catalog.dart';
import '../../companions/domain/companion_models.dart';
import '../../progress/domain/progress_models.dart';

const _ink = Color(0xFF183E35);
const _paper = Color(0xFFFFFAEC);
const _gold = Color(0xFFE3B968);
const _firstStageId = 'r01-c01-s01';

/// Presentation-only onboarding. The parent persists the selected player,
/// starts/resumes the real first stage and confirms departure transactionally.
/// Browsing profiles never grants companions or edits existing progress.
class ExpeditionOnboardingScreen extends StatefulWidget {
  const ExpeditionOnboardingScreen({
    required this.save,
    required this.onChoosePlayer,
    required this.onStartTutorial,
    required this.onDepart,
    this.saving = false,
    this.errorMessage,
    this.onSettings,
    super.key,
  });

  final SaveEnvelopeV1 save;
  final ValueChanged<String> onChoosePlayer;
  final VoidCallback onStartTutorial;
  final VoidCallback onDepart;
  final bool saving;
  final String? errorMessage;
  final VoidCallback? onSettings;

  @override
  State<ExpeditionOnboardingScreen> createState() =>
      _ExpeditionOnboardingScreenState();
}

class _ExpeditionOnboardingScreenState
    extends State<ExpeditionOnboardingScreen> {
  String _selectedId = 'CHAR_D';

  int get _phase => widget.save.playerCharacterId == null
      ? 0
      : widget.save.completedStageIds.contains(_firstStageId)
      ? 2
      : 1;

  CompanionProfile get _profile =>
      companionProfileById(widget.save.playerCharacterId ?? _selectedId) ??
      companionProfiles.firstWhere((profile) => profile.id == 'CHAR_D');

  @override
  Widget build(BuildContext context) {
    final phase = _phase;
    final profile = _profile;
    final resume = widget.save.activeSession != null;
    final title = switch (phase) {
      0 => '나의 탐험가를 골라요',
      1 => '첫 문제로 탐험을 연습해요',
      _ => '이제 평원으로 출발해요',
    };
    final action = switch (phase) {
      0 => '이 탐험가로 시작',
      1 => resume ? '첫 문제 이어서 풀기' : '첫 문제 풀어보기',
      _ => '계산의 평원으로 출발',
    };
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/expedition/r1-trail.png',
              fit: BoxFit.cover,
              cacheWidth: 2048,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFF477566)),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xD9183E35), Color(0x88183E35)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        if (widget.onSettings != null)
                          IconButton(
                            onPressed: widget.onSettings,
                            tooltip: '음악·효과음 및 접근성 설정',
                            color: _paper,
                            icon: const Icon(Icons.settings_outlined),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _paper,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${phase + 1} / 3 · 탐험 준비',
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _paper.withValues(alpha: .97),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _gold.withValues(alpha: .6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            if (widget.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  widget.errorMessage!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFA33127),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: phase == 0
                                  ? _selection(profile)
                                  : _preparation(profile, phase, resume),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('onboarding-primary-action'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _ink,
                        disabledBackgroundColor: const Color(0xFFA3A994),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: widget.saving
                          ? null
                          : switch (phase) {
                              0 => () => widget.onChoosePlayer(profile.id),
                              1 => widget.onStartTutorial,
                              _ => widget.onDepart,
                            },
                      child: widget.saving
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _ink,
                              ),
                            )
                          : Text(
                              action,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
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
  }

  Widget _selection(CompanionProfile profile) => LayoutBuilder(
    builder: (context, constraints) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: constraints.maxWidth < 620 ? 204 : 232,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '26명 중 한 명을 선택해요',
                style: TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: GridView.builder(
                  key: const ValueKey('onboarding-player-grid'),
                  padding: const EdgeInsets.only(right: 4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    childAspectRatio: .94,
                  ),
                  itemCount: companionProfiles.length,
                  itemBuilder: (context, index) {
                    final candidate = companionProfiles[index];
                    final selected = candidate.id == _selectedId;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: '${candidate.letter} ${candidate.name} 탐험가 선택',
                      child: Material(
                        color: selected
                            ? const Color(0xFFFFE8AC)
                            : const Color(0xFFE8EFE1),
                        borderRadius: BorderRadius.circular(11),
                        child: InkWell(
                          key: ValueKey('onboarding-player-${candidate.id}'),
                          borderRadius: BorderRadius.circular(11),
                          onTap: widget.saving
                              ? null
                              : () => setState(() {
                                  _selectedId = candidate.id;
                                }),
                          child: Stack(
                            children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: _Portrait(
                                    profile: candidate,
                                    size: 54,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                  right: 3,
                                  top: 3,
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 17,
                                    color: _ink,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('onboarding-player-detail'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Portrait(profile: profile, size: 86),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile.letter} · ${profile.name}',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '선택한 한 명이 나의 주인공이 돼요.\n다른 동료는 탐험하며 구해요.',
                            style: TextStyle(
                              color: Color(0xFF546C5E),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _fact('MBTI', profile.mbti),
                _fact('좋아하는 음식', profile.favoriteFood),
                _fact('좋아하는 수학', profile.favoriteMathField),
                _fact('좋아하는 숫자', profile.favoriteNumber),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _preparation(CompanionProfile profile, int phase, bool resume) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 130,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _Portrait(profile: profile, size: 112),
              const SizedBox(height: 4),
              Text(
                profile.name,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                '나의 탐험가',
                style: TextStyle(color: Color(0xFF546C5E), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: SingleChildScrollView(
          child: phase == 1
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resume
                          ? '멈춘 보드와 식부터 이어서 풀어요.'
                          : '설명만 읽지 않고 실제 첫 문제를 풀어요.',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _instruction(
                      Icons.swap_horiz_rounded,
                      '1 · 이웃한 보석 교환',
                      '옆에 붙은 보석 두 개를 바꿔 같은 색을 세 개 이상 이어요.',
                    ),
                    _instruction(
                      Icons.diamond_outlined,
                      '2 · 필요한 조각 발굴',
                      '매치로 봉인을 풀어 숫자와 연산 기호를 찾아요.',
                    ),
                    _instruction(
                      Icons.functions_rounded,
                      '3 · 문장을 식으로',
                      '질문의 관계를 생각하며 찾은 조각으로 식을 완성해요.',
                    ),
                    const Text(
                      '힌트와 쉬운 보드를 써도 탐험은 계속돼요.',
                      style: TextStyle(color: Color(0xFF546C5E), fontSize: 11),
                    ),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '첫 번째 관계를 찾았어요.',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '보석을 연결하고, 조각을 발굴하고, 문장을 식으로 풀면 막힌 길이 열려요. 계산의 평원에서 다음 흔적을 찾아보세요.',
                      style: TextStyle(color: _ink, fontSize: 13, height: 1.5),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '챕터의 구조 지점에 도착하면 알파벳 동료를 구할 수 있어요. 평원에서는 C01·C03·C05 마지막 문제 뒤에 만나요. 선택한 주인공은 다시 구조하지 않아요.',
                      style: TextStyle(
                        color: Color(0xFF546C5E),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ],
  );

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value),
        ],
      ),
      style: const TextStyle(color: _ink, fontSize: 12, height: 1.35),
    ),
  );

  Widget _instruction(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 25, color: const Color(0xFF457354)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF546C5E),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.profile, required this.size});
  final CompanionProfile profile;
  final double size;

  Widget _letter() => Center(
    child: Text(
      profile.letter,
      style: TextStyle(
        color: _ink,
        fontWeight: FontWeight.w900,
        fontSize: size * .7,
      ),
    ),
  );

  Widget _legacy() => Image.asset(
    profile.legacyAsset,
    cacheWidth: (size * 2).round(),
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => _letter(),
  );

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: profile.expeditionAsset == null
        ? _legacy()
        : Image.asset(
            profile.expeditionAsset!,
            cacheWidth: (size * 2).round(),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _legacy(),
          ),
  );
}
