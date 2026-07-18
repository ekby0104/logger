# HaruLog (하루로그) — Wireframe Implementation

A working implementation of the `하루로그-wireframe.dc.html` design from Claude Design.

HaruLog captures the moments of your day as short story-style videos, automatically
woven into a daily blog. This wireframe renders the full app inside an iPhone frame
with a hand-drawn, neo-brutalist look.

## Screens & interactions

- **Today** — daily summary hero card (moment count, clip reel, "Create daily blog"),
  list of today's moments; tapping a moment opens the story viewer.
- **Timeline** — vertical dashed timeline of the day's moments with media cards.
- **Calendar** — July 2026 month grid with logged-day markers; tapping a logged day
  updates the day-detail card below.
- **Me** — profile, streak/blog/moment stats, and a grid of past daily blogs.
- **Camera overlay** — opened from the center record FAB. Tap the record button to
  start/stop segments (live timer + segment bar), pick a mood chip, then continue.
- **Edit overlay** — caption input, mood selection, location/time rows,
  "Save to timeline" appends a new moment and shows a toast.
- **Story viewer overlay** — progress bars, moment details, and an Edit shortcut.

## Run

No build step — it's plain HTML/CSS/JS. Open `index.html` directly, or serve it:

```sh
python3 -m http.server 8000
# → http://localhost:8000
```

## Files

- `index.html` — page shell, phone frame, status bar
- `style.css` — design tokens and all component styles
- `app.js` — state, actions, and view rendering (vanilla JS)

## iOS App (planning)

네이티브 iPhone 앱 개발을 위한 설계 문서:

- [`docs/01-화면분석-설계.md`](docs/01-화면분석-설계.md) — 화면 구조·컴포넌트·데이터 모델 분석
- [`docs/02-기술스택.md`](docs/02-기술스택.md) — Swift 6 / SwiftUI / SwiftData / AVFoundation / Foundation Models 스택 선정
- [`docs/03-개발명세-순서.md`](docs/03-개발명세-순서.md) — SPM 모듈 구조, MVP 범위, Phase별 개발 순서
