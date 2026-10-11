# 에셋 분리와 앱 업데이트

Android 첫 전체 설치 후 배경과 캐릭터 이미지를 재설치하지 않고 앱 로직만 포함한 APK로 업데이트할 수 있도록 미디어 저장과 앱 코드를 분리했다. 로직 수정은 여전히 APK 업데이트다. 서버에서 Dart 코드를 내려받아 실행하는 원격 패치, CDN 다운로드 또는 Play Asset Delivery를 도입한 것은 아니다.

## 설치 방식

| 종류 | 이미지 포함 | 설치 조건 |
| --- | --- | --- |
| 전체 APK | PNG 31개와 manifest | 신규 설치, 미디어 팩 버전 변경, 앱 데이터 삭제 후 설치, 손상 미디어 복구 |
| 로직 전용 APK | manifest만 포함 | 검증된 기존 `r1-media-v3`가 있고 같은 앱의 정상 업데이트인 경우 |
| Web | 일반 bundle | 현재와 같이 이미지 포함 web 배포 |

첫 전체 APK가 시작되면 이미지를 `filesDir/kvm_asset_packs/r1-media-v3`에 복사하고 SHA256과 크기를 검증한다. 다음 시작에서는 검증된 팩을 재사용한다. 새 candidate를 검증한 뒤 교체하고 같은 버전의 이전 팩을 보존한다. 교체가 중단된 경우 완전한 candidate 또는 같은 버전의 이전 팩으로 복구한다. 이미지 팩과 학습 저장을 섞지 않는다.

이번 v3는 기존 배경 2개와 캐릭터 26명의 원본 사본, 새 D/J와 R1 탐험 지도 3개로 구성된다. 새 artwork는 built-in imagegen으로 제작했으며 해상도·투명도·해시·사용 화면·프롬프트 요약을 manifest에 기록했다. v1/v2만 설치된 기기는 v3 전체 APK를 한 번 받아야 한다. 이전 팩을 v3로 간주하거나 새 이미지를 빠뜨린 로직 전용 업데이트로 대체하지 않는다. 이전 팩과 원본은 삭제하지 않았다.

등록된 `assets/legacy/*.png`와 `assets/expedition/*.png`만 읽을 수 있으며 파일 경로는 앱 전용 디렉터리 안으로 제한한다. 누락 또는 해시 손상 시 전체 APK 설치 안내를 표시하고 진행을 초기화하지 않는다. UI 표시 전 팩 준비를 마치며 Flutter 이미지는 `RetainedAssetBundle`을 통해 읽는다.

현재 이미지 31개의 합계는 15,617,620 bytes다. 기존 원본 사본은 10,276,549 bytes, 신규 탐험 이미지 3개는 5,341,071 bytes다. 최초 전체 APK에는 이미지가 남아 있으므로 첫 설치 직후에는 APK와 파일 팩에 이미지가 중복 존재한다. 로직 전용 APK로 업데이트한 이후 APK 안의 중복 미디어를 줄일 수 있다. 최종 APK 절감량은 서명 빌드로 측정해야 한다.

## 업데이트 조건

v0.1.1부터 Renewal은 `com.crus7230.kvm.renewal`이라는 별도 앱이다. 기존 Kotlin 앱과 v0.1.0의 `com.user.kvm`을 업데이트하지 않으며 기존 진행이나 미디어 팩을 자동 이관하지 않는다. 새 앱의 최초 설치에는 전체 APK가 필요하다. 이후 Renewal을 업데이트할 때는 앱을 삭제하지 않고 같은 `com.crus7230.kvm.renewal`, 같은 signing key와 더 높은 versionCode를 사용한다. 현재 Gradle 템플릿의 debug 서명을 정식 배포용 서명으로 해석하지 않는다.

