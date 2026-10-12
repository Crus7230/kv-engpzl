# 로컬 설치 테스트 APK 0.1.5

2026-10-12 현재 수정본을 `0.1.5+6` 전체 APK로 빌드했다. R1·R2 각 60개, 총 120개 실제 스테이지와 특수 블록/방해 요소 진행, 확대된 월드맵 및 플로팅 추천 버튼을 포함한다. R3~R7은 업데이트 예정으로 닫혀 있다.

## 설치 파일과 호환성

- 설치 파일: `build/deployment/artifacts/KVM-R1-0.1.5-alpha.apk`.
- 크기: 65,847,614 bytes, 약 62.8 MiB.
- SHA256: `693873d06b87a3ef038eb4dcd902a8f19cce0801778d427dc718a885b10f22a3`.
- 패키지: `com.crus7230.kvm.renewal`, versionName `0.1.5`, versionCode `6`.
- Android 7.0 이상, minSdk 24, targetSdk 36, 가로 화면.
- arm64-v8a, armeabi-v7a, x86_64를 포함한 universal release APK다.
- 기존 v0.1.4와 동일한 개발용 인증서이며 APK v2 서명이 유효하다. Google Play 정식 서명으로 해석하지 않는다.

파일명의 `KVM-R1-...-alpha.apk`는 기존 시작 업데이트 selector의 파일명 계약을 유지하기 위한 명칭이다. 실제 콘텐츠는 R1·R2를 포함한다. 본 빌드 차수에서는 GitHub 업로드·릴리즈·태그·커밋을 수행하지 않았다. 이후 별도 요청으로 같은 APK를 `v0.1.5-r1-alpha`로 공개했으며 [배포 결과](GITHUB_RELEASE.md)에 다운로드·인식 검사와 커밋을 기록했다.

정상 앱 진입점 `lib/main.dart`를 빌드했다. `tool/r2_preview.dart`의 R2 검증용 리본·가상 완료 기록·별도 검증 저장 구획은 포함하지 않는다. 신규 설치는 캐릭터 선택과 필수 첫 문제부터 시작한다. 기존 Renewal 업데이트는 앱 삭제나 데이터 지우기 없이 설치하며 `expedition-1` 진행 구획을 유지한다. 실제 기기 설치·업데이트·강제 종료 복원은 아직 검증하지 않았다.

## 실행 및 검증

```powershell
flutter build apk --release --no-pub -t lib/main.dart
```

release 빌드가 성공했다. `aapt`로 패키지·버전·SDK·실행 Activity·가로 설정을 확인했고 `apksigner verify --verbose --print-certs`로 서명 유효성과 v0.1.4 인증서 일치를 확인했다. APK ZIP 안의 `r1-media-v3` 이미지 31개의 크기·SHA256을 manifest와 실제 소스 양쪽에 비교해 모두 일치했다. 설치용 복사본도 원본 APK와 SHA256이 같다. `.apk.sha256`과 `build-info-0.1.5.json`을 함께 기록했다.

직전 지도 변경 검증은 `flutter analyze --no-pub` 이슈 0개, 전체 테스트 570개 통과·조건부 배포 검증 1개 제외였다. 해당 로그는 `build/world-map-full-verification-final.log`다. 이번 빌드 차수에서는 버전 메타데이터만 올렸으며 분석·테스트를 다시 실행하지 않았다.

원본 앱·에셋·기존 APK·진행 저장을 삭제하지 않았다. 상위 Git의 `C:/grus.py` 경로 오류로 status/diff를 확인할 수 없어 로컬 커밋도 생성하지 않았다.
