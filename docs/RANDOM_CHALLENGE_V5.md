# 랜덤 발굴 퍼즐 v5

## 목적과 적용 범위

일반 스테이지가 한 번의 교환으로 끝나는 문제를 개선하고, 풀이 블록 발굴과 퍼즐 목표를 별도로 충족하도록 한다. R1·R2의 신규 시도에 적용한다. 최초 소스 작업에서는 버전·저장 epoch·에셋 팩을 변경하지 않았으며, 이후 0.1.7+8 APK로 공개했다. 저장 epoch·에셋 팩은 그대로 유지한다.

R1 C01 S01과 개발용 체험은 안내용 짧은 보드를 유지한다. 나머지 신규 시도는 이전 이동 한도가 20회 미만이면 18회, 기존 20회이면 20회를 제공한다. 수학 문장·AST·힌트·학습 판정은 변경하지 않는다.

## 완료 조건

`필수 풀이 블록 획득 AND 퍼즐 목표 달성 AND 올바른 수식 제출`

- C01~C04는 파란 보석 18개 제거, C05는 파란 보석 20개 제거, C06은 파란 보석 20개와 초록 보석 12개 제거를 요구한다.
- 기존 특수 블록 활성화·조합·장애물 제거 과제는 유지한다.
- 기존 C04 이후 배치 계획에 따라 얼음과 낙하 조각을 사용한다. 낙하 조각은 유효한 교환 4회 이후 보충되는 보석에 실리며, 실제 제거해야 획득한다.
- 색상 목표는 실제 제거된 보석 수를 사용한다. 연쇄·특수 블록의 제거도 포함하며 무효 교환은 진행이나 이동 수를 소모하지 않는다.
- 블록을 모두 획득하고 식을 작성했어도 퍼즐 목표가 남으면 식 확인은 열리지 않는다. 반대로 목표만 달성해도 필수 블록을 찾기 전에는 완료할 수 없다.
- 5~10회는 초반 플레이 길이의 설계 목표이지 최소 턴 잠금이 아니다. 좋은 연쇄로 빠르게 성공하는 경우를 억제하거나 목표를 뒤늦게 늘리지 않는다.

## 생성과 검증의 분리

1. 시도별 독립 seed로 시작 보석을 생성한다. 시작 시 이미 성립한 매치는 제외한다.
2. 풀이 블록·장애물·얼음의 위치를 탐색 결과와 무관하게 먼저 정한다. 조합 과제의 제공 특수 블록도 독립 위치에 놓는다.
3. 완성된 후보와 같은 고정 refill seed로 유효한 교환을 탐색한다.
4. 목표와 필수 블록을 모두 충족하는 경로가 확인된 후보를 채택한다. 검증 경로는 진단·회귀 검증 자료이며 입력을 제한하거나 자동 플레이하지 않는다.
5. 후보의 조각을 검증 경로의 제거 칸으로 옮기거나, 정답 모양을 보석에 심거나, 보충 순서를 해결 경로에 맞춰 변경하지 않는다.

탐색은 제한된 휴리스틱 검사이다. 경로 미발견을 수학적인 불가능 증명으로 취급하지 않는다. 최대 96개 독립 후보 중 경로를 확인할 수 있는 후보만 사용하며, 확인하지 못한 경우에는 진행을 보존하고 재시도를 안내한다. 인위적인 정답 경로를 만드는 구형 생성기로 대체하지 않는다. 검증된 시작 보드도 사용자의 선택에 따라 이동 부족 또는 막힌 보드로 실패할 수 있다.

새 예산은 W/P/L 14/16/18 또는 16/18/20이다. W는 발견한 검증 경로의 상한이며 최단 해법이 아니다. 보정과 사람 플레이 검증이 별도로 필요하다.

## 저장과 재도전

