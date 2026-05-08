# syntax=docker/dockerfile:1.7
#
# Multi-stage build for the WP4Trust onboarding (Django) app.
#
# Pattern mirrors `docker-ms-registry`: deployment infra lives in this repo;
# app code lives in a separate (public) repo and is cloned at build time.
#
#     docker build \
#       --build-arg WP4_ONBOARDING_VERSION=main \
#       -t docker-wp4-onboarding:latest .

# ─────────────── Stage 1: builder ───────────────
FROM python:3.13-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps into a venv we'll copy into the runtime stage.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip wheel \
    && pip install -r /tmp/requirements.txt \
    && pip install --no-binary pyuwsgi pyuwsgi

# Public app repo — no auth needed.
ARG WP4_ONBOARDING_REPO=https://github.com/AniaAlex/wp4-onboarding.git
ARG WP4_ONBOARDING_VERSION=main

RUN git clone "${WP4_ONBOARDING_REPO}" /tmp/wp4-onboarding \
    && git -C /tmp/wp4-onboarding checkout "${WP4_ONBOARDING_VERSION}"


# ─────────────── Stage 2: runtime ───────────────
FROM python:3.13-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    DJANGO_SETTINGS_MODULE=lote_registry.settings

# Runtime-only system deps: postgres client (psycopg) + tini for clean signals.
# libexpat1 is required by pyuwsgi at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libexpat1 \
    tini \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Non-root app user.
RUN groupadd --system --gid 1000 wp4app \
    && useradd  --system --uid 1000 --gid wp4app --home /app --shell /usr/sbin/nologin wp4app

# Pre-create writable dirs the app needs at runtime.
RUN mkdir -p /var/www/static /var/www/media /mnt/logs /app/data /run \
    && chown -R wp4app:wp4app /var/www/static /var/www/media /mnt/logs /app /run

# Bring over the venv from the builder.
COPY --from=builder /opt/venv /opt/venv

# Bring over the app source (lote_registry package + manage.py at repo root).
COPY --from=builder /tmp/wp4-onboarding/ /app/
WORKDIR /app

# uWSGI config and entrypoint script — controlled from this repo.
COPY uwsgi.ini /etc/uwsgi/app.ini
COPY start.sh  /start.sh
RUN chmod +x /start.sh

USER wp4app

EXPOSE 3030 8000

# Liveness probe — `/healthz/` returns 200 when the process is up.
# (Add a tiny `path("healthz/", lambda r: HttpResponse("ok"))` view in the app.)
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8000/healthz/ || exit 1

# OCI labels for image traceability.
LABEL org.opencontainers.image.title="wp4-onboarding" \
    org.opencontainers.image.description="WP4Trust trust-list onboarding" \
    org.opencontainers.image.source="https://github.com/CHANGE_ME/docker-wp4-onboarding" \
    org.opencontainers.image.licenses="EUPL-1.2"

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/start.sh"]
