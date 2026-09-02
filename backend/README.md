# Church App Backend

교회 통합 앱의 FastAPI Backend입니다. 개발 구성은 Mac에서 FastAPI를 실행하고 Docker에는
MySQL 8.4만 실행합니다. Flutter 앱과 독립된 `backend/` 경계를 유지하며 의존 방향은
Router → Service → Repository → SQLAlchemy Session입니다.

## 기술 스택

- Python 3.12+
- FastAPI, Pydantic v2, pydantic-settings
- SQLAlchemy 2.x, Alembic
- MySQL 8.4, PyMySQL
- PyJWT Access/Refresh Token
- pwdlib Argon2 Password Hash
- pytest, HTTPX

## 1. MySQL 실행

저장소 루트에서 실행합니다.

```bash
docker compose -f docker-compose.dev.json up -d
docker compose -f docker-compose.dev.json ps
```

`docker-compose.dev.json`은 로컬 개발 전용이며 다음 기본값을 사용합니다.

- Host/Port: `127.0.0.1:3307`
- 개발 DB: `church_app`
- 테스트 DB: `church_app_test`
- Application User: `church_app`
- 문자셋/Collation: `utf8mb4` / `utf8mb4_0900_ai_ci`
- DB timezone: UTC

기본 비밀번호에는 개발 전용임을 나타내는 값만 들어 있습니다. 운영 환경에서 이 Compose
파일이나 기본값을 사용하면 안 됩니다. 다른 로컬 값을 사용할 때는
`CHURCH_MYSQL_PASSWORD`, `CHURCH_MYSQL_ROOT_PASSWORD` 등의 환경변수를 Compose 실행 전에
설정하십시오. Backend는 root 계정을 사용하지 않습니다.

현재 작업 환경 정책은 `*.yml`/`*.yaml` 생성을 허용하지 않아 Compose 사양을 동등한 JSON
형식으로 제공합니다.

Health 상태 확인:

```bash
docker inspect --format='{{json .State.Health.Status}}' church-app-mysql-dev
```

초기화 스크립트는 DB와 권한만 준비합니다. Application Table은 만들지 않으며 Alembic이
Schema의 유일한 Source of Truth입니다.

## 2. Python 가상환경

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## 3. 환경변수

애플리케이션은 `.env` 파일을 자동으로 읽지 않고 프로세스 환경변수만 사용합니다.
`environment.example`의 값은 위 Docker 개발 구성과 일치합니다.

```bash
set -a
source environment.example
set +a
```

실제 Secret 파일은 Git에 추가하지 마십시오. 저장소는 `.env`, `.env.*`, `*.local.env`를
ignore합니다. 현재 실행 환경 정책 때문에 `.env.example` 대신 `environment.example`을
사용합니다.

## 4. Migration

개발 DB와 테스트 DB 모두 동일한 Migration을 적용합니다.

```bash
alembic upgrade head
DATABASE_URL="$TEST_DATABASE_URL" alembic upgrade head
alembic current
DATABASE_URL="$TEST_DATABASE_URL" alembic current
```

초기 Migration은 다음 Table을 만듭니다.

- `users`, `churches`, `church_memberships`
- `roles`, `permissions`, `role_permissions`
- `membership_permission_overrides`, `refresh_tokens`
- Alembic 관리용 `alembic_version`

SQLAlchemy `create_all()`로 Migration을 우회하지 않습니다.

### 개발 DB 완전 초기화

과거 실패한 Migration 때문에 `church_app`이 partial schema 상태인 경우 아래 전용
스크립트로 개발 DB만 삭제·재생성하고 Alembic head를 처음부터 적용합니다.

> 이 명령은 `church_app`의 User, Membership, Token 등 개발 데이터를 모두 삭제합니다.
> 명시적인 `APP_ENV=development`, `DATABASE_URL`의 DB 이름, 확인 인자가 모두 정확해야 실행되며
> `church_app_test` 또는 다른 DB는 거부합니다.

```bash
python -m app.scripts.reset_development_database --confirm-database church_app
alembic current
alembic heads
python -m app.scripts.seed_permissions
python -m app.scripts.seed_development_data
```

정상 상태에서는 `alembic current`가 `20260901_0001 (head)`를 출력하며, Alembic 관리
Table 외에 Application Table 8개가 생성됩니다.

## 5. Permission과 System Role Seed

Seed는 개발 DB에서 실행합니다. 두 번 실행해도 Permission, Role, Mapping이 중복되지
않도록 구현되어 있습니다.

```bash
python -m app.scripts.seed_permissions
python -m app.scripts.seed_permissions
```

- Permission: 30개
- `member`: `live.access`, `vod.view`
- `staff`: 앱의 직원 기본 Permission 11개
- `admin`: 전체 Permission

Role은 Permission 묶음일 뿐이며 Role 이름을 접근 판정에 사용하지 않습니다.

## 6. 테스트

Unit Test:

```bash
pytest -m "not integration"
```

MySQL Integration Test는 `TEST_DATABASE_URL`만 사용합니다. URL의 DB 이름에 `test`가
없으면 테스트가 즉시 실패하므로 `church_app` 개발 DB에서는 실행되지 않습니다.
테스트 session 시작 시 fixture가 테스트 DB에 `alembic upgrade head`를 적용하고,
Alembic revision과 필수 8개 Table을 확인한 후에만 테스트를 실행합니다.

```bash
pytest -m integration
pytest
```

`alembic_version`은 head이지만 Table이 누락된 기존 테스트 DB처럼 Schema drift가 감지되면
테스트는 자동으로 `create_all()`을 실행하지 않고 명확한 오류로 중단됩니다. 이 경우
다음 명령으로 `church_app_test`만 삭제·재생성하고 Alembic head를 적용합니다.