Android 앱 전용 파일은 일반 APK 업데이트에서 재사용할 수 있지만 앱 삭제나 데이터 지우기 후에는 남지 않는다. 새 기기와 초기화 후에는 전체 APK가 필요하다. [Android 앱 전용 저장소](https://developer.android.com/training/data-storage/app-specific)와 [Flutter Android 배포](https://docs.flutter.dev/deployment/android)의 설치 및 서명 조건을 따른다.

문장, AST, 커리큘럼과 학습 로직은 현재 Dart 코드이므로 로직 APK에 들어간다. 이미지 변경이 필요하면 별도 pack ID와 manifest를 도입한 전체 업데이트가 필요하다. 오디오와 나머지 리전의 신규 배경까지 구현하지 않았다.

## 의무 온보딩과 이번 진행 초기화

2026-10-11 사용자의 전체 진행 초기화 요청에 따라 저장 구획을 `kvm.renewal.save.v1.expedition-1`로 변경했다. 이전 `kvm.renewal.save.v1.slot.*`와 활성 포인터는 읽거나 덮어쓰지 않는다. 별·완료·복습·선택·장식·중단 세션은 새 구획에서 초기 상태로 시작한다. 이전 원본 저장과 에셋 팩을 물리적으로 삭제하지 않으며, 이후 일반 앱 업데이트에서는 이 epoch를 바꾸지 않는다.

새 설치는 26명 중 캐릭터를 선택하고 실제 C01 S01의 발굴·수식 문제를 완료한 뒤에만 출발할 수 있다. `onboardingCompleted`를 문제 완료 및 출발 transaction에서 기록한다. 누락 필드로 온보딩 완료를 추론하지 않는다. 종료 후에는 선택·보드·식 또는 완료 후 출발 단계부터 재개하며, 온보딩을 매 실행 반복하거나 완료 보상을 중복 지급하지 않는다.

## 로직 전용 빌드 입력 생성

`tool/prepare_logic_only_source.ps1`은 `build/logic-only-source` 아래 새 디렉터리에 소스를 복사한다. 원본 파일, 원본 pubspec과 이미지에는 손대지 않는다. Flutter 및 Gradle 캐시, 빌드 산출물, keystore, `key.properties`와 `local.properties`는 복사하지 않는다. 생성본 pubspec에서는 `assets/legacy/`와 `assets/expedition/`를 제외하며 manifest는 유지한다.

```powershell
cd "C:\grus.py\pythonProject\Grus Project\KVM\2026Renewal"
& .\tool\prepare_logic_only_source.ps1
```

기존 목적지 덮어쓰기와 `build/logic-only-source` 밖으로의 출력은 거부한다. 실행 결과의 경로는 해당 시점의 소스 snapshot이다. 코드가 변경되면 새 생성본을 사용한다. 생성본에는 서명 비밀 파일을 복사하지 않으므로 실제 릴리스 설정을 별도로 안전하게 제공해야 한다.

다음은 별도 승인을 받아 수행할 Android 빌드 예시이며 이번 구현에서는 실행하지 않았다. `<generated-path>`와 versionCode를 실제 경로 및 기존 설치보다 높은 값으로 바꾼다. 전체 APK는 원본 프로젝트에서 같은 서명으로 만든다.

```powershell
cd "<generated-path>"
flutter pub get
flutter build apk --release --build-name 0.2.1 --build-number 2
```

예시 build number `2`는 기존 APK보다 높다고 보장하지 않는다. 기존 배포 기록을 확인하고 증가시킨다. 정상적인 Flutter 의존성 준비와 서명 설정은 여전히 필요하다.

## 배포 전 검증

1. 새 기기에 전체 APK를 설치하고 배경과 캐릭터를 확인한다.
2. 두 스테이지를 완료하고 정원을 복원한 뒤 진행 중 보드와 식을 남긴다.
3. 앱을 삭제하지 않고 로직 전용 APK로 업데이트한다.
4. 이미지, 별, 복원과 중단된 보드 및 식이 유지되는지 확인한다.
5. candidate 교체 중단과 팩 손상 시 이전 팩 복구 또는 전체 APK 안내를 확인한다.
6. 데이터 지우기 후 로직 전용 APK가 진행 초기화를 강행하지 않고 전체 APK를 안내하는지 확인한다.

현재 v3의 Dart channel 계약 테스트와 소스 생성 스크립트의 이미지 제외, 31개 원본 해시·크기 검증을 수행했다. v0.1.4 전체 Android APK 빌드와 v0.1.3 동일 인증서·APK v2 서명을 확인했고, 실제 APK 안의 이미지 31개가 manifest와 일치한다. 실기기 설치와 전체 APK→로직 전용 APK 업데이트 검증은 아직 수행하지 않았다. 로직 전용 APK를 신규 사용자에게 배포하지 않는다.
