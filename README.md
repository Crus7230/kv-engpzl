# KV 수학탐험대 — R1 알파

매치 퍼즐에서 숫자와 기호를 발굴하고, 문장에 맞는 수식을 완성해 정원을 복원하는 Android 게임입니다. 기존 KVM을 Flutter/Dart로 재구성했습니다. 현재 계산의 평원(R1) 60개 스테이지를 플레이할 수 있으며, R2~R7은 `업데이트 예정`으로 닫혀 있습니다.

## 다운로드와 설치

[Android APK 다운로드 — v0.1.2 독립 설치용 R1 알파](https://github.com/Crus7230/kv-engpzl/releases/download/v0.1.2-r1-alpha/KVM-R1-0.1.2-alpha.apk)

[릴리스 안내와 파일 정보](https://github.com/Crus7230/kv-engpzl/releases/tag/v0.1.2-r1-alpha)

1. Android 휴대폰에서 위 APK를 다운로드합니다. GitHub의 `Code → Download ZIP`은 소스이며 설치 파일이 아닙니다.
2. 다운로드한 APK를 열고, 필요한 경우 다운로드에 사용한 브라우저 또는 파일 앱에만 출처가 다른 앱 설치를 허용합니다.
3. 설치 후 `KV 수학탐험대 2026`을 실행합니다. 가로 화면에서 R1 계산의 평원으로 들어갑니다.
4. 설치가 끝나면 해당 앱의 출처가 다른 앱 설치 허용을 다시 끌 수 있습니다. 기기의 보안 검사 전체를 끄지 마세요.

| 항목 | 이번 배포 |
| --- | --- |
| 지원 OS | Android 7.0 이상 (`minSdk 24`) |
| 화면 | 스마트폰 가로 모드, FHD/20:9 저높이 화면 대응 |
| 버전 | `0.1.2`, versionCode `3` |
| 패키지 | `com.crus7230.kvm.renewal` |
| 설치 파일 | 전체 미디어 포함 APK, 56,749,105 bytes (약 54.1 MiB) |
| 서명 | 개발용 Android Debug 키, release 모드 빌드 |

v0.1.1부터 Renewal은 기존 KVM과 v0.1.0의 `com.user.kvm`을 업데이트하지 않고 **별도 앱으로 설치**됩니다. 기존 앱은 삭제할 필요가 없으며 그 데이터도 유지됩니다. 새 앱의 진행은 처음부터 시작하고 기존 진행·미디어 팩은 자동 이관하지 않습니다. 같은 서명의 v0.1.1 Renewal이 설치되어 있다면 v0.1.2는 정상 업데이트로 진행을 유지하도록 구성했습니다. 실제 휴대폰 업데이트 검증은 남아 있습니다.

이 배포는 실기기 테스트를 위한 공개 **알파 사전 릴리스**입니다. 개발용 서명으로 직접 설치할 수 있지만 정식 배포용 키나 Google Play 배포본이 아닙니다. 이후 같은 `com.crus7230.kvm.renewal` 앱을 업데이트할 때에는 같은 서명과 증가한 versionCode가 필요합니다. 설치 오류가 나면 보안 검사 전체를 끄거나 앱 데이터를 삭제하지 말고 오류 문구를 [Issues](https://github.com/Crus7230/kv-engpzl/issues)에 알려주세요.

APK SHA256:

```text
F99E806E767B4E6CF0DB0BC2AF0B4B5A415CE5BD0153018DB85461DFC604B3C4
```

## 플레이 흐름

`월드맵 → 계산의 평원 → 오늘의 복습 또는 다음 스테이지 → 매치·발굴 → 수식 완성·해설 → 정원 복원 → 다음 추천`

- R1은 6챕터 × 10개 스테이지입니다. 기본 연산, 혼합 연산·괄호, 복습, 보드 효과 학습과 전이 문제로 이어집니다.
- 수학 풀이와 매치 퍼즐과 지도 진행은 별도 모델로 연결합니다. 매치만 하거나 숫자만 모아서는 완료되지 않습니다.
- 3단계 힌트, 오개념 피드백과 풀이 해설을 제공합니다. 힌트를 사용해도 다음 스테이지와 복원 보상은 막지 않습니다.
- 도래한 복습과 다음 탐험을 추천합니다. 빠진 날짜를 벌주거나 연속 출석을 초기화하지 않습니다.
- 정원 복원 지점은 24곳입니다. 캐릭터 4명, 무료 장식 변경과 짧은 이야기 다시 보기를 제공합니다.
- 중단한 보드와 작성 중인 식, 진행과 복원을 저장합니다. 첫 완료 보상은 중복 지급하지 않습니다.
- 광고, 결제, 가챠, 생명과 대기시간은 없습니다. 인터넷 연결 없이 기본 플레이를 할 수 있습니다.

진행 구조는 꿈의 정원(Gardenscapes)의 퍼즐·정원 분리를 장르 참고점으로 삼았습니다. 기존 KVM의 세계관·캐릭터와 인접 교환 퍼즐을 유지합니다.

## 검증 범위와 알려진 제한

2026-10-11 기준 `flutter analyze --no-pub` 오류 0건, Flutter 테스트 265개와 순수 Dart 검증 스크립트 15개를 통과했습니다. R1 60개 연속 완료, 보드 120개 참조 경로, 저장 복원·중복 보상 방지, 다음 날 복습과 저높이 화면을 자동 검증했습니다. Android 전체 APK의 빌드, 서명과 포함 미디어 해시를 확인했습니다.

실제 Android 휴대폰의 설치·강제 종료 복원·성능과 전체 APK에서 로직 전용 APK로의 업데이트는 아직 검증하지 않았습니다. 웹·Flutter viewport 캡처는 실제 기기 검증이 아닙니다. 정원은 기존 배경과 벡터 레이어를 합성한 장면이며, 아트·스토리와 사람 플레이에 따른 난도 보정은 계속 개발합니다. 학습 성취 향상은 실제 사용자 연구로 확인한 결과가 아닙니다.

오류를 제보할 때는 기종, Android 버전, 앱 버전, 스테이지 ID, 재현 순서와 화면을 알려주세요. 개인정보나 기기 식별자를 포함할 필요는 없습니다.

## 소스 구조와 개발

이 저장소의 현재 기본 브랜치는 Renewal 앱입니다. 이전 앱의 현재 파일은 교체했으며 과거 Git 커밋 이력은 보존했습니다.

```text
lib/app/                       앱 셸과 화면 흐름
lib/core/assets/               보존 미디어 팩
lib/features/campaign/         R1 실제 콘텐츠와 캠페인 모델
lib/features/discovery/         매치·발굴·보드 효과·세션
lib/features/puzzle/            수식 AST와 정답 검증
lib/features/progress/          저장·완료·복습·일일 추천
lib/features/garden/            지도·정원·캐릭터·복원
assets/                        필요한 배경·캐릭터와 출처/해시 manifest
android/                       Android 프로젝트와 보존 미디어 구현
web/                           웹 프리뷰 프로젝트
test/                          회귀·화면·제품 루프 테스트
tool/                          Dart 검증과 로직 전용 소스 생성
docs/                          구현·설계 기록
legacy_reference/              기존 수학 문제 동결 참조본
```

Flutter SDK(Dart 3.12 이상 포함)와 Android SDK를 준비한 뒤 저장소 루트에서 실행합니다. 생성 캐시, APK, 로컬 SDK 경로와 서명 비밀 파일은 소스에 포함하지 않습니다. 직접 빌드하면 이 배포 APK와 같은 서명이 자동 보장되는 것은 아닙니다.

```powershell
flutter pub get
flutter analyze
flutter test
dart .\tool\verify_r1_runtime.dart
dart .\tool\verify_r1_complete_progress.dart
flutter run -d chrome
flutter build apk --release
```

## 에셋과 향후 업데이트

이번 다운로드는 신규 설치에 필요한 **전체 APK**입니다. 최초 실행 시 검증한 `r1-media-v2` 이미지 팩을 앱 전용 저장소에 보존합니다. 이후 같은 미디어를 쓰는 로직 전용 APK가 이를 재사용하는 구조입니다. 로직 수정도 APK 업데이트이며 원격 Dart 코드 패치가 아닙니다.

로직 전용 배포에는 같은 application ID·서명, 증가한 versionCode가 필요합니다. 앱 삭제·데이터 초기화·새 기기와 새 미디어 팩에는 전체 APK가 필요합니다. 실제 업데이트 전환을 검증하기 전에는 로직 전용 APK를 신규 사용자에게 제공하지 않습니다. 정식 키로 전환할 때의 설치·진행 이전 정책은 별도로 확정해야 합니다.

[R1 구현과 검증 상세](docs/R1_COMPLETE_ALPHA_IMPLEMENTATION.md), [에셋 분리와 업데이트](docs/ASSET_PACK_UPDATES.md), [학습·복습 설계](docs/LEARNING_PROGRESSION_DESIGN.md), [7리전 커리큘럼](docs/REGIONAL_STAGE_CURRICULUM.md)을 참고하세요. 이전 단계의 문서는 당시 구현과 검증 기록이며 이번 APK 배포 상태는 이 README와 해당 Release 안내를 기준으로 합니다.
