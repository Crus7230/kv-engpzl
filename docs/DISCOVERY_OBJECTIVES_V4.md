# 조건형 발굴 퍼즐 v4

## 목적과 범위

2026-10-12 소스 변경이다. 기존 인접 교환·특수 블록·수학 문항은 유지하고 풀이 조각의 획득 경로와 복합 완료 조건을 확장했다. 앱 버전·저장 epoch·에셋 팩은 변경하지 않았다. APK 빌드·릴리즈·프리뷰 갱신은 하지 않았다.

## 획득 경로와 완료 판정

- 기존 봉인: 해당 칸의 매치 또는 특수 타격으로 발굴한다.
- 얼음: 풀이 조각을 숨긴 고정 칸이다. 교환·매치·낙하가 통과할 수 없고, 인접 매치 또는 직접 특수 타격으로 연쇄당 한 층만 손상된다. 마지막 층이 깨지면 숨은 조각을 보관함에 지급한다.
- 낙하 조각: 시작 보드에는 없다. 유효 교환 2회 이후 상단에서 보충되는 일반 보석에 실려 내려온다. 그 보석을 매치하거나 특수 블록으로 제거해야 조각을 얻는다. 등장 자체는 획득이 아니다. 고정 장애물 아래에서 조각이 순간 생성되지는 않는다.
- 색상 목표: 실제 제거된 해당 색의 보석을 센다. 무효 교환은 진행을 올리지 않으며, 목표 달성 보상은 고유 토큰 ID로 한 번만 지급한다.
- 복합 목표: 색상·얼음·낙하 조각·기존 장애물·특수 활성 조건을 모두 충족해야 발굴이 완료된다. 식을 먼저 조립했어도 목표가 남아 있으면 정답 판정을 열지 않는다.

`DiscoveryObjective`는 색상 제거, 얼음 파괴, 장애물 제거, 유효 이동 조건을 표현한다. `DiscoveryTargetDrop.requiredObjectiveIds`로 여러 조건 충족 후 낙하시키는 설정도 지원한다. 현재 작성된 낙하 수업은 유효 이동 2회를 사용하고, 색상 수업은 목표 달성 즉시 조각을 지급한다.

## R1·R2 도입 순서

두 리전의 기존 실제 문항을 그대로 사용하며 C04~C06의 source-linked 복습/응용에 연결했다. 미작성 R3~R7은 활성화하지 않았다.

| 구간 | 새 획득/목표 |
|---|---|
| C01~C03, C04 S01 | 기존 v3 수준의 보드 규칙 유지 |
| C04 S02~S03 | 얼음 속 조각 소개 |
| C04 S04~S07 | 얼음과 2회 교환 후 낙하 조각 |
| C04 S08~S10 | 파란 보석 9개와 얼음 |
| C05 | 파란 보석 12개 + 토큰 수에 따라 얼음/낙하 경로 조합 |
| C06 | 파란 보석 20개와 초록 보석 12개를 모두 제거 + 얼음/낙하·기존 효과 |

토큰 manifest의 조각 수가 적으면 모든 획득 방식을 한 문제에 넣지 않는다. 예를 들어 발굴 조각 두 개인 문제는 색상 보상과 얼음, 세 개인 문제는 색상 보상·얼음·낙하를 구성한다. 숫자나 식의 구조를 바꿔 퍼즐 목표를 맞추지 않는다. 사람 플레이로 수량과 이동 예산을 보정하는 작업은 남아 있다.

## 보드 밀도와 화면

- 확장 구간에서는 800×360 이상일 때 7×7, 그보다 작은 화면에서는 6×6을 선택한다.
- 초반과 첫 설치 튜토리얼의 5×5/6×6 정책은 유지한다.
- 보드의 실제 칸을 줄이거나 숨기지 않고 같은 패널에 더 작은 타일을 배치한다.
- 목표는 보드 상단에 진행 수와 완료 표시로 보여준다. 얼음과 이동 중 조각은 다른 외형 및 접근성 설명을 사용한다.
- 680×300/800×360, 글자 100%/130% 회귀 테스트를 추가했지만 이번 턴에 Flutter 화면 테스트는 실행하지 않았다. 작은 타일의 실제 조작 가능성도 기기에서 확인해야 한다.

