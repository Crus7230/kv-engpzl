# KVM 기존 앱 감사 보고서

## 1. 목적과 조사 범위

이 문서는 2025년 Kotlin/Jetpack Compose 기반 KVM 수학 퍼즐 앱을 Flutter/Dart로 리뉴얼하기 전에 확인한 구조, 실행 흐름, 데이터 원천, 치명 결함, 화면 캡처 가능성, 용량 현황을 기록한다.

- 조사 대상: 저장소 루트의 kvm, Apk Version, Badge, PNGs, res
- 조사 방식: 소스와 파일 구조의 읽기 전용 정적 분석
- 제외 사항: 기존 앱 실행, APK 설치, Flutter 실행·빌드, 파일 삭제
- 조사 시점의 2026Renewal: Flutter 기본 스캐폴드만 생성된 상태

라인 번호는 조사 시점 파일을 기준으로 한다.

후속 실행 기록: 감사 완료 후 SHA-256이 원본과 완전히 같은 `PNGs/badges/copy` 50개와 `Badge/copy` 49개를 삭제해 92.17 MiB를 확보했다. 각 원본은 상위 폴더에 남아 있으며, 동일하지 않은 `Badge/copy/ic_b_master.svg`와 버전 이력일 수 있는 구버전 APK는 보존했다. 아래 용량 표는 삭제 후 재계측한 현재 스냅샷이다.

후속 구현 기록: 2026Renewal에는 현재 Android와 Web 대상, 퍼즐 도메인 모델·수식 AST, 고정 샘플 문제, 반응형 퍼즐 화면과 기본 접근성 처리가 추가되어 초기 구현을 완료했다. 순수 Dart 핵심 엔진 검증은 통과했다. 다만 Flutter analyze·test·run과 Android·Chrome 수동 플레이는 아직 수행하지 않았고, 상태별 fixture·golden 산출물도 미완료다.

## 2. 저장소 구성

| 경로 | 역할 | 현황 |
| --- | --- | --- |
| kvm/ | 기존 Kotlin 소스 | Kotlin 48개, 약 6,808줄 |
| Apk Version/ | 배포 APK 보관 | KvMA_1.0.apk부터 KvMA_2.1.apk까지 12개 |
| Badge/ | 뱃지 원본·복사본·구버전 | SVG, PNG, ZIP, PDF가 혼재 |
| PNGs/ | 캐릭터·뱃지 PNG | 앱 이식 후보 에셋 |
| res/ | 배경·아이콘·폰트 ZIP | Android 표준 res 구조가 아닌 작업 자료 폴더 |
| 2026Renewal/ | 신규 Flutter 앱 | 기존 앱과 분리된 리뉴얼 작업 위치 |

기존 폴더에는 Gradle 설정, AndroidManifest.xml, gradlew, 정상적인 Android res/drawable·res/font 트리, assets/problems.json이 없다. 따라서 loose Kotlin 소스만으로는 기존 앱을 재빌드할 수 없다.

## 3. 기술 스택과 진입점

기존 앱은 Dart 앱이 아니라 Android 네이티브 앱이다.

- 언어: Kotlin
- UI: Jetpack Compose, Material 3
- 내비게이션: Navigation Compose
- 로컬 저장: Room Database version 5
- 비동기 처리: Kotlin Coroutines
- JSON 변환: Gson
- 패키지: com.user.kvm

MainActivity가 Compose 테마와 AppNavigation을 설치한다.

- 근거: kvm/MainActivity.kt:18-25
- 시작 경로: kvm/MainActivity.kt:35

화면 경로는 다음과 같다.

1. intro
2. world_map
3. stage_select/{territoryId}
4. problem_screen/{stageId}
5. character_screen
6. badge_screen

- 근거: kvm/MainActivity.kt:35-78

## 4. 화면과 게임 흐름

### 4.1 인트로

인트로는 사용자 프로필 생성 또는 출석 갱신, 뱃지 판정, 로고 애니메이션을 한 Composable의 LaunchedEffect에서 처리한다.

- 최초 프로필 및 출석: kvm/screens/IntroScreen.kt:41-77
- 1.5초 간격 애니메이션: kvm/screens/IntroScreen.kt:79-84
- 월드맵 이동: kvm/screens/IntroScreen.kt:97-104

