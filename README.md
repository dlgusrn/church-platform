# 교회 통합 모바일 앱

Android/iOS용 Flutter 기반 교회 통합 앱의 인증·교회 Membership 기반 구현입니다.

## Mock 계정

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

Debug 실행에서는 `더보기 → 개발 도구 → Mock 가입 승인 관리`에서 Role과 사용자별
추가/제외 Permission을 선택해 승인하거나 거절할 수 있습니다. 로그인 화면의 Mock
계정 목록과 관리자 도구, 실행 중 권한 변경 도구는 Release 빌드에 노출되지 않습니다.
