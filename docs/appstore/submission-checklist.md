# App Store 출시 체크리스트

**상태: 1.0 / 1.0.1 / 1.0.2 승인 완료** 🎉 — 다음 업데이트는 **1.0.3 (빌드 7)** 로 준비 중.

> ⚠️ **저장소 이름 변경 확인 필요**: `ekby0104/logger` → `yuemyname/dailogger`로 바뀌었습니다.
> App Store Connect에 등록한 **개인정보 처리방침 / 지원 URL이 GitHub Pages 주소**라면
> 예전 주소(`ekby0104.github.io/logger/...`)는 더 이상 열리지 않을 수 있습니다.
> 새 주소(`yuemyname.github.io/dailogger/privacy.html`, `.../support.html`)가 실제로 열리는지
> 브라우저로 확인하고, 안 되면 Settings → Pages를 다시 켠 뒤 App Store Connect의 URL을 갱신하세요.
> (심사원이 접속 못 하면 리젝 사유가 됩니다.)

## 제출까지 완료된 것 ☑️

- ☑️ 번들 ID(`com.dailogger.app`), 팀 서명, 위젯 타깃
- ☑️ 앱 아이콘 (1024px) + 런치 스크린
- ☑️ 권한 사유 문구 (카메라·마이크·위치)
- ☑️ 수출 규정 (`ITSAppUsesNonExemptEncryption = NO`)
- ☑️ 한국어/영어 현지화
- ☑️ App Store Connect 앱 레코드 생성, 메타데이터·스크린샷 입력
- ☑️ 개인정보 처리방침·지원 URL
- ☑️ 프라이버시 라벨 ("데이터가 수집되지 않음")
- ☑️ 빌드 업로드 → 버전 연결 → **심사 제출**

## 심사 대기 중 할 일

- [ ] App Store Connect 이메일 알림 확인 (상태: 심사 중 → 승인/거절)
- [ ] **권정애체 폰트 라이선스** 확인 — `../fonts/kwonjungae-font-story.pdf`에서
      앱 임베드/상업 사용 허용 여부. 문제가 있으면 폰트를 빼고 1.0.1 업데이트 준비
- [ ] 실기기에서 계속 사용하며 버그 수집 (1.0.1 소재)

## 승인되면

1. 수동 출시로 설정했다면 App Store Connect에서 **출시** 버튼 클릭
2. 스토어 페이지 링크 확인·공유
3. 다음 버전(1.0.1/1.1) 계획 — 백로그는 [`../03-개발명세-순서.md`](../03-개발명세-순서.md) 참고

## 거절(리젝)되면 — 흔한 사유와 대응

| 사유 | 대응 |
|---|---|
| 메타데이터 문제 (스크린샷·설명) | 해당 항목만 수정 후 재제출 (빌드 재업로드 불필요) |
| 권한 사용 설명 부족 | Info.plist 문구 보강 → 빌드 번호 올려 재업로드 |
| 데모 계정 요청 | 로그인 없음 — 심사 메모에 이미 명시되어 있으니 회신으로 안내 |
| 기능 오류 재현 | 재현 경로 확인 → 수정 → 빌드 번호 올려 재업로드 |

거절 사유는 Resolution Center(App Store Connect)에 구체적으로 오고,
회신으로 소명만 해도 통과되는 경우가 많습니다.

## 새 빌드 올리는 법 (요약)

1. 코드 수정 → 두 타깃의 `CURRENT_PROJECT_VERSION`을 +1 (현재 4)
2. 기기 선택 **Any iOS Device (arm64)** → Product → **Archive**
3. Organizer → Distribute App → App Store Connect → Upload
4. App Store Connect에서 버전에 새 빌드 연결 → 제출

## 참고: 심사 메모

1.0 제출본에는 샘플 데이터 안내가 포함되어 있었지만, **빌드 5부터 샘플 데이터가 제거**되어
다음 제출부터는 아래 문구를 사용하세요:

```
Notes for review:
- Dailogger is a fully local video diary. There are no accounts and no servers; all data stays on device.
- Camera/microphone are used to record short diary clips. Location (optional) only names the place of a moment on-device.
- The "Write with AI" button uses Apple's on-device Foundation Models on supported devices; on other devices it composes the caption from the user's own notes. No content is uploaded.
```
