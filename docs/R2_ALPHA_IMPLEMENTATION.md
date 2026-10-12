# R2 숲 탐험 확장 — 소스 구현

## 범위와 현재 상태

2026-10-12에 R2 C01~C06 각 10개, 총 60개 문항과 진행 경로를 소스에 추가했습니다. 활성 카탈로그는 R1 60개와 R2 60개이며 R3~R7의 300개는 계속 `planned`입니다. 현재 APK와 GitHub 릴리즈에는 이번 변경이 포함되지 않습니다.

첫 소스 작업은 코드 수정만 수행했고, 이후 사용자 승인으로 2026-10-12 Flutter 분석·전체 테스트·웹 실행과 프리뷰 캡처까지 검증했습니다. APK 빌드·커밋·푸시·릴리즈는 수행하지 않았습니다. `playable` 등록과 자동 테스트 통과는 사람 플레이 난도 보정이나 Android 출시 검증을 뜻하지 않습니다.

## 문항과 난도

| 챕터 | 수학 내용 | 퍼즐 진행 |
|---|---|---|
| C01 | 일정 증가·감소, 간격 추론, 번째 수에서 간격 횟수, 예측 비교 | R1에서 배운 직선·L/T·5매치 파워와 1개 장애물; 1층 봉인 |
| C02 | 두 배·반, 증가량 교대, 연산 교대, 짝 반복, 매번 두 단계를 적용하는 규칙 | C01과 같은 물리 규칙; 수학을 배울 때 보드 복잡도를 올리지 않음 |
| C03 | 입력→출력, 역연산, 장치 순서와 괄호, 증가하는 차이, 네모·층별 배열 | C01/C02와 같은 물리 규칙 |
| C04 | 실제 일지·시간표·작업 이력으로 C01 S06~C02 S05 복습 | S01 2층 봉인 학습, S06 파워 조합 학습; 앞 수학 원본과 연결 |
| C05 | 보급·생산·영수증·조립 절차로 C02 S06~C03 S05 전이 | 2층 봉인·파워 조합·장애물 2개; S06에서 내구도 2 도입 |
| C06 | 평원 보급·화단과 숲의 규칙 연결, 다음 지역으로 향하는 탐험 기록 | 기존 규칙 조합, 내구도 2 장애물 3개; S01은 익숙한 쉬운 수학 |

60개 모두 실제 문장, 고유 ID 토큰, 의도한 답 AST, 관찰→관계→부분식 힌트, 오개념 피드백, 2단계 해설, 전이 질문, 접근성 텍스트를 제공합니다. 전체 문장은 정적 검사 기준 73자 이하이며 숫자 기록을 포함합니다. 복습 30개는 원본 순서를 유지하면서 일지·영수증·절차 등 실제 상황과 표현을 바꾸었습니다. 숫자나 명칭만 바꾼 것을 독립 학습으로 취급하지 않습니다.

수열과 입출력은 현재 `textRecord` 렌더러로 제공합니다. 표·도형의 그래픽 렌더러를 구현했다고 표시하지 않습니다. 유한 수열의 가능한 규칙이 하나뿐이라고 가정하지 않도록 적용할 규칙 또는 동일 간격 조건을 명시합니다. 실제 사용자 검토로 문항의 모호성·재미·난도를 보정해야 합니다.

R2 C06의 R1 관계 재사용은 `reinforcedSkillIds`로 연결하되, 기본 학습 증거는 R2의 해당 개념에 남습니다. 정원·동료 합류나 보드 성공이 별도의 R1 숙련·지연 복습 증거를 만들지는 않습니다.

## 연결된 제품 흐름

`R1 C03 S10 완료 → 월드맵에서 숲 진입 → 챕터 탐험 → 발굴·식 조립 → 해설 → 탐험 흔적 → 동료 합류 → 복습 또는 다음 스테이지`

