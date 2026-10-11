# GitHub 공개 APK 배포 기록

## v0.1.3 모션·시작 업데이트 빌드

사용자가 승인한 아이콘·인트로·보석 교환→제거→동시 낙하·보충→연쇄 개선과 시작 GitHub 업데이트 확인을 묶어 `0.1.3+4` 전체 APK를 빌드했다. 배포 대상은 `Crus7230/kv-engpzl`, 태그는 `v0.1.3-r1-alpha`, 첨부 파일은 `KVM-R1-0.1.3-alpha.apk` 한 개다. 새 런타임 의존성을 추가하지 않았다.

- 크기: 57,110,480 bytes. SHA256: `76134090C297F238E4CBC0F1DCE34C8E5D1087BE11BDA846AA416E7CEC70D65F`.
- 패키지: `com.crus7230.kvm.renewal`, versionName `0.1.3`, versionCode `4`, minSdk `24`.
- `flutter analyze --no-pub` 오류 0건, `flutter test --no-pub --reporter expanded` 전체 305개 통과, `flutter build apk --release --no-pub` 성공.
- APK v2 서명이 유효하고 인증서 SHA256이 v0.1.2와 같다. 포함된 `r1-media-v2` PNG 6개가 manifest의 크기·해시와 일치한다. APK manifest의 설치 권한과 비공개 FileProvider도 확인했다.
- 실제 기기 연결이 없어 설치·앱 내 다운로드·설치 확인과 모션 성능은 검증하지 않았다. v0.1.2에는 업데이트 기능이 없으므로 이번 버전은 한 번 직접 설치해야 한다.

시작 조회는 공개 `/releases?per_page=20` 목록을 최대 5초 기다리고 실패 시 게임을 계속 연다. 초안·이전 버전·잘못된 태그·표식·파일·digest는 제외한다. 사용자가 다운로드를 선택하면 앱 전용 캐시에서 크기·SHA256·패키지·versionCode·인증서를 재검증한 뒤 Android 설치 화면을 연다. 설치 허용 설정과 최종 확인은 사용자가 수행한다. 설치 취소·나중에 계속하기가 가능하며 저장·정원·보존 미디어는 업데이트 모듈에서 변경하지 않는다.

이후 릴리스도 아래 한 줄을 실제 APK 버전과 일치시켜야 한다. 알파는 `/releases/latest`에서 제외되므로 목록 조회를 유지한다.

```html
<!-- kvm-update: {"schema":1,"versionName":"0.1.3","versionCode":4} -->
```

공개 완료는 초안의 첨부 개수·크기·digest 검증, 공개 API 확인과 인증 없는 APK 다운로드의 SHA256 비교 후에 판정한다. 이전 릴리스와 Git 이력은 보존한다.

## v0.1.2 재빌드

사용자의 재빌드·원격 릴리스 요청에 따라 현재 독립 설치용 소스를 `0.1.2+3`으로 올리고 `flutter build apk --release --no-pub`를 새로 실행했다. 2026-10-11 20:43 KST에 빌드된 전체 APK이며 게임 기능·콘텐츠·패키지 ID는 변경하지 않았다. 기존 릴리스는 보존한다.

- Release: https://github.com/Crus7230/kv-engpzl/releases/tag/v0.1.2-r1-alpha
- APK: https://github.com/Crus7230/kv-engpzl/releases/download/v0.1.2-r1-alpha/KVM-R1-0.1.2-alpha.apk
- 버전: `0.1.2`, versionCode `3`, 패키지 `com.crus7230.kvm.renewal`.
- 크기: 56,749,105 bytes.
- SHA256: `F99E806E767B4E6CF0DB0BC2AF0B4B5A415CE5BD0153018DB85461DFC604B3C4`.

빌드와 `apksigner` 서명 검증을 통과했고 v0.1.1과 인증서가 같다. `aapt` 메타데이터와 DEX의 native Activity, 포함 미디어 6개의 해시를 확인했다. 배포용 입력 121개가 현재 작업 소스와 일치하는지 확인했다. 분석·Flutter 테스트는 게임 코드 변경이 없어 이번 재빌드에서 다시 실행하지 않았다. 실제 기기 설치·업데이트 검증은 남아 있다.

