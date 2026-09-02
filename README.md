# 교회 통합 모바일 앱

Android/iOS용 Flutter 기반 교회 통합 앱입니다. 기본 실행 경로는 FastAPI Backend를
사용하며, Mock Repository는 명시적인 Debug 옵션에서만 사용합니다.

## Backend 연결

API 주소는 빌드에 하드코딩하지 않고 `dart-define`으로 전달합니다. iPhone 실기기에서는
Mac과 같은 네트워크에 연결하고 FastAPI를 외부 접속 가능하게 실행합니다.

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

cd ..
flutter run -d <IPHONE_DEVICE_ID> \
  --dart-define=API_BASE_URL=http://<MAC_LAN_IP>:8000
```

`API_BASE_URL`이 없으면 앱은 로그인 화면을 표시하지만 API 요청 시 설정 안내 오류를
보여줍니다. iOS는 Local Network 범위만 ATS 예외로 선언하며, Android의 cleartext 허용은
Debug manifest에만 있습니다.

Access/Refresh Token은 SharedPreferences에 저장하지 않습니다. iOS Keychain 및 Android
Keystore로 보호되는 앱 전용 저장소를 사용합니다. 401 응답 시 Refresh Token rotation 후
원 요청을 한 번 재시도하고, 실패하면 Token 및 앱의 사용자/교회/Permission 상태를
초기화합니다.

## 명시적 Mock 모드

Mock 모드는 Debug 빌드에서만 다음처럼 활성화할 수 있습니다.

```bash
flutter run --dart-define=USE_MOCK_REPOSITORIES=true
```

Mock 계정의 공통 로그인 비밀번호는 `test1234`입니다.

공통 로그인 비밀번호는 `test1234`입니다.

- `new@church.app`: 별도 권한 없음, 두 교회 소속
- `member@church.app`: `live.access`, `vod.view`
- `staff@church.app`: 하늘문교회 직원 권한, 브엘성회 성도 권한

Mock 방송 비밀번호는 `123456`입니다. 비밀번호 값과 검증은 UI가 아닌
`MockLiveAccessService`에 있습니다.

## 구조

- `lib/app`: 앱 조립, 세션/Active Church 전역 상태, 동적 Shell
- `lib/core`: 인증 계약, Permission 계산, Navigation 정책, Theme
- `lib/features`: 인증, 교회 선택, 홈, LIVE, Placeholder 기능
- `lib/shared`: 공통 모델과 Permission Guard

`AppState`는 로그인/로그아웃 및 교회 전환 때 Permission Context와 홈 데이터를
함께 초기화합니다. 메뉴는 `NavigationPolicy.available`이 Effective Permission에
따라 매번 생성하므로 고정 인덱스에 의존하지 않습니다.

## Mock 회원가입과 승인

로그인 화면의 회원가입에서 계정을 생성하고 Repository가 제공하는 교회 목록 중
하나에 가입을 신청할 수 있습니다. 가입 신청은 Membership 단위로 `pending`,
`approved`, `rejected` 상태를 가지며 pending 상태에서는 Role과 Permission이
적용되지 않습니다.

Mock 실행에서는 `더보기 → 개발 도구 → 가입 승인 관리`에서 Role과 사용자별
추가/제외 Permission을 선택해 승인하거나 거절할 수 있습니다. 로그인 화면의 Mock
계정 목록과 관리자 도구, 실행 중 권한 변경 도구는 Release 빌드에 노출되지 않습니다.

실제 API 모드에서도 Debug 관리자 화면은 현재 Active Church의 `member.view`,
`member.manage`, `role.view`, `permission.manage` Effective Permission에 따라 노출되며,
Backend가 매 요청 최종 권한을 다시 검사합니다.

홈/LIVE 데이터와 방송 비밀번호 검증은 아직 Mock Service 경계에 남아 있습니다. 실제
LIVE/Worship/VOD API 계약이 준비되면 해당 Repository만 교체할 예정입니다.
