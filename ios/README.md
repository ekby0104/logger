# HaruLog iOS

SwiftUI 네이티브 앱. `docs/` 설계 문서의 Phase 0~4에 해당하는 스캐폴드입니다.

## 요구 사항

- macOS + **Xcode 16 이상** (프로젝트 포맷이 Xcode 16의 폴더 동기화 방식)
- iOS 17.0+ 기기 또는 시뮬레이터

## 실행 방법 (맥북)

```sh
git clone <repo-url>
cd logger
git checkout claude/harulog-wireframe-impl-1tefir
open ios/HaruLog.xcodeproj
```

1. Xcode에서 프로젝트 열기
2. 프로젝트 설정 → **Signing & Capabilities** → Team에 본인 Apple ID 선택
   (무료 Apple ID면 Xcode → Settings → Accounts에서 추가)
3. 상단 기기 선택에서 **시뮬레이터** 또는 케이블로 연결한 **아이폰** 선택
4. `⌘R` 실행

실기기 첫 실행 시: 아이폰에서 설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 신뢰.

### 프로젝트가 열리지 않으면 (Xcode 15 이하 등)

```sh
brew install xcodegen
cd ios && xcodegen
open HaruLog.xcodeproj
```

## 현재 구현 상태 (Phase 0~4)

| 화면 | 상태 |
|---|---|
| Today / Timeline / Calendar / Me 탭 | ✅ 완성 (SwiftData 시드 데이터) |
| 커스텀 탭바 + 중앙 녹화 FAB | ✅ |
| Camera | ✅ UI·녹화 상태머신(타이머·세그먼트) — 프리뷰는 Phase 5에서 AVFoundation 연결 |
| Edit → 저장 → Today 반영 → 토스트 | ✅ |
| 스토리 뷰어 (좌/우 탭 이동) | ✅ — 영상 재생은 Phase 7 |
| 데일리 블로그 AI | Phase 8 예정 (Foundation Models) |

## 구조

```
ios/HaruLog/
├── HaruLogApp.swift        # @main, SwiftData 컨테이너
├── RootTabView.swift       # 탭 셸 + 커스텀 탭바 + 오버레이 라우팅
├── AppModel.swift          # @Observable 앱 상태 (탭·오버레이·녹화·토스트)
├── DesignSystem/           # HL 토큰, hardCard, 필·뱃지·버튼·토스트
├── Models/                 # Moment, DailyLog, SeedData
└── Features/               # Today, Timeline, Calendar, Profile, Capture, Viewer
```
