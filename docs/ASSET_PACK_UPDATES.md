# 에셋 분리와 앱 업데이트

Android에서 앱 코드, 배경·캐릭터 팩, 음악·효과음 팩을 분리했다. 팩은 APK에서 최초 설치하거나 사용자가 동의한 최초 다운로드로 설치하고, 이후 코드 업데이트에서는 재사용한다. 로직 수정은 여전히 APK 업데이트다. 서버에서 Dart 코드를 내려받아 실행하는 원격 패치나 Play Asset Delivery는 도입하지 않았다.

## 설치 방식

| 종류 | 에셋 포함 | 설치 조건 |
| --- | --- | --- |
| 다운로드형 APK / 로직 업데이트 | manifest만 포함 | 신규 설치는 이미지 팩 최초 다운로드가 필요하며 음원은 선택 다운로드. 기존 검증된 팩은 재사용 |
| 전체 오프라인 APK | PNG 31개, 음원 11개와 manifest | 다운로드 없이 시작할 수 있는 대체 설치 방식 |
| 음원 다운로드형 APK | PNG 31개와 manifest | 이미지는 포함하고 음원만 선택 다운로드하는 대체 방식 |
| Web | 일반 bundle | 현재와 같이 이미지 포함 web 배포 |

첫 전체 APK가 시작되면 이미지를 `filesDir/kvm_asset_packs/r1-media-v3`에 복사하고 SHA256과 크기를 검증한다. 다음 시작에서는 검증된 팩을 재사용한다. 새 candidate를 검증한 뒤 교체하고 같은 버전의 이전 팩을 보존한다. 교체가 중단된 경우 완전한 candidate 또는 같은 버전의 이전 팩으로 복구한다. 이미지 팩과 학습 저장을 섞지 않는다.

이번 v3는 기존 배경 2개와 캐릭터 26명의 원본 사본, 새 D/J와 R1 탐험 지도 3개로 구성된다. 새 artwork는 built-in imagegen으로 제작했으며 해상도·투명도·해시·사용 화면·프롬프트 요약을 manifest에 기록했다. v1/v2만 설치된 기기는 v3 ZIP 또는 v3 전체 APK가 필요하다. 이전 팩을 v3로 간주하지 않는다. 이전 팩과 원본은 삭제하지 않았다.

등록된 `assets/legacy/*.png`와 `assets/expedition/*.png`만 읽을 수 있으며 파일 경로는 앱 전용 디렉터리 안으로 제한한다. APK에도 검증 가능한 이미지가 없으면 최초 다운로드 안내를 표시하고 진행을 초기화하지 않는다. 준비 실패 시 재시도 또는 전체 APK 복구가 가능하다. UI 표시 전 팩 준비를 마치며 Flutter 이미지는 `RetainedAssetBundle`을 통해 읽는다.

현재 이미지 31개의 합계는 15,617,620 bytes다. 기존 원본 사본은 10,276,549 bytes, 신규 탐험 이미지 3개는 5,341,071 bytes다. 최초 전체 APK에는 이미지가 남아 있으므로 첫 설치 직후에는 APK와 파일 팩에 이미지가 중복 존재한다. 로직 전용 APK로 업데이트한 이후 APK 안의 중복 미디어를 줄일 수 있다. 최종 APK 절감량은 서명 빌드로 측정해야 한다.

## 업데이트 조건

v0.1.1부터 Renewal은 `com.crus7230.kvm.renewal`이라는 별도 앱이다. 기존 Kotlin 앱과 v0.1.0의 `com.user.kvm`을 업데이트하지 않으며 기존 진행이나 미디어 팩을 자동 이관하지 않는다. 새 앱의 최초 설치에는 공개된 이미지 ZIP 또는 전체 APK가 필요하다. 이후 Renewal을 업데이트할 때는 앱을 삭제하지 않고 같은 `com.crus7230.kvm.renewal`, 같은 signing key와 더 높은 versionCode를 사용한다. 현재 Gradle 템플릿의 debug 서명을 정식 배포용 서명으로 해석하지 않는다.

