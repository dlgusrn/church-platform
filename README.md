# 교회 통합 모바일 앱

Android/iOS용 Flutter 기반 교회 통합 앱의 1차 기반 구현입니다.

> 현재 작업 환경은 `*.yaml` 생성을 금지합니다. 실행 전 보안 프로필에서 해당
> 제한을 해제한 뒤 `pubspec.yaml.required.txt`를 `pubspec.yaml`로 복사하고
> `flutter pub get`을 실행해야 합니다.

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