### 4.2 월드맵

월드맵은 영토별 누적 별을 Room에서 읽고 이전 영토에서 별 100개 이상 획득했는지에 따라 다음 영토를 연다.

- 별 집계와 해금 조건: kvm/screens/WorldMapScreen.kt:51-70
- 영토 선택: kvm/screens/WorldMapScreen.kt:103-121
- 캐릭터·뱃지 화면 이동: kvm/screens/WorldMapScreen.kt:124-134

개발자 메뉴가 일반 화면에 그대로 노출되어 모든 캐릭터·뱃지·스테이지 해금과 전체 데이터 초기화를 제공한다.

- 근거: kvm/screens/WorldMapScreen.kt:136-189

### 4.3 영토와 스테이지

영토는 7개이며 1~6영토는 각 100개, 지혜의 정상은 150개로 총 750개 스테이지다.

- 근거: kvm/data/TerritoryData.kt:15-30

스테이지는 저장된 콘텐츠가 아니다. StageManager가 ID를 받을 때마다 해당 구간 규칙에서 일반 템플릿 4개와 고난도 템플릿 1개를 무작위 복원추출하고 다시 섞는다.

- 규칙 정의: kvm/StageManager.kt:19-85
- 즉석 생성: kvm/StageManager.kt:92-108

같은 스테이지도 다시 열면 문제 구성이 달라질 수 있고, 생성 seed와 난도 파라미터는 저장되지 않는다.

### 4.4 문제 생성

문제 화면의 실행 파이프라인은 다음과 같다.

StageManager
→ ProblemScreen
→ MainGenerator
→ Room의 문제 템플릿 + ProblemLogicManager의 정답 람다
→ 유형별 Generator
→ Problem
→ ExpressionEvaluator

- 5문제 병렬 생성: kvm/screens/ProblemScreen.kt:81-101
- 생성기 분배: kvm/MainGenerator.kt:24-60
- 생성기 공통 계약: kvm/generators/IProblemGenerator.kt:10-21
- 결과 모델: kvm/Models.kt:39-45

ID 첫 글자로 생성기를 선택한다.

| 접두사 | 유형 |
| --- | --- |
| P, C | 계산·혼합계산 |
| U | 단위·측정 |
| G | 도형 |
| B | 자료해석 |
| E | 관계·방정식 |
| R | 규칙·패턴 |
| W | 융합 |

### 4.5 플레이와 판정

사용자는 블록 은행에서 숫자와 연산자를 눌러 풀이 식을 만들고, 식의 정수 결과가 Problem.answer와 같으면 통과한다.

- 블록 이동: kvm/screens/ProblemScreen.kt:219-240
- 제출 판정: kvm/screens/ProblemScreen.kt:163-176
- 중위식→후위식→정수 계산: kvm/ExpressionEvaluator.kt:18-72

지원 문법은 정수와 +, -, ×, ÷, 괄호뿐이다. 등호, 미지수, 소수, 분수, 정확한 유리수는 모델링하지 않는다. 따라서 현재 핵심 경험은 엄밀한 “문장을 식으로 변환”이라기보다 “블록으로 같은 정숫값을 만드는 사칙연산 퍼즐”에 가깝다.

### 4.6 보상과 부가 시스템

스테이지는 패스 사용 여부와 오답 횟수에 따라 별 1~3개를 준다.

- 별 계산과 진행 저장: kvm/screens/ProblemScreen.kt:127-152

캐릭터는 별을 소비해 순차 가격으로 구매하며 총 26종이다.

- 캐릭터 데이터: kvm/data/CharacterData.kt:13-41
- 가격과 구매: kvm/screens/CharacterViewModel.kt:33-80

뱃지는 출석, 영토, 별, 캐릭터, 완벽 클리어, 블록 사용, 분야별 해결 수를 기준으로 총 49종이 정의되어 있다.

- 뱃지 카탈로그: kvm/data/BadgeData.kt:19-89
- 획득 판정: kvm/BadgeManager.kt:17-38

## 5. 저장 구조

Room DB version 5에 다음 7개 Entity가 등록되어 있다.