## 저장 호환성

앱의 새 시도는 `rulesVersion: 4`로 기록한다. 기존 v1·v3 체크포인트는 원래 카탈로그·크기·fixture로 재생한다. 테스트/도구가 명시하지 않은 컨트롤러는 기존 v3 기본값을 유지하며, 제품 앱에서만 새 시도의 v4를 선택한다.

v4 체크포인트는 기존 항목에 색상별 제거 수, 목표 진행도, 파괴한 얼음 수, 대기 중 낙하 조각, 현재 운반 중인 조각 ID를 추가한다. 유효 교환을 재생해 동일한 RNG·목표·조각 상태를 확인하며, 알 수 없는 버전은 거부한다. 완료 기록·별·동료·탐험 흔적을 초기화하거나 저장 키를 변경하지 않는다.

## 검증 결과와 경계

- `dart format`: 변경 소스/테스트 구문·포맷 확인.
- `dart tool/verify_excavation.dart`: R1·R2 120개 × 5×5/6×6, 확장 구간 58개의 7×7을 합쳐 298개 기준 경로 통과. 각 목표·조각 획득·W 이동 예산과 두 엔진의 결정적 재생 확인.
- 같은 도구의 계약 검사에서 복합 AND, 실제 색상 제거 수, 보상 단일 지급, 얼음 고정 및 연쇄별 타격 제한, 무효 교환과 지연 등장, 운반 보석 제거 후 획득을 확인했다.
- `dart tool/verify_r1_runtime.dart`: 기존 v3 R1 60개/120개 fixture 경로 통과.
- 일반 `dart analyze`는 분석 서버의 `AppData/Local/Dart/perf` 종료 권한 오류로 두 번 실패했다. 기존 Flutter 도구에 설치된 analyzer 라이브러리를 직접 호출한 `build/verification/analyze_excavation.dart`로 관련 21개 Dart 파일을 분석했고 진단 0개였다. 새 의존성은 설치하지 않았다.
- 신규 Flutter 회귀 파일 `test/features/discovery/excavation_objectives_test.dart`: 복합 AND, 색상 보상 중복, 얼음의 한 연쇄 한 타격, 무효 교환, v4 세션 복원과 저높이 배치를 작성했다. 기존 R1/R2 제품 흐름 검사는 실행 중 세션의 정확한 reference path를 사용하도록 수정했다.

이번 변경의 `flutter analyze`, `flutter test`, `flutter run`, `flutter build`는 실행하지 않았다. 따라서 Flutter 전체 회귀·UI/모션·실제 Android 저장 복원·사용자 체감 난도는 검증 완료로 표현하지 않는다.

후속 승인 후 실행할 명령:

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8769 -t tool/r2_preview.dart
```

## 수정 위치

- 엔진과 목표: `lib/features/discovery/domain/discovery_models.dart`, `discovery_engine.dart`, `discovery_hint_solver.dart`.
- 작성/카탈로그: `lib/features/discovery/data/discovery_excavation_profile.dart`, `renewed_discovery_fixture.dart`, `authored_discovery_fixture.dart`, `discovery_runtime_catalog.dart`.
- 세션/화면: `lib/features/discovery/presentation/`의 ViewModel, 컨트롤러, 목표 표시, 얼음/조각 표현 및 모션 데이터.
- 제품 진입: `lib/app/math_adventure_app.dart`의 v4 및 7×7 복원 선택.
- 검증: `tool/verify_excavation.dart`, 신규 회귀 테스트와 기존 R1/R2 제품 흐름 테스트.

상위 Git의 `C:/grus.py` 경로 오류는 건드리지 않았다. 로컬 커밋·원격 푸시·기존 파일 삭제는 하지 않았다.