- `rulesVersion: 5`, 시도 seed, fixture ID, 유효한 교환 목록, 목표 진행·낙하 대기·보드·작성 중인 식을 기존 세션 형식으로 보존한다.
- 중단 후 복원은 저장 seed와 교환을 정확히 재생한다. 복원 중 seed를 다시 뽑지 않는다.
- 무료 재도전은 새 seed와 새 attemptId를 사용한다. 새 보드를 검증하기 전에는 현재 시도를 교체하지 않는다.
- v1·v3·v4 저장은 각각의 기존 카탈로그·규칙·이동 예산으로 이어진다. 새 규칙을 소급 적용하거나 진행을 초기화하지 않는다.
- 스테이지 ID, 캠페인·학습 진행, 최초 완료 보상과 중복 지급 방지 정책은 유지한다.
- 랜덤 시도별 fixture 캐시는 스테이지당 최근 4개로 제한한다. 재생성 결과는 같은 seed로 동일하다.

## 보드 밀도 확대

신규 v5 세션은 같은 보드 영역에 더 많은 칸을 배치한다. 질문·퍼즐 목표·획득 블록·작성 중인 식의 공간을 줄이지 않고 보석 크기와 칸 간격을 조정한다. 선택 기준은 실제 픽셀 해상도가 아니라 SafeArea를 제외한 가로 화면의 논리 크기이다.

| 조건 | 보드 |
|---|---|
| R1 C01 S01 튜토리얼·개발용 체험 | 5×5, 25칸 |
| 사용 가능 너비 600dp 미만 또는 높이 288dp 미만 | 5×5, 25칸 |
| 일반 스테이지 | 6×6, 36칸 |
| 기존 고밀도 대상인 C04 S02 이후·C05·C06, 사용 가능 영역 720×320dp 이상 | 7×7, 49칸 |

680×300에서는 일반·후반 모두 6×6이고, 800×360에서는 일반 6×6·후반 7×7이다. 고밀도 도입은 기존 복습·보드 효과 학습 배치를 따르며 수학 문장이나 난도를 동시에 올리지 않는다. 6×6·7×7의 칸 간격은 1dp이며 제목에 실제 보드 크기를 표시한다. 전체 칸을 스크롤 없이 배치하는 기존 구조를 유지한다.

진행 중인 세션은 저장된 행·열을 그대로 복원한다. 기존 5×5 세션을 임의로 확대하거나 진행 기록을 초기화하지 않는다. 같은 세션의 무료 재도전도 현재 크기를 유지하며, 새 스테이지 세션부터 변경된 선택 기준을 적용한다. v1·v3·v4의 기존 선택 기준은 변경하지 않는다.

## 힌트 표시 패치

힌트 버튼이 계속 다음 내용을 표시하기만 하고 닫기 상태가 없었다. 마지막 수학 힌트에서는 버튼도 비활성화되어 표시를 끌 수 없었다.

- 같은 전구 버튼이 `힌트 보기`와 `힌트 닫기`로 전환된다. 열려 있으면 보드 모션 중에도 닫을 수 있다.
- 닫으면 현재 블록·퍼즐 목표에 맞는 일반 안내로 돌아간다. 보드, 이동 수, 작성 중인 식은 변경하지 않는다.
- 마지막 수학 힌트도 닫았다가 다시 열 수 있다. 마지막 단계를 넘어서 힌트 수준을 증가시키지 않는다.
- 힌트를 닫아도 최고 수학 힌트 단계와 직접 경로 도움 사용 기록은 유지한다. 학습 지원을 사용하지 않은 시도로 바꾸지 않는다.
- 기존 저장의 힌트 문장으로 표시 상태를 복원한다. 저장 스키마·epoch를 변경하거나 진행을 초기화하지 않는다.
- 색상 목표를 진행하는 힌트는 봉인 발굴 경로와 구분해 안내한다. 풀이 식을 모두 놓았어도 목표가 남으면 남은 목표를 안내하고 확인 버튼을 잠근다.

## 변경 파일