Android 앱 전용 파일은 일반 APK 업데이트에서 재사용할 수 있지만 앱 삭제나 데이터 지우기 후에는 남지 않는다. 새 기기와 초기화 후에는 팩을 다시 받거나 전체 APK를 설치한다. [Android 앱 전용 저장소](https://developer.android.com/training/data-storage/app-specific)와 [Flutter Android 배포](https://docs.flutter.dev/deployment/android)의 설치 및 서명 조건을 따른다.

문장, AST, 커리큘럼과 학습 로직은 현재 Dart 코드이므로 로직 APK에 들어간다. 이미지·음원 변경이 필요하면 새 pack ID, manifest와 검증된 다운로드 ZIP을 배포한다. 같은 pack ID의 파일을 덮어쓰지 않는다. R3 이후 신규 배경은 아직 구현하지 않았다.

## 의무 온보딩과 이번 진행 초기화

2026-10-11 사용자의 전체 진행 초기화 요청에 따라 저장 구획을 `kvm.renewal.save.v1.expedition-1`로 변경했다. 이전 `kvm.renewal.save.v1.slot.*`와 활성 포인터는 읽거나 덮어쓰지 않는다. 별·완료·복습·선택·장식·중단 세션은 새 구획에서 초기 상태로 시작한다. 이전 원본 저장과 에셋 팩을 물리적으로 삭제하지 않으며, 이후 일반 앱 업데이트에서는 이 epoch를 바꾸지 않는다.

새 설치는 26명 중 캐릭터를 선택하고 실제 C01 S01의 발굴·수식 문제를 완료한 뒤에만 출발할 수 있다. `onboardingCompleted`를 문제 완료 및 출발 transaction에서 기록한다. 누락 필드로 온보딩 완료를 추론하지 않는다. 종료 후에는 선택·보드·식 또는 완료 후 출발 단계부터 재개하며, 온보딩을 매 실행 반복하거나 완료 보상을 중복 지급하지 않는다.

## 로직 전용 빌드 입력 생성

`tool/prepare_logic_only_source.ps1`은 `build/logic-only-source` 아래 새 디렉터리에 소스를 복사한다. 원본 파일, 원본 pubspec과 이미지에는 손대지 않는다. Flutter 및 Gradle 캐시, 빌드 산출물, keystore, `key.properties`와 `local.properties`는 복사하지 않는다. 생성본 pubspec에서는 `assets/legacy/`, `assets/expedition/`, `assets/audio/`를 제외하고 두 manifest를 유지한다. 따라서 APK에 음원 약 30MB가 매번 포함되지 않는다. 신규 설치에서도 이미지 다운로드 화면을 통해 시작할 수 있지만 두 ZIP을 먼저 공개해야 한다.

```powershell
cd "C:\grus.py\pythonProject\Grus Project\KVM\2026Renewal"
& .\tool\prepare_logic_only_source.ps1
```

기존 목적지 덮어쓰기와 `build/logic-only-source` 밖으로의 출력은 거부한다. 실행 결과의 경로는 해당 시점의 소스 snapshot이다. 코드가 변경되면 새 생성본을 사용한다. 생성본에는 서명 비밀 파일을 복사하지 않으므로 실제 릴리스 설정을 별도로 안전하게 제공해야 한다.

다음은 다운로드형 Android 빌드 명령이다. `<generated-path>`는 방금 생성한 경로를 사용한다. versionName/versionCode는 기존 공개 버전보다 높아야 한다. 전체 APK는 원본 프로젝트에서 같은 서명으로 만든다.

```powershell
cd "<generated-path>"
flutter pub get
flutter build apk --release --no-pub -t lib/main.dart
```

생성본은 원본 pubspec의 버전을 승계한다. 정상적인 Flutter 의존성 준비와 기존 앱과 동일한 서명 설정은 여전히 필요하다.

## 배포 전 검증

1. 새 기기에 전체 APK를 설치하고 배경과 캐릭터를 확인한다.
2. 두 스테이지를 완료하고 정원을 복원한 뒤 진행 중 보드와 식을 남긴다.
3. 앱을 삭제하지 않고 로직 전용 APK로 업데이트한다.
4. 이미지, 별, 복원과 중단된 보드 및 식이 유지되는지 확인한다.
5. candidate 교체 중단과 팩 손상 시 이전 팩 복구 또는 전체 APK 안내를 확인한다.
6. 데이터 지우기 후 다운로드형 APK가 이미지 팩 최초 다운로드를 안내하고 필수 튜토리얼부터 시작하는지 확인한다.

이전 v0.1.4 검증에서는 v3 Dart channel 계약과 소스 생성 스크립트, 31개 원본 해시·크기 및 전체 Android APK의 이미지·서명을 확인했다. 이번 다운로드형 변경은 별도 검증 범위다. 신규 사용자에게 다운로드형 APK를 배포하기 전에 아래 두 ZIP을 먼저 공개하고 실기기 최초 다운로드·업데이트 유지 검증을 완료해야 한다.

## 이미지·음원 다운로드 팩

| 팩 | 파일 | ZIP bytes | 앱 전용 설치 위치 |
| --- | --- | --- | --- |
| `r1-media-v3` | `KVM-r1-media-v3.zip` | 15,183,325 | `filesDir/kvm_asset_packs/r1-media-v3` |
| `audio-v2` | `KVM-audio-v2.zip` | 29,864,615 | `filesDir/kvm_asset_packs/audio-v2` |

현재 소스의 로컬 배포 산출물은 `build/asset-pack/r1-media-v3/KVM-r1-media-v3.zip`, `build/audio-pack/audio-v2/KVM-audio-v2.zip`이다. 2026-10-12에 [이미지 팩](https://github.com/Crus7230/kv-engpzl/releases/tag/media-r1-v3)과 [이전 음원 팩 audio-v1](https://github.com/Crus7230/kv-engpzl/releases/tag/media-audio-v1)을 공개하고 공개 다운로드 해시를 확인했다. v0.1.8까지는 audio-v1, v0.1.9부터는 audio-v2를 사용한다. 기존 audio-v1 사용자는 v0.1.9 앱 업데이트 후 설정에서 새 팩 약 30MB를 받아야 음악·효과음을 재생한다. 기존 팩은 삭제하지 않는다. 새 3곡을 포함한 audio-v2 소스와 배포 경계는 [audio-v2 기록](AUDIO_PACK_V2.md)과 [v0.1.9 설치 안내](RELEASE_NOTES_0_1_9.md)를 기준으로 한다. 기존 팩과 릴리즈는 보존하며 같은 pack ID를 덮어쓰지 않는다. 에셋 릴리즈는 APK 버전 태그 패턴과 달라 앱 업데이트 후보로 선택되지 않는다.

- 이미지 ZIP SHA256: `5ABD5C72714DC982A47EA89BC35DE849A26B3F38B16C06F4A98CD0F4DAB8F50A`
- 현재 audio-v2 ZIP SHA256: `9A7200A5FDEB9A0B4A1FA37F70E5A77BD94D61FC025F4FA5CD98AF608BF9A750`
- 보존된 audio-v1 ZIP SHA256: `9F2A0BC6F7F35B2DE76BA006385391987C3E764BDE24914E54C5617EABA4EB2E`

`RetainedPackDownloader`는 고정 GitHub HTTPS 경로, 허용 redirect host, 다운로드 크기와 ZIP SHA256을 검증한다. 압축을 풀 때 등록된 경로·중복·각 파일 크기·SHA256을 검증하며 활성 팩을 바로 덮어쓰지 않는다. 검증된 candidate만 교체하고 이전 팩을 보존한다. 실패한 임시 다운로드와 불완전 candidate만 정리한다. 사용자 저장과 BGM 원본은 건드리지 않는다.

신규 설치는 이미지 다운로드에 동의해야 지도·캐릭터를 표시할 수 있다. 음원은 선택 사항이다. 거절하면 조용히 플레이하고 이후 설정에서 받을 수 있다. 안내를 본 기록도 저장하여 앱을 켤 때마다 다시 권하지 않는다. 팩이 이미 있으면 네트워크 다운로드는 하지 않는다. 음악은 APK마다 다시 들어가지 않으며 미래 콘텐츠 변경에 따른 새 팩 배포만 별개다.

## 음악·효과음·햅틱과 모험 캐릭터

음악 원본은 `C:\grus.py\pythonProject\Grus Project\BGM`의 MP3 7개를 바이너리 복사했다. 인트로 기본곡은 `Before the Great Dawn`, 탐험·퍼즐 기본곡은 `Yellow Plastic Swings`이며 설정에서 총 7곡을 선택하도록 소스를 확장했다. 새 곡은 `Glass Horizon`, `Highest Point of the Swing`, `Painted Ponies Turning`이다. 새 곡 선택은 audio-v2를 사용하는 다음 APK에 포함해야 하며 기존 v0.1.8 APK가 자동으로 목록을 바꾸지는 않는다. MP3를 변경하거나 레퍼런스 게임의 효과음을 추출하지 않았다. 자체 PCM 효과음 4개는 `tool/generate_puzzle_sounds.dart`로 생성했다. 사용자 제공 음원의 공개 배포 권한은 사용자 관리 대상이다.

`AudioController`는 음악·효과음·햅틱 ON/OFF, 각각의 음량 및 통합 음악 선택을 저장한다. 기본은 장면에 따라 인트로/탐험 곡을 바꾸며 직접 선택한 곡은 두 장면에서 이어 재생한다. Android는 `MediaPlayer` loop와 `SoundPool`, Web은 HTML Audio를 사용한다. `inactive/hidden/paused/detached`에서는 음악·효과음을 중단하고 `resumed`에서만 이어 재생한다. Android Activity와 audio focus, Web visibility도 별도로 정지한다. 브라우저는 자동 재생을 막을 수 있어 첫 터치 뒤 음악을 시작한다. 음악과 효과음을 모두 끈 경우 audio focus를 요청하지 않는다.

선택은 selection 햅틱, 교환·매치는 light, 풀이 블록 획득은 medium, 정답은 heavy 햅틱으로 구분한다. 효과음·햅틱은 모션 타임라인에서 발생하며 복원·화면 재생성·백그라운드 복귀로 재생하지 않는다. 짧은 동일 이벤트를 제한하고, 햅틱은 음원 다운로드 여부와 독립적이다. 실제 진동 강도와 지원 여부는 폰에 따라 다르며 Web에서는 햅틱을 사용하지 않는다.

동료 도감의 `이 동료로 탐험하기`는 탐험대 구성 변경이 아니라 `playerCharacterId` 변경이다. 구출한 동료와 처음 선택한 캐릭터만 선택할 수 있다. 새 `starterCharacterId`는 최초 캐릭터를 보존하며 기존 저장에서는 현재 캐릭터를 최초 캐릭터로 이행한다. 구조 이야기, 소유 동료, 별·학습·정원·중단 퍼즐은 유지한다. 현재 모험 캐릭터가 구조된 동료여도 합류 이야기를 생략하지 않는다. 저장 epoch는 유지하며 앱 버전만 `0.1.6+7`로 증가시킨다.

## 소스 구현 단계의 검증 기록

주요 변경 파일은 `lib/app/math_adventure_app.dart`의 설정·생명주기·다운로드 안내, `lib/core/audio/`의 재생·피드백 제어, `lib/core/assets/retained_asset_bundle.dart`와 Android `MainActivity.kt`·`GameAudioBridge.kt`·`RetainedPackDownloader.kt`의 팩 처리, `lib/features/companions/`와 `progress_models.dart`의 모험 캐릭터 선택·추가 저장 필드다. `discovery_board_animation.dart`와 `discovery_puzzle_screen.dart`에서 모션·선택·획득·정답 이벤트를 연결했다. `pubspec.yaml`, 두 manifest, Web `audio.js`·`index.html`, 빌드 입력 생성 스크립트와 관련 테스트도 변경했다.

순수 Dart 오디오·생명주기·음소거·햅틱·다운로드 선택·캐릭터 변경·저장 복원 계약, Web 가짜 Audio 계약, 관련 소스 정적 진단, Kotlin 타입 검사와 20개 발굴 퍼즐 회귀 경로를 확인했다. 두 ZIP은 등록 파일의 크기·해시와 일치하며 다운로드형/음원 다운로드형 입력에서 제외되는 파일을 확인했다. Kotlin 타입 검사는 업데이트 클래스만 스텁으로 대체한 소스 검사이고 APK 빌드가 아니다. Web 가짜 Audio 검사는 실제 청취나 브라우저 자동재생 검증이 아니다.

실행한 주요 검증은 `dart tool/verify_audio_and_avatar.dart`, `dart tool/verify_excavation.dart --smoke`, `node tool/verify_web_audio.cjs`, `tool/verify_asset_packs.ps1`이다. 기존 로컬 분석기 API로 관련 Dart 41개 파일을 해석했으며 진단은 0건이었다. 신규 런타임 의존성 설치, APK 생성, GitHub 업로드 또는 로컬 커밋은 하지 않았다.

위 내용은 Flutter 실행 승인 전 소스 구현 단계의 기록이다. 이후 승인된 분석·전체 테스트·APK 빌드와 공개 검증 결과는 [v0.1.6 릴리즈 기록](RELEASE_NOTES_0_1_6.md)을 기준으로 한다. 신규 설치 → 이미지/음원 다운로드 → 튜토리얼 → 홈/다른 앱 전환 → 복귀 → 모험 캐릭터 변경 → 같은 서명의 코드 업데이트 → 오프라인 재실행은 실제 Android 폰으로 확인해야 한다. 다운로드 중단·해시 손상·저장 공간 부족도 실기기 검증 범위다.
