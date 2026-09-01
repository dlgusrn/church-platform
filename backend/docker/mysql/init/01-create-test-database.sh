#!/bin/bash
set -euo pipefail

test_database="${MYSQL_TEST_DATABASE:-church_app_test}"
application_user="${MYSQL_USER:-church_app}"

if [[ ! "$test_database" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "MYSQL_TEST_DATABASE must contain only letters, digits, and underscores" >&2
  exit 1
fi

if [[ ! "$application_user" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "MYSQL_USER must contain only letters, digits, and underscores" >&2
  exit 1
fi

mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${test_database}\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
GRANT ALL PRIVILEGES ON \`${test_database}\`.* TO '${application_user}'@'%';
FLUSH PRIVILEGES;
SQL