- R1 C04~C06을 먼저 전부 완료할 필요 없이 R2 핵심 탐험을 시작할 수 있습니다.
- 지역 지도 안의 ‘다음 탐험’은 선택한 지역의 미완료 경로를 우선합니다. 월드맵의 추천은 전체 캠페인의 다음 핵심 경로를 사용합니다.
- 복습은 같은 일일 추천/학습 엔진을 사용합니다. 최초 완료 보상과 재도전의 학습 기록을 분리합니다.
- R2에 6개 탐험 목적지와 24개 흔적 지점을 연결했습니다. 표식은 무료로 변경할 수 있습니다.
- B·F는 C01 S10, R은 C03 S10, N은 C05 S10 완료 후 확정 합류합니다. 원본 캐릭터 정보와 기존 이미지, 동료 도감을 사용합니다.
- 숲 배경은 해상도 독립 `CustomPainter`로 구현했습니다. 비트맵·의존성을 추가하지 않았고 기존 보관 에셋 팩 ID/해시는 변경하지 않았습니다.
- 이동 잠금·포털·컨베이어는 여전히 미지원입니다. R2 활성 보드에는 구현된 파워·봉인·덩굴만 사용합니다. 원래 설계 청사진의 잠금 슬롯은 실행 콘텐츠와 구분해 보존했습니다.

## 저장 호환성

`saveEpoch=expedition-1`, 저장 스키마, 기존 스테이지/토큰/fixture ID와 R1 문제를 유지했습니다. `CampaignContentUpdateService`는 완료한 문제의 새로 작성된 후속 경로를 다시 확인하여 누락된 해금 ID만 합칩니다. 완료·별·학습 증거·복원·장식·일일 기록·현재 보드와 작성 중인 식을 초기화하지 않습니다. 이전 R1 checkpoint의 v1 규칙 재생도 유지합니다.

스키마 버전 변경이나 별도 데이터 초기화가 필요한 변경은 아닙니다. R3~R7 해금 ID가 과거 기록에 있어도 작성되지 않은 스테이지는 실행할 수 없습니다.

## 수정 위치

- `lib/features/campaign/data/r2_authored_content.dart`: 60개 실제 문제와 복습 원본 연결. 기존 R1 작성기와 `part`로 결합하여 토큰/학습 지원 생성 로직을 재사용합니다.
- `r2_board_progression.dart`, `r1_authored_campaign.dart`, `initial_campaign.dart`: R1/R2 활성 overlay와 물리/수학 난도 분리.
- `lib/features/discovery/data/discovery_runtime_catalog.dart`, `renewed_discovery_fixture.dart`: 런타임 등록 및 2층 봉인 학습 경로.
- `lib/features/progress/domain/campaign_content_update_service.dart`, `campaign_access_policy.dart`: 추가 해금과 지역 진입 게이트.
- `lib/features/exploration/`, `lib/features/garden/`, `lib/features/companions/`, `lib/app/math_adventure_app.dart`: 지역별 지도·흔적·결과·동료 연결.

## 실행 검증 결과

`flutter analyze --no-pub`는 이슈 0개, `flutter test --no-pub --reporter expanded`는 556개 통과·1개 제외였습니다. 제외 항목은 공개 릴리즈 JSON과 예상 메타데이터를 별도로 요구하는 배포 검증입니다. 로컬 분석·전체 테스트 결과는 `build/r2-full-verification.log`에 남았습니다.

다음 항목이 전체 테스트에 포함되어 통과했습니다.