1. UserProfile
2. Character
3. StageProgress
4. UserBadge
5. ProblemTypeLog
6. ProblemTemplateEntity
7. HintMessageEntity

- 근거: kvm/database/AppDatabase.kt:15-40

저장 대상은 별 잔액, 대표 캐릭터, 출석, 블록 사용 수, 스테이지 최고 별과 클리어, 완벽 클리어 수, 캐릭터·뱃지 획득, 분야별 해결 수, 문제 템플릿과 힌트다.

문제 화면에서 실제로 갱신하는 값은 스테이지 진행도, 별 잔액, 뱃지뿐이다.

- 근거: kvm/screens/ProblemScreen.kt:127-151

totalBlocksUsed와 ProblemTypeLog를 증가시키는 코드는 없다. 그 결과 블록 마스터와 분야별 전문가 뱃지는 정상 플레이만으로 획득할 수 없다.

- 요구하는 값: kvm/BadgeManager.kt:22-33, 63-65, 87-95

스테이지 저장, 별 갱신, 뱃지 판정은 한 트랜잭션이 아니라 순차 실행된다.

## 6. 데이터 진실 원천

현재 문제 데이터에는 서로 다른 세 원천이 있다.

| 원천 | 내용 | 수량·상태 | 런타임 사용 |
| --- | --- | --- | --- |
| 최신 KvMA_2.1.apk의 assets/problems.json | 문장, 해설, 컴포넌트, 힌트 | 303개 템플릿 | 실제 배포본의 우선 기준 |
| kvm/GameData.kt | 문장, 해설, 컴포넌트, 정답 람다 | 고유 296개 | 현재 loose 실행 경로에서 직접 사용하지 않음 |
| kvm/ProblemLogicManager.kt | ID별 정답 람다 | 고유 296개, 4개 중복 선언 | MainGenerator가 사용 |
| kvm/StageManager.kt | 스테이지별 활성 템플릿 목록 | 고유 47개 참조 | 현재 플레이 진입점 |

근거:

- 레거시 템플릿: kvm/GameData.kt:138-1920
- 정답 로직: kvm/ProblemLogicManager.kt:3-312
- 중복된 W_DST_MEET_01, W_DST_CHASE_01, W_DST_AVGSPD_01, W_WORK_TIME_01: kvm/ProblemLogicManager.kt:276-309
- JSON 초기화 경로: kvm/database/DatabaseInitializer.kt:36-65
- 활성 스테이지 규칙: kvm/StageManager.kt:19-85

리뉴얼의 원본 우선순위는 최신 APK의 303개 JSON → 현재 활성 47개 규칙 → loose 296개 템플릿/로직 대조 순서로 잡는다. 데이터 변환과 체크섬 보존이 완료되기 전에는 GameData.kt를 삭제하지 않는다.

## 7. P0 결함

### P0-1. 중복 토큰 삭제

정답 블록과 방해 블록을 합친 후 distinct()를 적용한다.

- 근거: kvm/screens/ProblemScreen.kt:104-123

동일한 숫자, 연산자, 괄호가 여러 번 필요한 식의 토큰이 하나만 남는다. 블록은 이동 시 은행에서 제거되므로 재사용도 불가능하다.

항상 또는 자주 실패하는 예:

- a × a: kvm/generators/GeometryGenerator.kt:98-102
- A × k × k: kvm/generators/GeometryGenerator.kt:134-139
- 복합도형: kvm/generators/GeometryGenerator.kt:121-131
- 가중평균: kvm/generators/DataAnalysisGenerator.kt:120-134
- 두 구간 이동: kvm/generators/WisdomGenerator.kt:80-90

### P0-2. 후반 스테이지 생성 예외

지혜의 정상 101~140 구간은 생성기가 만들지 않는 변수를 정답 람다가 강제 참조한다.

- 고급 스테이지 규칙: kvm/StageManager.kt:82-84
- W_DST_MEET_01, W_DST_CHASE_01이 요구하는 d: kvm/ProblemLogicManager.kt:276-278
- 거리 생성기가 제공하는 변수: kvm/generators/WisdomGenerator.kt:80-90
- W_MIX_TARGET_01이 요구하는 ct: kvm/ProblemLogicManager.kt:282-287
- 혼합 생성기가 제공하는 변수: kvm/generators/WisdomGenerator.kt:106-115

