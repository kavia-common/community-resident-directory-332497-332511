#!/bin/bash
set -euo pipefail

# PUBLIC_INTERFACE
# Resident Directory DB migration runner.
# Contract:
# - Inputs: db_connection.txt containing a psql connection command (e.g., "psql postgresql://...").
# - Behavior: applies *.sql in migrations/ in lexical order, exactly once each, recording to schema_migrations.
# - Errors: exits non-zero on SQL errors; prints which migration failed.
# - Side effects: creates/updates schema objects and schema_migrations table.
# - Idempotency: safe to re-run; already applied migrations are skipped.
#
# Usage:
#   ./scripts/migrate.sh
#   ./scripts/migrate.sh --force-reapply 001_init.sql   (dev-only; re-applies by deleting record)
#
# Notes:
# - Requires PostgreSQL to be running (startup.sh).
# - Uses existing connection mechanism via db_connection.txt.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CONN_CMD="$(cat db_connection.txt | tr -d '\n')"

FORCE_REAPPLY="${2:-}"

echo "[migrate] Using connection: ${CONN_CMD}"

# Ensure migration tracking table exists (run as a single statement)
${CONN_CMD} -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());"

apply_migration() {
  local file_path="$1"
  local version
  version="$(basename "${file_path}")"

  if [[ -n "${FORCE_REAPPLY}" && "${FORCE_REAPPLY}" == "${version}" ]]; then
    echo "[migrate] FORCE reapply requested for ${version}: deleting schema_migrations row"
    ${CONN_CMD} -v ON_ERROR_STOP=1 -c "DELETE FROM schema_migrations WHERE version='${version}';"
  fi

  local applied
  applied="$(${CONN_CMD} -tA -v ON_ERROR_STOP=1 -c "SELECT 1 FROM schema_migrations WHERE version='${version}' LIMIT 1;" || true)"
  if [[ "${applied}" == "1" ]]; then
    echo "[migrate] Skipping already applied: ${version}"
    return 0
  fi

  echo "[migrate] Applying: ${version}"
  # Apply the migration file
  ${CONN_CMD} -v ON_ERROR_STOP=1 -f "${file_path}"

  # Record applied version
  ${CONN_CMD} -v ON_ERROR_STOP=1 -c "INSERT INTO schema_migrations(version) VALUES ('${version}');"
  echo "[migrate] Applied: ${version}"
}

if [[ ! -d "migrations" ]]; then
  echo "[migrate] ERROR: migrations/ directory not found"
  exit 1
fi

shopt -s nullglob
MIGRATIONS=(migrations/*.sql)
shopt -u nullglob

if [[ "${#MIGRATIONS[@]}" -eq 0 ]]; then
  echo "[migrate] No migrations found."
  exit 0
fi

echo "[migrate] Found ${#MIGRATIONS[@]} migration(s)."
for f in "${MIGRATIONS[@]}"; do
  apply_migration "${f}"
done

echo "[migrate] Done."