- `r2_authored_content_test.dart`: 60개 문장/AST/지원, 30개 독립 복습, 청사진 ID/seed 보존, 전체 validator, 난도 분리, 지역 게이트.
- `r2_progress_update_test.dart`: 이전 기록을 유지하는 추가 해금, 120회 완료 transaction, 중복 방지, 48개 흔적, 동료 순서, 다음 날 복습.
- `r1_runtime_test.dart`: R1/R2 120개 × 5×5/6×6, 총 240개 fixture의 실제 교환·답 AST·정확한 세션 재생 검사로 확장.
- `r2_product_loop_test.dart`: 이전 R1 29개 완료 기록에서 C03 S10을 실제 교환·식 제출로 완료→R2 해금→실제 R2 퍼즐→작성 중인 식과 보드 저장→앱 재생성 시 동일 attempt/세션 복원→흔적→다음 스테이지. 800×360/720×320/680×300/960×432의 100%/130% 지도 배치.
- `quiz_readability_test.dart`: R1/R2 전체 120개 질문이 680×300, 텍스트 100%/130%에서 질문 영역 스크롤 없이 표시되는지 검사.
- `r2_preview_capture_test.dart`: 위 4개 크기·2개 텍스트 배율에서 숲 지도 전후·괄호 문제의 실제 Flutter 래스터 24장 생성. Android 캡처나 승인된 golden이 아닙니다.
- 기존 R1/동료/제품 흐름 테스트의 ‘R2 미작성’ 가정을 ‘R3 미작성’으로 갱신했습니다.

초기 실행에서 확인하고 수정한 사항:

- 특수 파워 테스트의 사용자 정의 동등성 객체를 담은 const set과 R2 테스트의 누락 import를 수정했습니다.
- L/T 도입의 곱셈 후 뺄셈은 이전에 배운 관계입니다. 더 쉬운 중간 문제 이후 이를 새 수학 부하로 오인하던 검사를 수정했습니다. 실제 앞선 source와 tier·연산 수·연산 종류·괄호·연산 순서를 확인하며, 새로운 구성 난도가 보드 난도와 함께 상승하는 경우는 계속 거부합니다. 문항/정답을 바꾸거나 검사 자체를 비활성화하지 않았습니다.
- 도래 복습은 같은 skill의 본 문제보다 source-linked 복습을 우선하고, 일반 복습 챕터 완료 후에는 그 지역의 다음 문제로 이어집니다. 일일 복습 완료 후 본 경로 추천과 R1 C03 관문 이후 R2 진입은 유지합니다.
- 이전 25개 완료 기록은 당시 legacy 규칙으로 만든 저장 fixture에서 현 규칙으로 이어가는 방식으로 검증했습니다. 현재 규칙의 필수 학습 단계를 테스트에서 우회하지 않습니다.
- 날짜에 의존하던 복습 fixture를 고정 날짜로 바꾸고 UI 갱신/저장 flush를 기다리도록 테스트를 보완했습니다.

이번 검증 과정에서 수정한 파일:

- 실행 코드: `lib/app/math_adventure_app.dart`, `lib/features/campaign/domain/campaign_validator.dart`, `lib/features/progress/domain/daily_route_service.dart`, `lib/features/discovery/presentation/stage_session_controller.dart`.
- 프리뷰 진입점: `tool/r2_preview.dart` (신규).
- 통합/캡처 테스트: `test/r2_product_loop_test.dart`, `test/r2_preview_capture_test.dart` (신규), `test/discovery_motion_preview_test.dart`.
- 회귀 테스트: `test/features/campaign/r1_board_progression_test.dart`, `test/features/discovery/renewed_powers_test.dart`, `test/features/discovery/quiz_readability_test.dart`, `test/features/progress/progress_repository_test.dart`, `test/features/progress/r1_complete_progress_test.dart`, `test/features/progress/r1_daily_progress_test.dart`.
- 문서: `README.md`, 이 문서, `docs/R1_PUZZLE_PROGRESSION_V3.md`.

원본 Kotlin 파일·에셋·저장 키를 변경하거나 파일을 삭제하지 않았습니다. 상위 Git 메타데이터의 `C:/grus.py` 경로 오류로 status/diff는 확인하지 못했고, 커밋·푸시는 하지 않았습니다.

## 웹 프리뷰

