#!/usr/bin/env bash
# Provision a new tenant database + registry row + admin user.
#
# Usage:
#   ./db/scripts/add-tenant.sh <slug> <display_name> <theme_color> <admin_email> [password]
#
# Example:
#   ./db/scripts/add-tenant.sh initech "Initech" "#1D4ED8" admin@initech.demo password123
#
# Env overrides:
#   MYSQL_HOST MYSQL_PORT MYSQL_ROOT_USER MYSQL_ROOT_PASSWORD MYSQL_APP_USER

set -euo pipefail

SLUG="${1:-}"
NAME="${2:-}"
THEME="${3:-}"
EMAIL="${4:-}"
PASSWORD="${5:-password123}"

if [[ -z "$SLUG" || -z "$NAME" || -z "$THEME" || -z "$EMAIL" ]]; then
  echo "Usage: $0 <slug> <display_name> <theme_color> <admin_email> [password]" >&2
  exit 1
fi

if [[ ! "$SLUG" =~ ^[a-z0-9-]+$ ]]; then
  echo "slug must be lowercase alphanumeric/hyphen" >&2
  exit 1
fi

DB_NAME="tenant_${SLUG//-/_}"
HOST="${MYSQL_HOST:-127.0.0.1}"
PORT="${MYSQL_PORT:-3306}"
ROOT_USER="${MYSQL_ROOT_USER:-root}"
ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"
APP_USER="${MYSQL_APP_USER:-apipulse}"

HASH=""
if command -v node >/dev/null 2>&1; then
  HASH="$(node -e "const b=require('bcryptjs'); console.log(b.hashSync(process.argv[1],10))" "$PASSWORD" 2>/dev/null || true)"
fi
if [[ -z "$HASH" ]] && command -v python3 >/dev/null 2>&1; then
  HASH="$(PASSWORD="$PASSWORD" python3 - <<'PY'
import os, bcrypt
print(bcrypt.hashpw(os.environ["PASSWORD"].encode(), bcrypt.gensalt(rounds=10)).decode())
PY
)" || true
fi
if [[ -z "$HASH" ]]; then
  if [[ "$PASSWORD" != "password123" ]]; then
    echo "Need node+bcryptjs or python3+bcrypt to hash custom passwords." >&2
    exit 1
  fi
  HASH='$2b$10$OVCxDzhQ4l49WusLNEpvpOMZmueznQb2AwvE5VyGVaxg6HtAOo2kq'
fi

# Escape single quotes for SQL literals
sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

NAME_ESC="$(sql_escape "$NAME")"
EMAIL_ESC="$(sql_escape "$EMAIL")"
HASH_ESC="$(sql_escape "$HASH")"

mysql -h"$HOST" -P"$PORT" -u"$ROOT_USER" -p"$ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${APP_USER}'@'%';
FLUSH PRIVILEGES;

USE api_pulse_registry;
INSERT INTO tenants (slug, name, db_name, theme_color)
VALUES ('${SLUG}', '${NAME_ESC}', '${DB_NAME}', '${THEME}')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  db_name = VALUES(db_name),
  theme_color = VALUES(theme_color);

USE \`${DB_NAME}\`;
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'admin',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS api_metrics (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  endpoint VARCHAR(128) NOT NULL,
  latency_ms INT NOT NULL,
  status_code INT NOT NULL,
  recorded_at DATETIME NOT NULL,
  INDEX idx_metrics_recorded (recorded_at),
  INDEX idx_metrics_endpoint (endpoint)
);
CREATE TABLE IF NOT EXISTS uptime_snapshots (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  snapshot_date DATE NOT NULL UNIQUE,
  uptime_pct DECIMAL(5,2) NOT NULL
);
INSERT INTO users (email, password_hash, role)
VALUES ('${EMAIL_ESC}', '${HASH_ESC}', 'admin')
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);
SQL

echo "Tenant '${SLUG}' ready (db=${DB_NAME}, admin=${EMAIL})."