awaitAll()에서 한 문제가 예외를 내면 스테이지의 전체 문제 목록을 빈 목록으로 바꾼다.

- 근거: kvm/screens/ProblemScreen.kt:86-93

### P0-3. 정답과 제공 블록 불일치

범용 생성기가 같은 접두사의 여러 템플릿에 동일한 블록 식을 사용해 실제 정답 공식과 어긋난다.

- U_LEN_08 공식: kvm/GameData.kt:494-499
- 모든 U_LEN에 동일한 n1 × 1000 + n2 제공: kvm/generators/UnitGenerator.kt:90-100
- W_WORK_TIME_01 공식: kvm/ProblemLogicManager.kt:291
- W_WORK에 (a+b) × t 제공: kvm/generators/WisdomGenerator.kt:118-127
- E_SYSTEM, E_WORK에 빈 answerBlocks 제공: kvm/generators/AlgebraGenerator.kt:150-169

### P0-4. 불완전한 수식 검증

ExpressionEvaluator는 마지막 스택에 값이 정확히 하나 남았는지 확인하지 않는다. 연속된 숫자나 여분 토큰을 포함한 불완전식도 마지막 값만 맞으면 통과할 수 있다.

- 근거: kvm/ExpressionEvaluator.kt:61-72

판정도 의도한 교육용 식 구조가 아니라 결과 정수만 비교한다.

- 근거: kvm/screens/ProblemScreen.kt:163-176

### P0-5. DB 초기화와 마이그레이션

4→5 마이그레이션은 문제·힌트 테이블만 빈 상태로 만들며 JSON 삽입은 DB onCreate에서만 실행한다. 기존 v4 사용자가 v5로 이동하면 신규 테이블이 비어 있을 수 있다.

- 테이블 생성: kvm/database/AppDatabase.kt:64-84
- onCreate 초기화: kvm/database/AppDatabase.kt:87-110

지원되지 않는 버전은 fallbackToDestructiveMigration()으로 사용자 진행 데이터를 잃을 수 있다.

- 근거: kvm/database/AppDatabase.kt:109-112

### P0-6. 컴파일 불가능한 중복 초기화 파일

kvm/database/DatabaseInitializer_updated.kt는 같은 패키지에 DatabaseInitializer를 다시 선언하고, 존재하지 않는 TemplateHint와 insertTemplateHints를 참조한다.

- 기존 객체: kvm/database/DatabaseInitializer.kt:29-31
- 중복 객체와 미완성 참조: kvm/database/DatabaseInitializer_updated.kt:28-30, 63-76

### P0-7. 세션 복구 불가

문제 목록, 현재 인덱스, 식, 오답 수, 패스 여부가 모두 remember 메모리 상태다. 회전, 프로세스 종료, 앱 재시작 시 세션을 복원하지 못한다.

- 근거: kvm/screens/ProblemScreen.kt:61-79

## 8. 추가 위험

- 방해 숫자 생성 while 루프는 가능한 양수 후보가 두 개 미만인 경우 종료되지 않을 수 있다.
  - kvm/screens/ProblemScreen.kt:109-117
- 템플릿 치환 뒤 미해결 {placeholder}를 검사하지 않는다.
  - 예: kvm/generators/GeometryGenerator.kt:51-65
- 최초 대표 캐릭터 기본값이 빈 문자열, null, char_default_hero로 충돌한다.
  - kvm/database/AppDatabase.kt:99-104
  - kvm/database/UserProfile.kt:15-20
  - kvm/screens/IntroScreen.kt:50-73
- 문제 유형 로그는 UI에서 Title Case를 기대하지만 BadgeManager는 대문자 키를 조회한다.
  - kvm/screens/BadgeViewModel.kt:82-87
  - kvm/BadgeManager.kt:87-95
- 개발자 초기화 메뉴가 배포 UI에 노출되어 있다.
  - kvm/screens/WorldMapScreen.kt:136-189

## 9. 화면 캡처 현황

### 기존 앱

