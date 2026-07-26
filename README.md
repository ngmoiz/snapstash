# SnapStash

A minimal photo-upload service: upload an image with a title and a target URL,
store the file plus its metadata, and list everything back.

> **Learning project.** SnapStash is a hands-on playground to practise DevOps
> end to end (Docker, CI/CD, Terraform, Kubernetes, AWS). The Flask app is
> intentionally small - the value lives in the layers around it. See
> [ROADMAP.md](./ROADMAP.md) for the full journey.

## Architecture

The whole stack runs locally with Docker Compose:

| Service | Image | Role | Exposed port |
|---|---|---|---|
| `app` | built from [`Dockerfile`](./Dockerfile) | Flask API served by Gunicorn | `8000` |
| `db` | `postgres:15-alpine` | stores item metadata | internal only |
| `minio` | `minio/minio` | S3-compatible object storage | `9000` (API), `9001` (console) |

Services talk to each other by **service name** over Compose's private network
(e.g. the app reaches Postgres at `db:5432`, not `localhost`).

> **Current status:** uploaded files are written to the app container's local
> disk. MinIO already runs but is **not wired to the app yet** - moving uploads
> to object storage (via `boto3`) is planned for Phase 3 (brick B3.5).

## Tech stack

- **Language:** Python 3.10 (Flask, served by Gunicorn)
- **Database:** PostgreSQL 15
- **Object storage:** MinIO (S3-compatible)
- **Containerisation:** Docker + Docker Compose

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose

## Getting started

### 1. Configure the environment

Copy the example file and fill in your own values:

```bash
cp .env.example .env
```

`.env` is git-ignored and holds every secret and setting (12-Factor, config in
the environment). Note the MinIO root password must be **at least 8 characters**.

### 2. Launch the stack

```bash
docker compose up --build
```

On the first run, Postgres executes [`db/init.sql`](./db/init.sql) to create the
`items` table, and named volumes are created for Postgres and MinIO data.

### 3. Try it

- Web UI: <http://localhost:8000>
- MinIO console: <http://localhost:9001> (log in with your `MINIO_ROOT_*` creds)
- Health check:

  ```bash
  curl localhost:8000/health          # {"status": "ok"}
  curl localhost:8000/items           # {"items": []}
  ```

Stop the stack with `docker compose down` (add `-v` to also delete the volumes
and start from a clean database next time).

## Configuration

All configuration comes from environment variables (see `.env.example`):

| Variable | Used by | Description |
|---|---|---|
| `DATABASE_URL` | app | PostgreSQL connection string |
| `UPLOAD_DIR` | app | directory where uploaded files are written |
| `MAX_UPLOAD_SIZE` | app | max upload size in bytes (rejected with `413` above it) |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | db | database bootstrap credentials |
| `POSTGRES_SERVICE` / `POSTGRES_PORT` | app | used to compose `DATABASE_URL` |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | minio | MinIO root credentials |

## API

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | liveness check |
| `GET` | `/` | web UI |
| `POST` | `/items` | upload an item - multipart form: `image` (file), `title`, `target_url` |
| `GET` | `/items` | list items (newest first) |
| `GET` | `/uploads/<filename>` | serve a stored file |

## Project structure

```
.
├── app.py               # Flask application
├── db/
│   └── init.sql         # schema, run on first DB init
├── deploy/
│   └── nginx.conf       # Phase 1 reverse-proxy sample (host setup, not in Compose)
├── static/
│   └── index.html       # minimal web UI
├── Dockerfile           # builds the app image
├── docker-compose.yml   # app + postgres + minio
├── requirements.txt
└── ROADMAP.md           # the DevOps learning path
```

## Roadmap

The full plan - 8 phases from local to orchestrated cloud - lives in
[ROADMAP.md](./ROADMAP.md).
