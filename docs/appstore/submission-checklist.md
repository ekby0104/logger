# App Store 출시 체크리스트

**상태: v1.0 (빌드 4) 심사 제출 완료** 🎉 — 보통 1~3일 내 결과가 옵니다.

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

## 참고: 심사 메모 (제출 시 사용한 내용)

```
Notes for review:
- Dailogger is a fully local video diary. There are no accounts and no servers; all data stays on device.
- On first launch the app shows sample (demo) moments so screens are not empty. They can be removed via Me tab > gear > "Remove sample data".
- Camera/microphone are used to record short diary clips. Location (optional) only names the place of a moment on-device.
- The "Write with AI" button uses Apple's on-device Foundation Models on supported devices; on other devices it composes the diary from the user's own captions. No content is uploaded.
```