- `lib/features/discovery/data/discovery_challenge_profile.dart`: 신규 시도의 목표·이동 예산·fixture 식별자.
- `lib/features/discovery/data/random_discovery_fixture.dart`: 탐색 전에 완료되는 독립 랜덤 배치와 해결 가능성 검사.
- `authored_discovery_fixture.dart`, `discovery_runtime_catalog.dart`: v5 생성 경로와 한정 캐시 연결.
- `engine_discovery_puzzle_view_model.dart`, `stage_session_controller.dart`: 새 규칙·seed·복원·재도전 및 이중 목표 표시.
- `lib/app/math_adventure_app.dart`, `lib/features/garden/presentation/garden_screens.dart`: 신규 세션 연결과 이동·목표 안내.
- `tool/verify_random_challenge.dart`: 랜덤 보드·복합 목표·동일 seed 재생 검사.
- `test/features/discovery/random_challenge_test.dart`: 저장 복원·구형 규칙·재도전·목표 우회 차단·저높이 화면 회귀 사례.

### 후속 검증·프리뷰에서 변경한 파일

- `lib/features/discovery/domain/discovery_hint_solver.dart`: 목표 진행 힌트에 실제 목표 명칭을 전달한다.
- `lib/features/discovery/presentation/engine_discovery_puzzle_view_model.dart`: 목표 미달 안내, 힌트 표시·닫기·마지막 단계 재열기 및 저장 복원.
- `lib/features/discovery/presentation/discovery_puzzle_view_model.dart`: 기존 인터페이스를 깨지 않는 선택적 `DiscoveryHintVisibility`와 개발용 모델 지원.
- `lib/features/discovery/presentation/discovery_puzzle_screen.dart`: 힌트 버튼의 열림·닫힘 상태와 활성 아이콘.
- `test/features/discovery/random_challenge_test.dart`: 색상 목표만 충족한 경우의 우회 차단, R1·R2의 양쪽 목표 달성 후 실제 수식 판정.
- `test/features/discovery/excavation_objectives_test.dart`: 목표 진행 힌트의 정확성과 상태 비변경 검증.
- `test/features/discovery/hint_visibility_test.dart`: 보드·마지막 수학 힌트 열기·닫기, 저높이 화면, 사용 기록과 저장 복원 검증.
- `test/random_preview_capture_test.dart`: 실제 v5 위젯의 시작·목표 달성·정답·힌트 열림/닫힘·R2 고밀도 보드 캡처.
- `tool/random_preview.dart`: 실제 앱을 사용하는 debug 전용 프리뷰 진입점. 별도 저장 키 접두사로 일반 플레이 기록과 분리한다.
- `README.md`, 이 문서: 검증 결과와 프리뷰 사용법을 기록한다.

### 보드 밀도 확대에서 변경한 파일

- `lib/features/discovery/data/discovery_challenge_profile.dart`: 신규 v5 전용 5×5·6×6·7×7 선택 기준.
- `lib/app/math_adventure_app.dart`: 신규 세션의 밀도 선택 연결. 저장 복원 분기는 유지.
- `lib/features/discovery/presentation/discovery_puzzle_screen.dart`: 작은 칸 간격, 실제 크기 제목과 검증용 grid key.
- `tool/verify_random_challenge.dart`: 화면 크기별 선택과 구형 규칙 유지 검사.
- `test/features/discovery/board_density_test.dart`: 480×270~800×360, 글자 배율 100%·130%에서 마지막 칸 표시·교환을 검사하는 12개 사례.
- `test/random_preview_capture_test.dart`: 고정 크기를 강제하지 않고 실제 신규 선택 기준으로 캡처하도록 수정.

## 보드 밀도 변경 전 검증

최초 코드 작업에서는 순수 Dart와 설치된 analyzer API로 검증했다. 후속 사용자 승인에 따라 `flutter analyze`, 전체 `flutter test`, `flutter run`을 실행하고 웹 UI를 직접 조작했다. APK 빌드·릴리즈·커밋은 수행하지 않았다.

