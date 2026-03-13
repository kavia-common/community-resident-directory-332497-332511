#!/bin/bash
set -euo pipefail

# PUBLIC_INTERFACE
# One-command local dev DB bootstrap for the resident directory database container.
#
# Contract:
# - Inputs:
#   - startup.sh (optional) to start Postgres if not already running
#   - db_connection.txt for the psql connection command
# - Behavior:
#   - Optionally starts postgres (default: yes)
#   - Runs migrations (scripts/migrate.sh)
#   - Runs dev seed (scripts/seed.sh)
# - Outputs:
#   - Prints status to stdout
# - Errors:
#   - Exits non-zero if any step fails
#
# Usage:
#   ./scripts/dev_setup.sh
#   ./scripts/dev_setup.sh --no-start
#   ./scripts/dev_setup.sh --reset-seed   (truncates and reseeds)
#
# Debugging:
#   - Inspect applied migrations: SELECT * FROM schema_migrations ORDER BY applied_at;
#   - Re-run migrations: ./scripts/migrate.sh
#   - Reset seed: ./scripts/seed.sh --reset

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

NO_START="false"
RESET_SEED="false"

for arg in "$@"; do
  case "${arg}" in
    --no-start) NO_START="true" ;;
    --reset-seed) RESET_SEED="true" ;;
    *) ;;
  esac
done

echo "[dev_setup] Starting resident directory DB dev setup..."

if [[ "${NO_START}" != "true" ]]; then
  echo "[dev_setup] Ensuring PostgreSQL is running (startup.sh)..."
  # startup.sh is safe to re-run: it exits early if already running.
  ./startup.sh
else
  echo "[dev_setup] Skipping startup.sh (--no-start)"
fi

echo "[dev_setup] Running migrations..."
./scripts/migrate.sh

echo "[dev_setup] Seeding dev data..."
if [[ "${RESET_SEED}" == "true" ]]; then
  ./scripts/seed.sh --reset
else
  ./scripts/seed.sh
fi

echo "[dev_setup] Done."