실행 명령 (`2026Renewal`):

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8769 -t tool/r2_preview.dart
```

`tool/r2_preview.dart`는 debug 전용이며 R1 코어 30개 완료 예시를 넣어 R2를 바로 살펴볼 수 있게 합니다. 키에 `r2-validation.` 접두어를 사용하므로 실제 진행 저장 공간과 격리됩니다. `lib/main.dart`의 신규 설치·필수 튜토리얼은 변경하지 않았습니다.

인앱 브라우저에서 월드맵→R2 숲 지도→문제 안내→퍼즐 진입을 확인했습니다. 실제 교환 후 이동 수가 20→19로 줄고 제거/낙하가 진행되었으며, 숫자 6을 식에 배치한 다음 새로고침→저장된 탐험 이어하기에서 같은 보드·이동 19회·초안 6이 복원되었습니다. 확인 시 브라우저 콘솔 warn/error는 없었습니다. 웹 JPG 캡처와 Flutter 모의 화면 PNG는 `build/previews/r2/`에 구분해 저장했습니다.

240개 등록 fixture의 결정적 풀이와 세션 재생은 통과했지만, 임의 seed 1,000개 검증·가족 관찰·실제 Android 강제 종료 복원·60fps/profile 성능·문항 재미와 난도 보정은 별도입니다. 기존 공개 APK와 보관 에셋은 변경하지 않았습니다.

## 월드맵 중심 레이아웃 개선 (2026-10-12)

월드맵 하단의 전폭 추천 카드 3개를 48px 높이의 플로팅 버튼으로 바꿨습니다. 기억의 씨앗은 도래 복습, 오늘의 탐험은 저장된 시도 또는 다음 본 스테이지, 탐험의 흔적은 이미 획득한 지점의 표현 변경 기능을 그대로 호출합니다. 상세 문구와 주간 발걸음은 길게 누르는 툴팁과 화면 읽기 안내에 유지합니다. 진행·보상·저장 형식과 에셋은 바꾸지 않았습니다.

800×360, 글자 100%, 상태 안내가 없는 기본 화면에서 지도 그림은 약 574×231에서 756×304로 커졌습니다. 지도를 자르거나 늘이지 않고 원본 비율과 7개 지역의 상대 위치를 유지합니다. 높이가 매우 짧거나 저장 상태 안내가 있는 경우에는 최소한의 하단 공간을 확보하여 지역 버튼을 가리지 않습니다. 이용할 수 없는 추천 버튼은 비활성 색상으로 구분합니다.

- 수정 코드: `lib/features/garden/presentation/garden_screens.dart`.
- 추가 테스트: `test/world_map_layout_test.dart`의 14개 검사. 지정 4개 크기 × 글자 100%/130%, SafeArea, 상태 안내, 7개 지역/3개 버튼의 비겹침, 48px 터치 높이, 버튼별 콜백, 상세 툴팁과 비활성 접근성을 검사합니다.
- 캡처: `test/r2_preview_capture_test.dart`에 월드맵을 추가해 총 32개 모의 화면을 생성합니다. `test/r1_complete_product_loop_test.dart`의 후속 R2 스테이지 상세 검사는 카드 본문 대신 툴팁과 전달 데이터를 확인합니다.
- 최종 검증: `flutter analyze --no-pub` 이슈 0개, `flutter test --no-pub --reporter expanded` 570개 통과·1개 배포 검증 제외. 로그는 `build/world-map-full-verification-final.log`에 있습니다.
- 웹: 기존 `http://127.0.0.1:8769/`에서 `tool/r2_preview.dart`를 재실행해 월드맵→R2→월드맵, 플로팅 버튼→저장된 탐험 안내를 확인했습니다. 800×360/680×300 JPG 캡처는 `build/previews/r2/world-map-floating_*_web.jpg`입니다. 실제 Android 캡처는 아닙니다.

computer-use 스킬의 브라우저 절차에 따라 실행 화면을 확인하고 캡처했으며, 임시 화면 크기 설정은 복원했습니다. APK 빌드·릴리즈·커밋·푸시·데이터 삭제는 수행하지 않았습니다.