| 검사 | 결과 |
|---|---|
| R1·R2 v5, 스테이지별 5×5·6×6 및 해당 7×7, seed 4종 | 1,192개 통과 |
| 기존 v4 경로와 목표·결정론적 재생 | 298개 통과 |
| 기존 R1 v3 문장·수식·fixture | 60문제, 120개 fixture 통과 |
| 수정·관련 Dart 소스 및 새 회귀 테스트 정적 검사 | 17개 파일, 진단 0개 |
| R1 C01 비튜토리얼 검사 경로 | 평균 9.07회, 범위 3~14회 |
| 가장 느린 이번 데스크톱 생성 | 전체 표본 776ms, 후속 smoke 912ms. 실제 Android 프로파일링이 아님 |
| 후속 현재 소스의 랜덤 smoke | 24개 보드, 양쪽 목표 및 동일 seed 재생 통과 |
| 후속 `flutter analyze --no-pub` | 힌트 닫기 패치 포함 진단 0개 |
| 최종 전체 Flutter 테스트, 힌트 닫기 포함 | 608개 통과, 공개 릴리즈 메타데이터 검증 1개 조건부 생략 |
| 힌트 닫기 후 관련 회귀·캡처 테스트 | 51개 통과 |
| v5 실제 위젯 캡처 | 800×360·680×300, text scale 100%·130%, 6개 상태 24장 생성 |
| 웹 UI 직접 검증 | 교환·색상 집계·식만 완성했을 때 확인 잠금·새 랜덤 재도전·보드/작성식 재실행 복원·힌트 열기/닫기 확인 |

경로 길이는 휴리스틱이 발견한 수순이며 최단 해법이나 사람의 실제 풀이 길이가 아니다. 전체 가능한 seed를 전수 검사했다는 의미도 아니다.

후속 smoke를 Flutter 검증과 함께 실행한 데스크톱에서는 최장 생성 시간이 1,684ms였다. 동시 실행 부하가 있는 수치이며 Android 성능이나 생성 대기 없는 동작을 보장하지 않는다.

## 보드 밀도 변경 후 검증 — 2026-10-13

- 설치된 analyzer API로 관련 소스·테스트 19개 파일을 검사했고 진단은 0개였다.
- 순수 Dart로 보드 선택 8개 조합과 구형 선택 기준을 검사했다. R1·R2 보드 298개에서 풀이 블록·목표 달성 및 같은 seed 재생을 확인했다.
- 이번 표본의 R1 C01 비튜토리얼 검증 경로는 평균 8.61회, 범위 4~13회였다. 최단 경로나 실제 사용자 풀이 길이로 해석하지 않는다.
- 가장 느린 데스크톱 생성은 1,437ms였다. 실제 Android 성능 검증은 아니다.
- `dart format`을 실행했다. 이번 밀도 변경 후에는 Flutter 명령을 실행하지 않았다. 위의 608개 테스트 결과와 24장 캡처는 밀도 변경 전 결과이며, 현재 화면의 검증 결과로 사용하지 않는다.
- 새 화면 회귀 테스트 12개는 작성·정적 검사만 완료했다. 작은 화면의 터치·가독성 및 갱신된 프리뷰는 별도 실행 승인 후 확인해야 한다.

이번 밀도 변경 후 실행한 검사 명령은 다음과 같다.

```powershell
& 'C:\tmp\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/verify_random_challenge.dart
& 'C:\tmp\flutter\bin\cache\dart-sdk\bin\dart.exe' --packages='C:\tmp\flutter\packages\flutter_tools\.dart_tool\package_config.json' build/verification/analyze_random_challenge.dart
```

## 실행한 명령

