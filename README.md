# Dailogger (데이로거) 🎬

> **영상 한 컷 일기** — 하루의 순간을 짧은 세로 영상으로 기록하면, 스토리로 돌려보고
> AI 데일리 블로그와 릴 영상으로 엮어주는 iOS 앱.

로그인·서버 없이 모든 데이터가 기기 안에만 저장되는 완전 로컬 앱입니다.
네오브루탈리즘 디자인(잉크색 굵은 테두리, 하드 섀도우, 손글씨 폰트)이 특징이에요.

**현재 상태: v1.0 (빌드 4) App Store 심사 제출 완료** 🚀

## 주요 기능

- **모먼트 촬영** — 세그먼트 끊어찍기(AVFoundation), 전·후면 전환, 자동 병합
- **자동 태깅** — 촬영 시각 + CoreLocation 역지오코딩 장소명
- **스토리 뷰어** — 인스타 스토리 스타일 재생 (탭 이동 / 꾹 눌러 일시정지), 날짜 단위 재생
- **4개 탭** — Today(오늘), Timeline(전체 기록 날짜별), Calendar(월별), Me(블로그 아카이브)
- **AI 데일리 블로그** — Apple Intelligence 기기(iOS 26+)는 온디바이스 생성, 그 외 템플릿. 직접 수정 가능
- **릴 영상 생성** — 타임라인 카드 스타일 / 풀사이즈 스타일 2종, 앱 디자인 그대로 텍스트 오버레이, 공유 시트
- **홈 화면 위젯** — 스트릭·오늘 클립 수 (小/中 크기)
- **데일리 리마인더** — 저녁 9시, 이미 기록한 날은 스킵
- **폰트 선택** — 권정애체(손글씨) / 타자기체 / 시스템
- **한국어·영어** 지원

## 저장소 구조

```
logger/
├── ios/                 # ★ iOS 앱 (SwiftUI) — 실행 방법은 ios/README.md
│   ├── Dailogger.xcodeproj
│   ├── Dailogger/          # 앱 타깃
│   └── DailoggerWidget/    # 위젯 익스텐션
├── docs/
│   ├── appstore/        # App Store 메타데이터·출시 체크리스트
│   ├── privacy.html     # 개인정보 처리방침 (GitHub Pages용)
│   ├── support.html     # 지원 페이지 (GitHub Pages용)
│   ├── fonts/           # 권정애체 라이선스 자료
│   └── 01~03-*.md       # 화면 구조·기술 스택·개발 히스토리 (현재 기준)
├── index.html           # 최초 웹 와이어프레임 프로토타입 (참고용)
├── style.css
└── app.js
```

## 시작하기

iOS 앱 빌드·실행·배포 방법은 **[`ios/README.md`](ios/README.md)** 를 보세요.

웹 와이어프레임 프로토타입은 `index.html`을 브라우저로 열면 바로 실행됩니다
(개발 초기에 디자인 검증용으로 만든 것으로, 현재 앱 기능과는 차이가 있습니다).

## 문서

| 문서 | 내용 |
|---|---|
| [`docs/appstore/metadata.md`](docs/appstore/metadata.md) | 스토어 등록 문구 (한/영) |
| [`docs/appstore/submission-checklist.md`](docs/appstore/submission-checklist.md) | 출시 체크리스트 (제출 완료) |
| [`docs/01-화면분석-설계.md`](docs/01-화면분석-설계.md) | 화면 구조·데이터 모델 (현재 기준) |
| [`docs/02-기술스택.md`](docs/02-기술스택.md) | 실제 사용한 기술 스택 |
| [`docs/03-개발명세-순서.md`](docs/03-개발명세-순서.md) | 개발 히스토리와 남은 백로그 |
