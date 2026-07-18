# App Store 출시 체크리스트

위에서 아래로 순서대로 진행하면 됩니다. ☑️ 표시된 것은 이미 완료된 항목.

## 0. 이미 완료된 것 ☑️

- ☑️ 번들 ID(`com.dailogger.app`), 팀 서명, 위젯 타깃
- ☑️ 앱 아이콘 (1024px)
- ☑️ 권한 사유 문구 (카메라·마이크·위치)
- ☑️ 수출 규정 (`ITSAppUsesNonExemptEncryption = NO`)
- ☑️ 한국어/영어 현지화
- ☑️ App Store Connect 앱 레코드(dailogger) 생성

## 1. 개인정보 처리방침·지원 페이지 공개 (URL 확보)

저장소 `docs/`에 `privacy.html`, `support.html`이 준비돼 있습니다. GitHub Pages로 공개:

1. github.com/ekby0104/logger → **Settings → Pages**
2. Source: **Deploy from a branch** → Branch: `claude/harulog-wireframe-impl-1tefir`(또는 머지 후 기본 브랜치), 폴더: **/docs** → Save
3. 몇 분 후 생성되는 주소 확인:
   - 개인정보: `https://ekby0104.github.io/logger/privacy.html`
   - 지원: `https://ekby0104.github.io/logger/support.html`

> ⚠️ 무료 플랜에서 Pages는 **public 저장소**만 가능합니다. 저장소를 공개하기 싫다면
> Notion 공개 페이지에 같은 내용을 붙여넣고 그 링크를 써도 심사 통과됩니다.

## 2. 스크린샷 촬영 (필수 1세트)

**iPhone 16 Pro Max 시뮬레이터**(6.9인치)에서 촬영하면 됩니다. `⌘S`로 저장(데스크탑에 PNG 생성). 3~10장 필요, 추천 순서:

1. Today 탭 — 모먼트 몇 개 채운 상태 (첫인상)
2. 카메라 화면 — 녹화 중 (세그먼트 바 보이게)
3. 스토리 뷰어 — 필·캡션 오버레이 보이게
4. 데일리 블로그 — AI로 작성된 일기
5. 릴 미리보기 — 타임라인 카드 스타일
6. 캘린더 탭 — 기록이 쌓인 모습
7. (선택) Me 탭 / 홈 화면 위젯

> 팁: 시뮬레이터는 카메라가 없으니 실기기에서 실제 기록을 만든 뒤,
> 같은 데이터 감성으로 시뮬레이터 목업 데이터를 활용해도 되고,
> 실기기 스크린샷(6.9인치 기기라면 그대로 사용 가능)을 써도 됩니다.

## 3. App Store Connect 입력

`docs/appstore/metadata.md`의 문구를 복사해서:

1. **앱 정보**: 이름·부제 (한국어 기본, 영어 현지화 추가: 좌측 상단 언어 메뉴 → English 추가)
2. **1.0 준비 중**: 설명, 프로모션 텍스트, 키워드, 스크린샷 업로드
3. **지원 URL / 개인정보 처리방침 URL**: 1번에서 만든 주소
4. **카테고리**: 라이프스타일 / 사진 및 비디오
5. **연령 등급** 설문: 전부 "아니요" → 4+
6. **가격 및 사용 가능 여부**: 무료, 전체 국가(또는 원하는 국가)

## 4. 앱 개인정보 (프라이버시 라벨)

앱 → **앱 개인정보** 섹션 → 시작하기:

- "이 앱에서 데이터를 수집합니까?" → **아니요, 데이터를 수집하지 않습니다**
- 결과 라벨: **"데이터가 수집되지 않음"** ✅ (위치는 기기 내에서만 쓰고 전송하지 않으므로 "수집"에 해당하지 않습니다)

## 5. 심사용 빌드 & 메모

1. 최신 코드로 Archive → Upload (빌드 번호는 기존보다 커야 함)
2. 1.0 준비 중 페이지에서 **빌드 선택**
3. **앱 심사 정보 → 메모**에 아래 붙여넣기 (심사원 안내):

```
Notes for review:
- Dailogger is a fully local video diary. There are no accounts and no servers; all data stays on device.
- On first launch the app shows sample (demo) moments so screens are not empty. They can be removed via Me tab > gear > "Remove sample data".
- Camera/microphone are used to record short diary clips. Location (optional) only names the place of a moment on-device.
- The "Write with AI" button uses Apple's on-device Foundation Models on supported devices; on other devices it composes the diary from the user's own captions. No content is uploaded.
```

4. 심사 제출! (보통 1~3일 소요)

## 6. 제출 전 마지막 확인

- [ ] 실기기에서 신규 설치 후 전체 플로우 1회 점검 (권한 팝업 → 촬영 → 저장 → 블로그 → 릴)
- [ ] 샘플 데이터 제거 후 빈 화면들이 어색하지 않은지
- [ ] **권정애체 폰트 라이선스** — 동봉 PDF(`docs/fonts/`)에서 앱 임베드/상업 사용 허용 확인
- [ ] 설정 앱 → 데이로거 → 언어 영어로 바꿔서 영어 화면도 한 바퀴