loose source는 재빌드할 수 없지만 Apk Version/KvMA_2.1.apk를 Android 기기나 에뮬레이터에 설치하면 실제 화면 캡처가 가능하다. 조사 시점에는 연결된 Android 기기와 사용 가능한 AVD가 없어 실행 캡처를 만들지 않았다.

캡처 시 권장 기준 화면:

1. 인트로
2. 월드맵
3. 스테이지 선택
4. 문제 기본 상태
5. 식 구성 중
6. 오답 피드백
7. 해설
8. 스테이지 클리어
9. 캐릭터 상점
10. 뱃지 보관함

### 신규 Flutter 앱

2026Renewal에는 Android와 Web 대상만 생성되어 있다. 현재 소스의 고정 샘플 문제는 Chrome/web 또는 Android에서 캡처할 수 있는 기반이지만, 이번 작업에서는 Flutter 앱을 실행하지 않아 신규 화면 캡처를 생성하지 않았다. Windows 데스크톱 대상은 생성되어 있지 않다.

도메인 AST와 기본 UI 접근성 처리는 초기 구현을 완료했으며 순수 Dart 핵심 엔진 검증은 통과했다. 그러나 Flutter analyze·test·run과 Android·Chrome 수동 플레이는 미완료이므로 vertical slice 전체 완료를 주장하지 않는다. 초기·식 구성·오답·힌트·정답 상태별 fixture 카탈로그와 golden 테스트도 아직 미완료다. 향후 캡처 파일에는 플랫폼, 화면 크기, fixture 또는 seed, 콘텐츠 버전을 포함한다.

## 10. 용량 현황과 정리 원칙

다음 표는 중복 파일 99개를 삭제한 뒤 다시 계측한 현재 스냅샷이다. 정리 전에는 약 1,109.54 MiB였으며 92.17 MiB를 확보했다.

| 폴더 | 파일 수 | 크기 |
| --- | ---: | ---: |
| Apk Version | 12 | 744.01 MiB |
| Badge | 177 | 168.12 MiB |
| res | 65 | 55.87 MiB |
| PNGs | 81 | 48.61 MiB |
| kvm | 48 | 0.32 MiB |
| 합계 | 383 | 약 1,017 MiB |

확장자 기준 큰 항목은 APK 744.01 MiB, ZIP 99.33 MiB, PNG 88.26 MiB, SVG 82.12 MiB다.

완료된 정리:

- `PNGs/badges/copy`의 SHA-256 동일 중복 50개 삭제
- `Badge/copy`의 SHA-256 동일 중복 49개 삭제
- 상위 폴더의 동일 원본과 고유 파일 `Badge/copy/ic_b_master.svg` 보존

추가 정리 후보:

- KvMA_1.0.apk부터 KvMA_2.0.apk까지 구버전 APK
- Badge/old
- 압축을 푼 원본과 함께 남은 중복 ZIP
- 미완성 DatabaseInitializer_updated.kt
- 테스트 전용 TestActivity.kt
- 사용되지 않는 BadgeScreen의 rememberBadgeProgressList
- 데이터 이식 완료 후 레거시 GameData.kt

삭제 전 완료 조건:

1. 최신 APK와 문제 JSON의 체크섬·복사본을 보존한다.
2. 303개 템플릿의 정규화 결과와 원본 ID 매핑을 확정한다.
3. 사용 에셋 목록과 해시 기반 중복 목록을 만든다.
4. 신규 Flutter 화면에서 필요한 원본 품질 에셋을 확인한다.
5. 삭제 대상을 별도 목록으로 검토하고 정확한 경로 단위로 승인한다.

## 11. 리뉴얼에 유지할 핵심 가치

- 문장을 읽고 필요한 수량과 관계를 식으로 바꾸는 핵심 학습 경험
- 짧은 스테이지 단위와 즉각적인 정오답 피드백
- 별, 캐릭터, 뱃지를 통한 장기 목표
- 계산, 패턴, 단위, 관계, 도형, 분석, 융합의 넓은 콘텐츠 축

구현 구조와 시각 표현은 새로 설계하되 위 네 가지 가치는 검증된 데이터와 함께 단계적으로 이식한다.
