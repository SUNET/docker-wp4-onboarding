# Docker WP4 Onboarding

Builds a Docker image for the **WP4Trust trust-list onboarding** Django app.

Mirrors the `docker-ms-registry` deployment pattern: this repo holds the
deployment infra (Dockerfile, uWSGI config, entrypoint, CI), and clones the
[**public app source repo**](https://github.com/AniaAlex/wp4-onboarding) from
GitHub at build time.

## Quick start

```sh
# Build (no auth needed — the app repo is public)
make build

# Build a specific commit/tag
make build-pinned WP4_ONBOARDING_VERSION=v0.1.0

# Run (with a real DATABASE_URL + SECRET_KEY)
docker run -d --name wp4-onboarding -p 8000:8000 \
  -e DJANGO_SECRET_KEY=... \
  -e DJANGO_DEBUG=false \
  -e DJANGO_ALLOWED_HOSTS=lists.wp4trust.eu \
  -e DATABASE_URL=postgres://wp4_app:...@db.internal:5432/wp4_lote \
  docker-wp4-onboarding:latest
```

## Build arguments

| Arg | Default | Notes |
|---|---|---|
| `WP4_ONBOARDING_REPO` | `https://github.com/AniaAlex/wp4-onboarding.git` | Public app repo |
| `WP4_ONBOARDING_VERSION` | `main` | Branch / tag / SHA to check out |

## What's in the image

- `python:3.13-slim-bookworm` (multi-stage; final stage has no build deps)
- The Django app at `/app/`
- Python virtualenv at `/opt/venv/`
- `uwsgi.ini` at `/etc/uwsgi/app.ini`
- Non-root user `wp4app` (uid/gid 1000)
- `tini` as PID 1 for clean signal handling
- `HEALTHCHECK` against `GET /healthz/` (add this view in the app — see below)

## Required env vars at runtime

| Var | What | Example |
|---|---|---|
| `DJANGO_SECRET_KEY` | Cryptographic salt | random 50-byte base64 |
| `DJANGO_DEBUG` | `false` in production | `false` |
| `DJANGO_ALLOWED_HOSTS` | Comma-sep host list | `lists.wp4trust.eu` |
| `DATABASE_URL` | DB connection string | `postgres://user:pass@host:5432/db?sslmode=require` |
| `RUN_MIGRATIONS` | Apply migrations on start | `true` (default) |
| `COLLECT_STATIC` | Run collectstatic on start | `true` (default) |
| `DB_WAIT_TIMEOUT` | Seconds to wait for DB | `60` (default) |

## Ports

- **3030** — uWSGI native socket (use this if nginx is in front)
- **8000** — plain HTTP (used by the HEALTHCHECK; bind for direct access in dev)

## App-side change required for the healthcheck

The `HEALTHCHECK` directive hits `/healthz/`. Add a one-line view in
`lote_registry/trustlists/urls.py`:

```python
from django.http import HttpResponse
urlpatterns = [
    ...
    path("healthz/", lambda r: HttpResponse("ok"), name="healthz"),
]
```

## CI

`.jenkins.yaml` triggers a daily build of `main`, mirroring `docker-ms-registry`.

## What this image does NOT include

- A database — point `DATABASE_URL` at a Postgres / SQLite file
- A reverse proxy — front with nginx (TLS termination, rate limiting, caching)
- The Go signer service — runs separately, polls the public `/lists/*` endpoints

## Repository contents

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build; clones app code at build time |
| `requirements.txt` | Python deps installed into `/opt/venv` |
| `uwsgi.ini` | uWSGI config copied into image |
| `start.sh` | Entrypoint — wait for DB, migrate, collectstatic, exec uWSGI |
| `Makefile` | `build` / `build-pinned` / `clean` targets |
| `.jenkins.yaml` | Daily CI build of `main` |
| `.dockerignore` | Speeds up build context, excludes secrets |
