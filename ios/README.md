# Dailogger (데이로거) iOS

SwiftUI 네이티브 앱. **v1.0 (빌드 4) App Store 심사 제출 완료** 상태입니다.

## 요구 사항

- macOS + **Xcode 16 이상** (프로젝트 포맷이 Xcode 16의 폴더 동기화 방식)
- iOS 17.0+ 기기 또는 시뮬레이터
- 번들 ID `com.dailogger.app` / 위젯 `com.dailogger.app.widget`, 앱 그룹 `group.com.dailogger.app`

## 실행 방법 (맥북)

```sh
git clone <repo-url>
cd logger
git checkout claude/harulog-wireframe-impl-1tefir
open ios/Dailogger.xcodeproj
```

1. Xcode에서 프로젝트 열기
2. 프로젝트 설정 → **Signing & Capabilities** → Team에 본인 Apple ID 선택 (앱·위젯 두 타깃 모두)
3. 상단 스킴이 **Dailogger** 인지 확인 (위젯 스킴이면 앱 대신 위젯만 설치됨)
4. 기기 선택 후 `⌘R` 실행

실기기 첫 실행 시: 아이폰에서 설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 신뢰.

> 카메라는 시뮬레이터에 하드웨어가 없으므로 **실기기에서 테스트**해야 합니다.
> 시뮬레이터에서는 녹화가 목(타이머)으로 동작합니다.

원격(Claude)에서 수정한 코드 받기:

```sh
git sync   # = git checkout -- . && git pull (로컬 Xcode 변경 버리고 최신으로)
```

## 구현된 기능 (v1.0)

| 기능 | 내용 |
|---|---|
| 촬영 | AVFoundation 세그먼트 끊어찍기, 전·후면 전환, 라이브 프리뷰, 권한 거부 안내 |
| 병합·썸네일 | AVMutableComposition 합본 → Documents/Moments 저장, 실측 영상 길이 기록 |
| 위치·시간 | CoreLocation 역지오코딩 장소명 + 촬영 시각 자동 태깅 |
| 편집 | 캡션 수정, 모먼트 삭제 (뷰어 → Edit 진입 포함) |
| 스토리 뷰어 | 클립 자동 재생·자동 다음, 탭 이동 / 꾹 눌러 일시정지, 릴과 동일한 필·캡션 오버레이, **날짜 단위 재생** |
| Today 탭 | 오늘 요약 히어로 카드 + 오늘 모먼트 목록 |
| Timeline 탭 | 전체 기록을 날짜별 그룹(점선 레일)으로 표시, 최신 날짜 우선 |
| Calendar 탭 | 월간 그리드, 날짜 카드 탭 → 그 날 스토리 재생, "Read the blog" → 블로그 |
| Me 탭 | 스트릭·블로그·모먼트 통계, 블로그 아카이브(탭 → 스토리, 길게 → 블로그), 설정(폰트·리마인더·샘플 제거) |
| 데일리 블로그 | 직접 작성 + "Write with AI" 버튼 (iOS 26+ Apple Intelligence 온디바이스, 폴백 템플릿), 수정·재사용 |
| 릴 영상 | 타임라인 카드 스타일 / 풀사이즈 스타일 2종, 소셜 안전 영역 고려한 오버레이, 미리보기·공유 |
| 위젯 | 스트릭·오늘 클립 수 (systemSmall / systemMedium), 앱 그룹으로 동기화 |
| 리마인더 | 저녁 9시 로컬 알림, 그날 기록이 있으면 자동 스킵 |
| 폰트 | 권정애체(런타임 등록, 1.15배 보정) / American Typewriter / 시스템 — Me 탭에서 선택, 위젯도 연동 |
| 런치 스크린 | 종이색 배경 + 카메라 배지 아이콘 (Info.plist `UILaunchScreen`) |
| 현지화 | 한국어·영어 (String Catalogs) |
| 샘플 데이터 | 첫 실행 시 데모 모먼트 시드, Me 탭 ⚙️에서 제거 가능 |

로그인·계정·서버는 **없습니다** — 모든 데이터는 SwiftData(기기 내) + 파일로만 저장됩니다.

## 배포 (Archive → App Store Connect)

1. Signing & Capabilities → Team 확인 (두 타깃)
2. 기기 선택을 **Any iOS Device (arm64)** 로 변경
3. **Product → Archive** → Organizer → **Distribute App → App Store Connect → Upload**
4. 새 빌드를 올릴 때는 **빌드 번호를 기존보다 크게** — 프로젝트 설정 두 타깃의
   `CURRENT_PROJECT_VERSION`을 같이 올리면 됩니다 (현재 4)
5. TestFlight 확인 후 App Store Connect에서 버전에 빌드 연결 → 심사 제출

자세한 출시 절차는 [`../docs/appstore/submission-checklist.md`](../docs/appstore/submission-checklist.md) 참고.

## 구조

```
ios/
├── Dailogger.xcodeproj/       # 두 타깃: Dailogger(앱), DailoggerWidgetExtension
├── Dailogger/
│   ├── DailoggerApp.swift     # @main, SwiftData 컨테이너, 폰트 등록
│   ├── RootTabView.swift      # 탭 셸 + 커스텀 탭바 + FAB + 오버레이 라우팅
│   ├── AppModel.swift         # @Observable 앱 상태 (탭·오버레이·녹화·블로그·토스트)
│   ├── Info.plist             # UILaunchScreen만 (나머지는 빌드 설정에서 생성)
│   ├── DesignSystem/          # HL 색 토큰, 폰트 선택, hardCard, 공용 컴포넌트
│   ├── Models/                # Moment, DailyLog, SeedData, Stats
│   ├── Media/                 # MediaStore, VideoComposer, ThumbnailStore, ReelComposer
│   ├── Features/              # Today, Timeline, Calendar, Profile, Capture, Viewer, Blog
│   ├── Fonts/                 # Together-KwonJungae.otf
│   ├── FontLoader.swift       # 런타임 폰트 등록 (CTFontManager)
│   ├── ReminderService.swift  # 저녁 9시 로컬 알림
│   └── WidgetBridge.swift     # 앱 그룹으로 위젯 데이터 동기화
└── DailoggerWidget/
    ├── DailoggerWidgetBundle.swift
    ├── StreakWidget.swift     # 小/中 크기 스트릭 위젯
    └── Info.plist             # NSExtension (widgetkit-extension)
```

## 2차 릴리즈 백로그

- CloudKit 백업/동기화 (기기 변경 대비)
- App Intents (단축어로 빠른 촬영)
- 다크 모드
- 계정은 소셜 기능이 생기는 시점에만 검토 (Sign in with Apple)