> 아래 명령은 `church_app_test`의 데이터를 모두 삭제합니다. `church_app` 개발 DB에는
> 접근하지 않으며, 확인 인자가 `TEST_DATABASE_URL`의 DB 이름과 정확히 일치해야 합니다.

```bash
python -m app.scripts.reset_test_database --confirm-database church_app_test
DATABASE_URL="$TEST_DATABASE_URL" alembic current
alembic heads
pytest -m integration
pytest
```

Integration Test는 다음을 검증합니다.

- Alembic Table, Unique Constraint, Foreign Key, MySQL Enum
- nullable email/phone과 email/phone unique
- `(user_id, church_id)` Membership unique
- Permission/System Role Seed 2회 실행 멱등성
- Register/Login/Refresh/Current User/Health API
- Argon2 hash 저장과 Refresh Token rotation/reuse 거부
- OpenAPI에 필수 Endpoint 노출

테스트는 외부 Transaction으로 감싸고 종료 시 rollback합니다. 운영 DB를 테스트에 연결하지
마십시오.

## 7. Backend 실행

```bash
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- Swagger UI: <http://127.0.0.1:8000/docs>
- OpenAPI JSON: <http://127.0.0.1:8000/openapi.json>

Health:

```bash
curl http://127.0.0.1:8000/api/v1/health
curl http://127.0.0.1:8000/api/v1/health/database
```

Register:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test User","email":"test@example.com","password":"<strong-password>"}'
```

Login:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"identifier":"test@example.com","password":"<strong-password>"}'
```

Refresh Token은 사용 즉시 폐기되고 새 Refresh Token으로 교체됩니다.

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/refresh \
  -H 'Content-Type: application/json' \
  -d '{"refresh_token":"<refresh-token>"}'
```

Current User:

```bash
curl http://127.0.0.1:8000/api/v1/users/me \
  -H 'Authorization: Bearer <access-token>'
```

## 데이터 초기화

다음 명령은 개발 DB와 테스트 DB를 포함한 Docker Volume 데이터를 모두 삭제합니다.
복구할 수 없으므로 로컬 개발 데이터를 버려도 되는 경우에만 실행하십시오.

```bash
docker compose -f docker-compose.dev.json down -v
docker compose -f docker-compose.dev.json up -d
```

Volume을 다시 만들면 초기화 스크립트가 `church_app`과 `church_app_test`를 준비합니다.
그 후 개발 DB와 테스트 DB에 Alembic Migration을 다시 실행해야 합니다.

## 인증·권한 원칙

- 이메일은 trim/lowercase, 휴대전화는 숫자 canonical 형태로 Service에서 정규화합니다.
- 비밀번호는 Argon2 hash만 저장합니다.
- JWT에는 `sub`, `type`, `iat`, `exp`, `jti`만 저장합니다.
- Refresh Token 원문은 DB에 저장하지 않고 SHA-256 hash만 저장합니다.
- Membership이 `approved`가 아니면 Effective Permission은 빈 집합입니다.
- Effective Permission은 Role Permission + grant override - deny override입니다.
- Native Android/iOS 요청은 브라우저 CORS 대상이 아니며 Web Origin만 명시적으로 허용합니다.

## Church와 Membership API

- `GET /api/v1/churches`
- `POST /api/v1/churches/{church_id}/memberships`
- `GET /api/v1/users/me/memberships`
- `GET /api/v1/memberships/{membership_id}/permissions`
- `GET /api/v1/churches/{church_id}/memberships/pending`
- `POST /api/v1/churches/{church_id}/memberships/{membership_id}/approve`
- `POST /api/v1/churches/{church_id}/memberships/{membership_id}/reject`
- `PATCH /api/v1/churches/{church_id}/memberships/{membership_id}/permissions`
- `GET /api/v1/churches/{church_id}/roles`

관리 API는 Role 이름이 아닌 target Church의 approved Membership에서 매 요청 계산한
Effective Permission을 검사합니다. JWT에는 Permission을 저장하지 않으므로 Role이나
Override 변경이 기존 Access Token에도 즉시 반영됩니다.

개발 교회 Seed는 production startup과 분리되어 있습니다.

```bash
python -m app.scripts.seed_development_data
```

이 Seed는 기존 개발 DB의 `skydoor`/`beersheba` row가 있으면 삭제하거나 재생성하지
않고 동일한 `churches.id`에서 각각 `skygate`/`beer`로 변경합니다. 따라서 기존
Membership의 FK 관계가 유지되며, 반복 실행해도 이전 code의 Church가 다시 생성되지
않습니다.

최초 관리자는 기존 User와 Church가 준비된 뒤 HTTP 우회 없이 Bootstrap Script로
연결합니다. Permission/System Role Seed를 먼저 실행해야 합니다.

```bash
python -m app.scripts.bootstrap_admin \
  --identifier admin@example.com \
  --church-code skygate
```

스크립트는 해당 User/Church의 Membership만 approved로 만들고 System admin Role을
연결합니다. User나 Church를 자동 생성하지 않으며 반복 실행해도 Membership을 중복
생성하지 않습니다.

## 향후 SMS 인증 확장

`phone_verifications` Model과 Repository/Service, `/api/v1/auth/phone/*` Router를 추가할 수
있습니다. `users.phone`과 `phone_verified_at`은 이미 분리되어 있습니다. 현재 단계에서는
SMS 발송이나 인증 코드를 구현하지 않습니다.