```powershell
& 'C:\tmp\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/verify_random_challenge.dart --seeds 4
& 'C:\tmp\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/verify_excavation.dart
& 'C:\tmp\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/verify_r1_runtime.dart
& 'C:\tmp\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/verify_campaign.dart
& 'C:\tmp\flutter\bin\cache\dart-sdk\bin\dart.exe' --packages='C:\tmp\flutter\packages\flutter_tools\.dart_tool\package_config.json' build/verification/analyze_random_challenge.dart
& 'C:\tmp\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/verify_random_challenge.dart --smoke
& 'C:\tmp\flutter\bin\flutter.bat' analyze --no-pub
& 'C:\tmp\flutter\bin\flutter.bat' test --no-pub --reporter expanded
& 'C:\tmp\flutter\bin\flutter.bat' test --no-pub --reporter compact
& 'C:\tmp\flutter\bin\flutter.bat' run -d web-server --web-hostname 127.0.0.1 --web-port 8769 --no-pub -t tool/random_preview.dart
```

수정 Dart 파일에 `dart format`을 실행했다. analyzer 도우미는 설치된 Flutter tools의 개발 의존성을 사용하는 로컬 검증 파일이며, 앱 의존성이나 배포 소스에 추가하지 않는다.

## 남은 확인

웹 프리뷰는 `http://127.0.0.1:8769/`에서 실행한다. 검증용 진행 기록은 `random-v5-preview.` 저장 구획에만 기록하며 튜토리얼 이후 R1 C01 S02부터 시험한다. 일반 앱의 첫 설치·튜토리얼·실제 진행 기록은 변경하지 않는다.

현재 실행 중인 웹 프리뷰와 기존 캡처에는 이번 보드 밀도 변경을 아직 반영하지 않았다. 검증 승인 후 `flutter analyze --no-pub`, `flutter test --no-pub`을 실행하고 현재 프리뷰 서버를 재시작 또는 hot restart해야 한다. 새 세션에서 밀도를 확인하며 저장된 기존 5×5 보드는 그대로 유지한다.

위젯 PNG와 웹 브라우저 JPG는 `build/previews/random-v5`에 생성한다. PNG는 고정 seed 42의 실제 Flutter 화면을 렌더링한 자료이며, 웹 JPG는 직접 플레이·복원·힌트 닫기 상태의 화면이다. 둘 다 실제 FHD Android 캡처가 아니다.

실제 Android의 생성 대기·프레임 성능·폰트·터치 영역·초반 체감 난도·실패율은 남아 있다. 위의 코드 작업 단계에서는 빌드·릴리즈하지 않았으며, 후속 사용자 요청으로 아래 배포를 완료했다. 원본·기존 APK·에셋을 삭제하거나 진행을 초기화하지 않았다.

## v0.1.7 릴리즈 검증 — 2026-10-13

밀도 변경 후 사용자 릴리즈 요청에 따라 `flutter analyze --no-pub` 진단 0개와 전체 `flutter test --no-pub --reporter expanded` 620개 통과를 확인했다. 공개 JSON 검사는 게시 후 별도 실행해 1개 통과했다. 새 밀도 테스트의 접근성 핸들을 테스트 종료 전에 해제하도록 수정했고, 480×270·글자 130%의 상단 난이도 문구 overflow를 폭 제한·전체 문구 Tooltip으로 보완했다. 밀도 화면 12개 사례와 실제 Flutter 캡처 24장을 갱신했다.

다운로드형 입력에서 `flutter pub get --offline`, `flutter build apk --release --no-pub -t lib/main.dart`를 실행했다. 빌드 소스 202개 SHA256, 기존 인증서·APK v2 서명·패키지·버전·SDK·ABI·가로 화면을 확인했고 보존 미디어 0개와 manifest 2개 해시를 검증했다. 공개 APK 단일 첨부와 로그인 없는 다운로드의 SHA256도 일치했다. 이전 웹 JPG와 실행 서버는 이번 릴리즈에서 갱신하지 않았다. 최종 설치·파일·검증 안내는 [v0.1.7 릴리즈 기록](RELEASE_NOTES_0_1_7.md)을 기준으로 한다.
