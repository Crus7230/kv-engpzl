# KV 수학탐험대 2026 v0.1.9 — 새 BGM 3곡과 음원 팩 업데이트

<!-- kvm-update: {"schema":1,"versionName":"0.1.9","versionCode":10} -->

## 다운로드와 설치

[Android APK 다운로드](https://github.com/Crus7230/kv-engpzl/releases/download/v0.1.9-r1-alpha/KVM-R1-0.1.9-alpha.apk)

버전은 `0.1.9+10`, 패키지는 `com.crus7230.kvm.renewal`입니다. Android 7.0 이상과 가로 화면을 지원하며 R1·R2 총 120개 스테이지를 유지합니다.

기존 앱을 삭제하거나 데이터를 지우지 말고 APK로 업데이트하세요. 기존 개발용 서명과 저장 epoch `expedition-1`을 유지하며 완료·별·동료·캐릭터·복습·이야기·중단 퍼즐을 초기화하지 않습니다. 신규 설치는 캐릭터 선택과 필수 튜토리얼부터 시작합니다.

## 새 음악 받기

1. 업데이트한 앱에서 설정 → `음악·효과음 및 접근성`을 엽니다.
2. `음원 받기 · 약 30MB, 팩당 1회`를 누릅니다. 모바일 데이터가 사용될 수 있습니다.
3. 다운로드·해시 검증이 끝나면 `음악 선택`에서 곡을 고르고 `저장`을 누릅니다.

새 곡은 `Glass Horizon`, `Highest Point of the Swing`, `Painted Ponies Turning`입니다. 인트로곡을 포함해 총 7곡을 선택합니다. 직접 선택한 곡은 인트로와 탐험에서 이어 재생하며 루프와 백그라운드 정지를 유지합니다.

이번 APK는 음악 파일을 포함하지 않고 별도 공개된 `audio-v2`를 사용합니다. 새 3곡만 받는 증분 방식이 아니라 음악 7곡·효과음 4개의 전체 팩 약 29.9MB를 한 번 받습니다. 기존 `audio-v1`은 삭제하지 않지만 새 버전의 재생에는 `audio-v2`가 필요합니다. 다운로드를 거절하면 조용히 게임을 진행할 수 있고 이후 설정에서 받을 수 있습니다. 같은 팩을 쓰는 다음 앱 업데이트에서는 재다운로드하지 않습니다. ZIP을 직접 압축 해제할 필요는 없습니다.

이미지 팩 `r1-media-v3`는 그대로 재사용합니다. 효과음·햅틱·선택한 모험 캐릭터, 기존 퍼즐과 수학 문제·지도·인트로·기억꽃·탐험 여권을 유지합니다. 새 런타임 의존성은 추가하지 않습니다.

[음원 팩과 원본 검증 기록](AUDIO_PACK_V2.md) · [음원 팩 릴리즈](https://github.com/Crus7230/kv-engpzl/releases/tag/media-audio-v2)

## 검증과 한계

- `flutter analyze --no-pub`: 이슈 0개.
- `flutter test --no-pub --reporter expanded`: 665개 통과, 공개 릴리즈 JSON 검사 1개 조건부 제외. 해당 검사는 게시 후 실제 공개 JSON으로 별도 실행합니다.
- 새 곡 3개의 설정 선택, 11개 파일의 audio-v2 manifest 전달, 명시적 다운로드·재시도, 다운로드 중 중복 버튼 방지와 설치 후 버튼 숨김을 Flutter 테스트로 확인했습니다.
- 기존 음악 선택·음소거·장면 전환·저장 복원, R1 60개 연속 진행·R1→R2와 보상 중복 방지를 회귀 검증했습니다.
- 이미지 31개·음원 11개의 원본 및 ZIP 크기·SHA256을 확인했고 공개 이미지/음원 팩의 asset 크기·digest도 manifest와 일치합니다.

- `flutter pub get --offline` 후 `flutter build apk --release --no-pub -t lib/main.dart` 성공. 정상 진입점이며 개발용 프리뷰 리본·가상 진행 기록은 넣지 않았습니다.
- 다운로드형 빌드 입력 217개가 검증한 소스와 SHA256이 같으며 pubspec에서는 미디어 선언만 제외했습니다.
- APK v2 서명과 기존 인증서 일치, 패키지·versionName/code·minSdk 24·targetSdk 36·가로 화면·3개 ABI를 확인했습니다.
- APK 내부 보존 이미지·음원은 0개이며 이미지/음원 다운로드 manifest 2개의 SHA256이 소스와 일치합니다.

파일은 `KVM-R1-0.1.9-alpha.apk`, 51,324,843 bytes(약 48.9 MiB)입니다. v0.1.8보다 196 bytes 증가했으며 음악 파일을 APK에 추가하지 않았습니다.

SHA256:

```text
6e049fe00dfd2a691357e4a10cd8f9f04788feb6a7fa8d4468423b677395cd8d
```

공개 다운로드·업데이트 인식 검증은 게시 후 기록합니다. 실제 Android 설치·다운로드·청취·햅틱·프레임 성능은 사용자 기기에서 별도 확인해야 합니다.
