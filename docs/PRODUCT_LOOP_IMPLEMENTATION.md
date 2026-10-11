# 일곱 수식 정원: 1차 제품 루프 구현

이 문서는 개발 체험만 연결한 1차 구현 기록이다. 이후 실제 R1 25개와 일일 흐름을 연결한 현재 상태는 [R1 알파 구현 기록](R1_ALPHA_IMPLEMENTATION.md)을 따른다.

## 목적과 범위

2026-10-11 승인한 로드맵의 첫 수직 슬라이스를 구현한다. 전체 앱 완성 또는 R1 콘텐츠 완성을 뜻하지 않는다. 별도 `prototype-bundle-add`를 사용하며, 정식 420개 캠페인 슬롯은 모두 `planned`로 유지한다.

`월드맵 → 계산의 평원 → 체험 안내 → 발굴·식 조립 → 결과·해설 → 장식 선택 → 정원 → 재실행`

첫 실행은 월드맵이다. 기존 7리전과 배경, CHAR_D·CHAR_J를 승계하고 개발 체험임을 명시한다. 한 문제를 완료해도 그날의 기록이 남는다. 출석 손실·생명·결제·광고·알림은 없다.

## 꿈의 정원 참고 구조

참고작은 비밀의 정원이 아니라 [꿈의 정원 Gardenscapes](https://play.google.com/store/apps/details?id=com.playrix.gardenscapes&hl=ko)이다. [공식 진행 설명](https://playrix.helpshift.com/hc/en/5-gardenscapes/faq/15571-about-the-game-how-to-play-gardenscapes/)의 퍼즐 완료와 정원·이야기 진행 분리를 참고한다. 그 앱의 별 소비·생명·유료 아이템 정책은 도입하지 않는다.

KVM은 세 책임을 분리한다. 발굴 퍼즐은 숫자·기호를 찾고, 수학 엔진은 문장의 관계와 정답 AST를 검증하며, 캠페인·정원은 확정된 완료 영수증으로 해금·복원을 표현한다. 매치만 끝내면 수학 완료나 복원 보상이 지급되지 않는다. 수학 별·탐색 별·힌트 사용과 무관하게 수학 문제를 지원받아 완료하면 기본 진행은 열린다.

현재는 질문·퍼즐·획득 조각·정답식이 동시에 보여야 한다는 가로 화면 요구에 따라 발굴과 수학 풀이를 한 화면의 세 영역에 배치했다. 결과·복원·월드맵은 별도 화면이다. 세 개의 완전히 독립된 게임 모드 또는 퍼즐만으로 새 리전을 여는 시스템을 구현한 것은 아니다. 정식 새 리전 해금은 기존 C03 S10 규칙을 사용하며 실제 콘텐츠 연결은 다음 단계다.

## 구조와 결정

| 책임 | 구현 |
|---|---|
| 화면 이동 | `MathAdventureApp`, typed `RenewalRoute`와 SDK `Navigator.pages` |
| 실행 콘텐츠 | `DiscoveryRuntimeCatalog`: authored/playable 상태와 등록된 runtime 모두 필요 |
| 중단·재시작 | `StageSessionController`: attempt ID, 매 상호작용 checkpoint, lifecycle 저장 |
| 저장 | `ProgressRepository`, `SaveEnvelopeV1`, `SharedPreferencesSaveStore` |
| 완료 | `StageCompletionService`, `StageAttemptResult`, `CompletionReceipt` |
| 하루 추천 | `DailyRouteService`: 도래 복습, 실행 가능한 탐험, 대기 복원 |
| 정원 | `GardenDefinition`, `RestorationNode`, 168개 지역 노드 정의와 독립 체험 노드 |

`shared_preferences`만 새 런타임 의존성으로 사용한다. 정원 선택은 캠페인·숙련·복습 간격을 변경하지 않는다. 장식 3종은 무료로 바꿀 수 있으며 복원은 최초 완료로만 열린다. 별은 소비하지 않고 최고 기록을 유지한다. 강제 튜토리얼은 독립 수학 숙련 증거로 인정하지 않는다.

### 저장과 복구

- 하나의 버전 JSON을 A/B 슬롯에 저장한다. 비활성 슬롯 기록과 정확한 readback 이후 pointer를 바꾼다.
- 최초 transaction 전에도 generation 0 체크포인트를 남긴다. 실패한 첫 보상을 미확정 슬롯에서 복구하지 않는다.
- 직렬 transaction으로 checkpoint, 완료, 장식 변경의 lost update를 막는다.
- 같은 `attemptId`는 같은 완료 영수증을 반환하고 보상·별·하루 기록을 다시 지급하지 않는다.
- 완료 직전 저장을 동결한다. 이미 ledger에 있는 attempt의 checkpoint는 세션을 되살리지 않는다.
- 보드 seed, fixture, 승인된 교환 기록, 실제 보드 스냅샷, 토큰, 작성 중인 식, 힌트·오개념·제출 증거를 함께 저장한다. 결정론적 재생 결과가 스냅샷과 다르면 복원을 거부한다.
- 복원 실패 시 반쯤 복원된 정답 상태를 남기지 않는다. 진행·정원은 보존하고 현재 퍼즐 초기화 여부를 사용자에게 묻는다.
- 미래 schema/content 버전과 양쪽 슬롯 손상은 자동 초기화하지 않는다.
- Renewal의 최초 persistent schema는 v1이다. Kotlin 저장 데이터를 자동으로 읽거나 변환하지 않는다. 기존 캠페인 v3→v4 ID/backfill 순수 Dart migration 검증은 별도로 유지한다.

## 에셋과 용량

기존 원본에서 4개만 선별 복사했다. 출처·SHA-256·크기·해상도·사용 화면은 `assets/asset_manifest.json`에 기록한다. 합계 7,578,177 bytes이며 배경 압축/해상도 최적화는 아직 하지 않았다. 원본·APK 이력·동결 JSON·SVG를 삭제하지 않았다. 정식 R1 제작과 실제 기기 성능 측정 후 파생 WebP/PNG가 필요하다.

런타임은 화면 크기와 기기 pixel ratio에 맞춘 이미지 디코드 크기를 요청한다. 원본 월드맵 6000px와 캐릭터 1500px를 작은 화면에서 항상 전체 크기로 디코드하지 않도록 했으며, 파일은 그대로 보존한다. 실제 메모리·프레임 개선량은 Android 측정 전까지 수치로 주장하지 않는다.

## 검증 방법

```powershell
cd "C:\grus.py\pythonProject\Grus Project\KVM\2026Renewal"
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

주요 회귀 범위는 저장 슬롯 실패·손상·미래 버전, concurrent/idempotent 완료, 실제 정원 milestone ID, due ticket 거부, planned 실행 차단, 5×5·6×6 정확한 세션 복원, 전체 화면 이동, 장식 저장과 재실행이다.

`test/preview_capture_test.dart`는 800×360, 720×320, SafeArea 적용 후의 가용 화면을 모사한 680×300, 960×432를 100%/130% 글자로 렌더링한다. PNG는 `build/previews`에 생성한다. Windows 한국어 폰트를 검증용으로 로드하며 배포 에셋으로 복사하지 않는다. 이는 Flutter 테스트 렌더링 캡처이며 Android 기기 캡처나 승인된 golden 기준이 아니다. Golden 기준은 화면 검토 후 별도로 승인해야 한다.

## 검증 경계와 다음 작업

- `flutter analyze`와 `flutter test` 64개, 기존 순수 Dart 검증기 11개를 통과했다. 실제 Chromium 웹에서 발굴→식 검증→최초 보상→허브 복원→재시작 후 2별·복원 유지도 확인했다.
- 웹 정수 shift 때문에 attempt ID 생성 범위가 0이 되는 문제를 실제 브라우저에서 수정했다. Chrome headless 자동 테스트는 초기 suite 로딩에서 진행되지 않아 중단했으며, Chrome 자동 검증 통과로 보고하지 않는다.
- Android 실기기가 연결되지 않아 강제 종료 복구, Android 화면, 60fps와 16.7ms/50ms 기준은 미검증이다. Web/테스트 결과로 대신 주장하지 않는다.
- 정식 R1 문항·source-linked 독립 복습은 아직 작성하지 않았다. 복습 카드가 준비 중인 이유이며 fixture를 독립 변형으로 재사용하지 않는다.
- 현재 보드 엔진은 단층 봉인만 지원한다. 2층 봉인·직선 파워·자동 섞기·쉬운 보드 지원은 다음 tranche의 검증 fixture와 함께 구현한다.
- 168개 복원 노드·26명 캐릭터의 정의와 실제 그림·이야기 구현은 다르다. 현재 실행되는 복원 노드는 체험 1개, 캐릭터는 2명이다.
- 성취 별, 무료 지원, 장식 선택이 진행에 영향을 주지 않는 원칙을 유지한다. 실제 학습 성취 향상과 가족 세션 길이는 아직 입증되지 않았다.

다음 tranche는 R1 C01 10개 → C02 S01~S05 5개 → 위 원본을 참조하는 C04 10개 순서로 진행한다. 각 묶음은 실제 문장·AST·고유 토큰·3단계 힌트·오개념·해설·전이 문제·접근성 설명·독립 의미 프로필·5×5/6×6 solver·사람 플레이 보정을 모두 갖춘 뒤에만 `playable`로 승격한다.
