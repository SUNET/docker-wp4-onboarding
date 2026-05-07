#!/usr/bin/env bash
# Entry point for the wp4-onboarding container.
# Mirrors docker-ms-registry/start.sh, with bounded DB-wait timeout.

set -euo pipefail

echo "Starting WP4Trust Onboarding..."

UWSGI_INI=${UWSGI_INI:-/etc/uwsgi/app.ini}
RUN_MIGRATIONS=${RUN_MIGRATIONS:-true}
COLLECT_STATIC=${COLLECT_STATIC:-true}
DB_WAIT_TIMEOUT=${DB_WAIT_TIMEOUT:-60}     # seconds; exit non-zero past this

echo "Configuration:"
echo "  uWSGI Config:    ${UWSGI_INI}"
echo "  Run Migrations:  ${RUN_MIGRATIONS}"
echo "  Collect Static:  ${COLLECT_STATIC}"
echo "  DB Wait Timeout: ${DB_WAIT_TIMEOUT}s"
echo ""

# Wait for the configured database (works for sqlite, postgres, etc).
# Bounded — fail fast on broken deploys instead of hanging forever.
echo "Waiting for database..."
DEADLINE=$(( $(date +%s) + DB_WAIT_TIMEOUT ))
until python manage.py check --database default 2>/dev/null; do
    if (( $(date +%s) >= DEADLINE )); then
        echo "ERROR: database not ready after ${DB_WAIT_TIMEOUT}s — aborting." >&2
        exit 1
    fi
    echo "  not ready yet, sleeping 2s..."
    sleep 2
done
echo "Database is ready."

if [ "${RUN_MIGRATIONS}" = "true" ]; then
    echo "Running migrations..."
    python manage.py migrate --noinput
fi

if [ "${COLLECT_STATIC}" = "true" ]; then
    echo "Collecting static files..."
    python manage.py collectstatic --noinput
fi

echo "---"
echo "Starting uWSGI..."
exec uwsgi --ini "${UWSGI_INI}"