커밋 `9b202c83b8ba22cdc573774aac08a8ebec399e71`, `Release rebuilt KVM R1 alpha 0.1.2`와 `v0.1.2-r1-alpha` 태그를 원격 main에 push했다. APK 한 개의 초안 첨부 크기·digest를 확인한 뒤 사전 릴리스로 공개했다. 인증 없는 공개 APK 다운로드가 HTTP 200이고 원본 SHA256과 일치함을 확인했다. main의 README, 태그의 README와 최종 raw README 모두 새 링크·버전·해시를 표시한다. 공개 직후 raw README가 이전 내용을 반환했으나 재확인에서는 최신 내용이 확인됐다. 소스 변경은 pubspec 버전과 README 안내이며 내부 README·이 배포 기록도 갱신했다.

## v0.1.1 독립 설치 수정

기존 앱의 업데이트로 인식되어 설치가 실패한다는 사용자 제보에 따라 설치 식별자를 `com.crus7230.kvm.renewal`로 변경했다. namespace와 Kotlin Activity 패키지·경로도 일치시켰다. 앱 표시 이름은 `KV 수학탐험대 2026`, 버전은 `0.1.1+2`다. 기존 앱과 별도 설치하며 기존 앱 데이터는 유지되고 새 앱의 진행은 처음부터 시작한다. 이전 진도나 미디어 팩의 자동 이관은 구현하지 않았다.

- 새 Release: https://github.com/Crus7230/kv-engpzl/releases/tag/v0.1.1-r1-alpha
- 새 APK: https://github.com/Crus7230/kv-engpzl/releases/download/v0.1.1-r1-alpha/KVM-R1-0.1.1-alpha.apk
- 크기: 56,749,105 bytes.
- SHA256: `01EA0B0C4AA06782C391764029FD4A2BBF5BB45FE947498E4FC56DFB8BA4609A`.

공개 사전 릴리스의 APK 한 개를 인증 없이 다운로드해 HTTP 200과 원본 SHA256 일치를 확인했다. 공개 README의 패키지·다운로드 링크·해시도 일치한다. 이전 v0.1.0 Release에는 새 독립 설치용 다운로드 안내를 추가했으며 기존 첨부와 Git 이력은 보존했다. 배포 커밋은 `9229953740691ba0e18cd1390ae67171801fdf94`, `Give KVM Renewal a separate Android install identity`이며 main과 `v0.1.1-r1-alpha` 태그를 push했다.

