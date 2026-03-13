#!/bin/bash
set -euo pipefail

# PUBLIC_INTERFACE
# Resident Directory DB seed runner.
# Contract:
# - Inputs: db_connection.txt containing a psql connection command.
# - Behavior: applies seed/seed_dev.sql to insert dev/demo data.
# - Errors: exits non-zero on SQL errors.
# - Side effects: inserts rows into app tables.
#
# Usage:
#   ./scripts/seed.sh
#   ./scripts/seed.sh --reset   (DANGEROUS: truncates app tables then reseeds)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CONN_CMD="$(cat db_connection.txt | tr -d '\n')"
MODE="${1:-}"

echo "[seed] Using connection: ${CONN_CMD}"

if [[ ! -f "seed/seed_dev.sql" ]]; then
  echo "[seed] ERROR: seed/seed_dev.sql not found"
  exit 1
fi

if [[ "${MODE}" == "--reset" ]]; then
  echo "[seed] RESET mode: truncating application tables (CASCADE)."
  ${CONN_CMD} -v ON_ERROR_STOP=1 -c "TRUNCATE TABLE
    audit_log,
    direct_message,
    direct_message_thread_participant,
    direct_message_thread,
    announcement,
    onboarding_event,
    invitation,
    resident_privacy_settings,
    resident_profile,
    app_user_role,
    app_role,
    app_user
    RESTART IDENTITY CASCADE;"
fi

echo "[seed] Applying seed/seed_dev.sql"
${CONN_CMD} -v ON_ERROR_STOP=1 -f "seed/seed_dev.sql"
echo "[seed] Done."
