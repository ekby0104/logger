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

## 현재 구현 상태 (Phase 0~5)

| 화면 | 상태 |
|---|---|
| Today / Timeline / Calendar / Me 탭 | ✅ 완성 (SwiftData 시드 데이터) |
| 커스텀 탭바 + 중앙 녹화 FAB | ✅ |
| Camera | ✅ **실제 AVFoundation 녹화** — 라이브 프리뷰, 세그먼트 끊어찍기, 전·후면 전환, 권한 거부 처리. 시뮬레이터에선 목(타이머) 동작 |
| 세그먼트 병합·썸네일 | ✅ AVMutableComposition 병합 + AVAssetImageGenerator 썸네일 → Documents/Moments 저장 |
| Edit → 저장 → Today 반영 → 토스트 | ✅ 실제 영상·썸네일 연결 |
| 스토리 뷰어 | ✅ 클립 자동 재생 + 끝나면 자동으로 다음 모먼트, 진행 바 실시간 표시, 꾹 눌러 일시정지, 좌/우 탭 이동 (Phase 7 완료) |
| 위치·시간 | ✅ CoreLocation + 역지오코딩으로 실제 장소명·좌표 저장, 카메라·편집 화면에 실시각 표시 |
| 모먼트 수정 | ✅ 뷰어 → Edit에서 캡션·무드를 기존 모먼트에 반영 (새로 생성 X) |
| 데일리 블로그 | ✅ Phase 8 완료 — Apple Intelligence 기기(iOS 26+)는 온디바이스 AI로, 그 외에는 템플릿으로 일기 생성. 오늘의 DailyLog에 저장·재사용 |
| 스트릭·통계 | ✅ 실제 계산 (연속 기록일, 블로그 수, 모먼트 수) |
| 클립 릴 썸네일 | ✅ Today 히어로·캘린더 상세에 실제 썸네일 표시 |
| 샘플 데이터 제거 | ✅ Me 탭 ⚙️ → "Remove sample data" (실제 녹화·블로그는 유지) |
| 계정·로그인 | 2차 릴리즈 백로그 (Sign in with Apple 예정) |

> 카메라는 시뮬레이터에 하드웨어가 없으므로 **실기기(아이폰 케이블 연결)에서 테스트**해야 합니다.
> 첫 진입 시 카메라·마이크 권한 팝업이 뜹니다.

## TestFlight 배포 절차

1. **App Store Connect에서 앱 등록** (최초 1회): [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → 앱 → ＋ → 신규 앱
   - 플랫폼 iOS, 이름 `하루로그`(또는 HaruLog), 번들 ID `com.ekby0104.harulog`(Xcode에서 Team 선택 시 자동 등록됨), SKU는 아무 문자열
2. Xcode: Signing & Capabilities → **Team 선택** 확인
3. 상단 기기 선택을 **Any iOS Device (arm64)** 로 변경
4. 메뉴 **Product → Archive**
5. 완료되면 Organizer 창 → **Distribute App → App Store Connect → Upload** (기본값으로 진행)
6. 10~30분 후 App Store Connect → 앱 → **TestFlight 탭**에 빌드가 나타남
7. 내부 테스팅 → 그룹 생성 → 본인(Apple ID) 추가
8. 아이폰에 **TestFlight 앱** 설치 → 초대 수락 → 설치 완료 🎉

이후 새 버전을 올릴 때는 4~5번만 반복하면 됩니다 (빌드 번호는 Xcode가 자동 증가하도록 General → Identity에서 Build 값을 올리거나 `agvtool` 사용).

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
