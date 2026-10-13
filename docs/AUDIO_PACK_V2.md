# 음원 팩 audio-v2

## 구성과 배포 범위

사용자가 추가한 MP3 3곡을 재인코딩 없이 원본과 동일한 바이트로 이식했다. 기존 음악 4곡과 자체 제작 효과음 4개는 그대로 유지한다. 음악 7곡과 효과음 4개, 총 11개 파일이다.

| 곡 | 앱 ID | 에셋 경로 |
| --- | --- | --- |
| Glass Horizon | `bgm04` | `assets/audio/bgm04.mp3` |
| Highest Point of the Swing | `bgm05` | `assets/audio/bgm05.mp3` |
| Painted Ponies Turning | `bgm06` | `assets/audio/bgm06.mp3` |

`audio-v1`을 덮어쓰지 않고 새 `audio-v2` ZIP을 별도 GitHub Release로 배포한다. 원본 BGM 폴더, 기존 APK·이미지·음원 팩과 저장 epoch는 변경하거나 삭제하지 않는다. 소스의 음악 선택 목록, manifest, Android 허용 경로·개수·크기 제한을 함께 반영한다. 기존 곡 ID와 기본 음악, 루프·백그라운드 정지·햅틱은 유지한다.

## 설치와 APK 경계

음원 팩을 공개했을 당시 최신 APK `0.1.8+9`는 `audio-v1` 주소와 4곡 목록을 고정 사용했다. 팩 업로드만으로 그 APK에 새 곡이 자동 추가되지 않는다. 음원 팩 공개 단계는 에셋 배포와 소스 반영이었으며 APK 버전업·빌드는 포함하지 않았다. 이후 앱 연결 업데이트 `0.1.9+10`을 공개했으므로 먼저 앱을 업데이트한 뒤 설정에서 audio-v2를 받고 새 곡을 선택한다. [앱 설치·검증 기록](RELEASE_NOTES_0_1_9.md)을 참고한다.

0.1.9 다운로드형 APK에는 manifest만 포함하고 MP3를 넣지 않는다. 설정에서 audio-v2 약 30MB를 동의 후 팩당 한 번 받고 이후 같은 팩을 사용하는 코드 업데이트에서는 재사용한다. 기기의 audio-v1을 삭제하거나 진행 기록을 초기화하지 않는다. 새 팩을 받지 않아도 조용히 게임을 진행할 수 있다. 새 곡을 직접 선택하면 인트로와 탐험에서 같은 곡이 이어 재생된다.

## 산출물

- 팩 ID: `audio-v2`
- 릴리즈 태그: `media-audio-v2`
- ZIP: `build/audio-pack/audio-v2/KVM-audio-v2.zip`
- ZIP 크기: `29,864,615 bytes`
- 압축 전 파일 합계: `29,948,641 bytes`
- ZIP SHA256: `9A7200A5FDEB9A0B4A1FA37F70E5A77BD94D61FC025F4FA5CD98AF608BF9A750`
- 릴리즈: https://github.com/Crus7230/kv-engpzl/releases/tag/media-audio-v2
- 다운로드: https://github.com/Crus7230/kv-engpzl/releases/download/media-audio-v2/KVM-audio-v2.zip

## 검증

- 모든 음악 7곡의 BGM 원본·이식본 크기와 SHA256 일치, 기존 audio-v1의 8개 파일 metadata 불변을 확인했다.
- `tool/verify_asset_packs.ps1`: 이미지 31개·음원 11개, ZIP 크기·SHA256 및 각 entry의 크기·SHA256을 확인했다.
- `dart tool/verify_audio_and_avatar.dart`: 7곡 목록·manifest 일치, 새 3곡 선택·장면 전환 시 재시작 방지·저장 재생성, 기존 선택·음소거·햅틱·중단 퍼즐 보존을 확인했다.
- 기존 로컬 분석기 API로 관련 Dart 43개 파일을 해석했으며 진단은 0개였다. `dart analyze` CLI는 Windows Dart perf 캐시 접근 오류로 종료되어 이 방식으로 우회했다. 시스템 캐시를 삭제하거나 변경하지 않았다.
- Android `MainActivity`·`GameAudioBridge`·`RetainedPackDownloader` Kotlin 타입 검사 통과. 업데이트 클래스만 스텁으로 대체한 좁은 소스 검사이며 APK나 실기기 검증은 아니다.
- `node tool/verify_web_audio.cjs`: 루프·같은 재생 객체 유지·백그라운드 정지·음소거·효과음·폐기 회귀 계약 통과. 가짜 Audio 기반 검사이며 실제 청취는 아니다.
- `tool/prepare_logic_only_source.ps1`: 생성 입력에서 이미지 15,617,620 bytes와 음원 29,948,641 bytes를 제외하고 manifest를 유지했다. APK는 생성하지 않았다.

- 2026-10-13 20:51:27 KST에 `media-audio-v2`를 공개했다. Release ID `411617541`, 초안 아님·알파 사전 릴리즈이며 ZIP 하나만 게시했다. APK 업데이트 표식은 넣지 않았다.
- 로그인 없는 공개 API와 실제 ZIP 다운로드의 크기·SHA256이 manifest 및 로컬 ZIP과 일치했다. 기존 릴리즈 11개와 각 asset ID·파일명·크기·digest가 보존됐다.
- 팩 및 앱 연결 소스 커밋은 `25d5a79c3f8cc77136ed6c3f493409c89b9a9436`이며 `media-audio-v2` 태그가 같은 커밋을 가리킨다.

음원 팩 공개 단계에서는 Flutter 분석·테스트·APK 빌드를 실행하지 않았다. 후속 앱 업데이트 0.1.9에서 승인된 `flutter analyze`, `flutter test`, `flutter build apk --release --no-pub -t lib/main.dart`를 실행했으며 분석 이슈 0개·전체 테스트 665개·게시 후 업데이트 인식 1개와 서명·미디어 분리·공개 APK 해시 검증을 통과했다. 실제 Android 다운로드·청취·새 곡 선택과 햅틱은 실기기에서 별도 확인해야 한다.