수정 파일은 `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, 새 패키지 경로의 `MainActivity.kt`, `pubspec.yaml`, README와 에셋·R1 구현 문서다. 내부 배포 기록은 이 문서에 별도로 반영했다.

`flutter build apk --release --no-pub`를 다시 실행해 통과했다. `aapt`로 새 패키지와 `com.crus7230.kvm.renewal.MainActivity`, 버전·앱 이름·minSdk를 확인했다. APK의 DEX에 새 Activity 클래스가 있고 배경·캐릭터 6개가 manifest 해시와 일치함을 확인했다. 개발용 v2 서명도 유효하며 이전 APK와 같은 인증서다. 실제 기기 설치·실행은 아직 검증하지 않았다. 게임 로직과 콘텐츠는 변경하지 않았으며 분석·Flutter 테스트는 이번 패키징 수정에서 다시 실행하지 않았다.

## v0.1.0 최초 배포 기록

2026-10-11 사용자가 지정한 공개 저장소 `Crus7230/kv-engpzl`의 기본 브랜치를 KVM Renewal 소스로 교체하고, R1 설치 테스트용 알파 APK 한 개를 공개했다. 실제 휴대폰 설치·실행과 로직 전용 APK 업데이트는 검증하지 않았다.

## 공개 결과

- 저장소: https://github.com/Crus7230/kv-engpzl
- Release: https://github.com/Crus7230/kv-engpzl/releases/tag/v0.1.0-r1-alpha
- APK: https://github.com/Crus7230/kv-engpzl/releases/download/v0.1.0-r1-alpha/KVM-R1-0.1.0-alpha.apk
- 상태: `draft=false`, `prerelease=true`. 정식 최신 릴리스로 지정하지 않았다.
- 커밋: `3d6045e2e7a7cd69a1586d8ee76386f85cb12d9c`, `Replace legacy app with KVM R1 renewal alpha`.
- 이전 main: `7191cb82d630a620083a42f800c6322957c2e191`.

R1은 60개 스테이지이며 R2~R7은 `업데이트 예정`이다. 기존 저장소의 영어 퍼즐·WordNet·Firebase·추가 플랫폼 등 현재 파일은 교체했다. 과거 커밋 이력은 보존했으며 force push, 저장소 삭제, 이력 압축이나 원본 KVM 삭제는 수행하지 않았다. 따라서 과거 데이터가 Git 이력에서 완전히 사라지거나 저장소 전체 용량이 그만큼 줄어든 것은 아니다.

## APK와 검증

| 항목 | 결과 |
| --- | --- |
| 파일 | `KVM-R1-0.1.0-alpha.apk` 한 개 |
| 크기 | 56,749,085 bytes |
| SHA256 | `C5DB080CA74FEF4A5A2D97B94382F9899093287DBE97CDEE59FFCCC08A89078D` |
| Android | minSdk 24, targetSdk 36 |
| 버전 | `0.1.0`, versionCode `1`, `com.user.kvm` |
| 서명 | Android Debug, APK Signature Scheme v2 검증 통과 |
| 인증서 SHA256 | `6e48b7c6164bedc2b0785f2247769b238ee2428c7e567c6362f80bd1f27d5c7b` |

`git bundle verify`, `git diff --cached --check`, 복사한 구현·테스트 입력 121개의 원본 해시 비교, 미디어 6개 manifest 검증, 자격 증명 패턴 검사를 수행했다. 공개 소스에는 캐시·APK·로컬 SDK 경로·서명 비밀 파일을 포함하지 않았다. 복사본에서 `tool/verify_*.dart` 15개를 다시 실행해 모두 통과했다. 기존에 통과한 Flutter 테스트 265개와 분석 결과를 유지하며 이번 배포 과정에서는 앱 로직을 변경하거나 Flutter 빌드를 다시 하지 않았다.

`apksigner`와 `aapt`로 기존 빌드의 서명·패키지·버전·설치 조건을 다시 확인했다. GitHub 초안의 첨부 개수·크기·digest를 확인한 뒤 공개했다. 인증 없이 공개 API·README와 실제 APK를 요청해 HTTP 200, 공개 상태와 원본 SHA256 일치를 검증했다.

## 로컬 파일과 복구

작업 입력은 `2026Renewal`이며 C:\grus.py 전체 Git 저장소에는 커밋하거나 push하지 않았다. 배포용으로 새로 clone한 아래 저장소에서만 커밋·태그·push했다.

```text
2026Renewal/build/deployment/kv-engpzl-20261011/                 배포용 Git checkout
2026Renewal/build/deployment/kv-engpzl-before-renewal-20261011.bundle  이전 전체 Git 이력 백업
2026Renewal/build/deployment/artifacts/KVM-R1-0.1.0-alpha.apk     이름을 정리한 배포 APK
2026Renewal/build/deployment/public-verification/              공개 다운로드 검증 파일
```

백업은 완전한 Git bundle로 검증했으며 161,818,598 bytes다. `build` 아래 파일은 `flutter clean` 등의 정리로 삭제될 수 있다. 장기 보존이 필요하면 별도 위치에 백업해야 한다. 원격 Git에도 이전 커밋이 남아 있으므로 이전 트리 복구는 가능하다. 별도 승인 없이 main을 이전 상태로 되돌리거나 이력을 삭제하지 않는다.

Git 작성자 설정이 없어 배포용 checkout에만 확인된 `Crus7230` 계정의 noreply 주소를 설정했다. 전역 설정은 변경하지 않았다. 기존 전역 Git 인증 도우미는 오래된 GitHub CLI 경로를 가리켰으므로 push 명령에만 실제 설치된 CLI를 지정했다. 인증 토큰과 키 파일은 출력·복사·커밋하지 않았다.

## 다음 업데이트

1. 실제 Android에서 설치·진행·정원 복원·강제 종료 후 보드와 식 복원을 확인한다.
2. 같은 signing key를 유지하고 기존보다 높은 versionCode로 다음 APK를 빌드한다. 정식 키로 전환하면 기존 알파와 바로 업데이트되지 않을 수 있어 별도 이전 정책이 필요하다.
3. 로직 전용 APK를 제공하기 전에 전체 APK에서의 업데이트와 미디어·진행 유지 검증을 완료한다. 신규 설치에는 전체 APK를 제공한다.
4. 새 Release도 초안 첨부 검증→공개→인증 없는 다운로드 SHA256 확인 순서를 따른다. 업로드된 APK와 태그 소스가 일치해야 한다.

배포용 공개 README와 내부 README는 대상이 다르다. 공개 README는 설치 안내를 우선하고, 내부 README·구현 문서는 유지보수 기록을 보존한다. 이번 변경에서 내부 README, `.gitignore`, R1 구현 문서와 에셋 업데이트 문서에 공개 상태와 검증 경계를 반영했다.
