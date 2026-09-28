# SnapStash

A minimal photo-upload service: upload an image with a title and a target URL,
store the file plus its metadata, and list everything back.

> **Learning project.** SnapStash is a hands-on playground to practise DevOps
> end to end (Docker, CI/CD, Terraform, Kubernetes, AWS). The Flask app is
> intentionally small - the value lives in the layers around it. See
> [ROADMAP.md](./ROADMAP.md) for the full journey.

## Architecture

SnapStash runs in two ways: locally with **Docker Compose**, and on a single-node
**Kubernetes (k3s)** cluster on a home server. Both run the same four components:

| Component | Image | Role | Docker Compose | Kubernetes (k3s) |
|---|---|---|---|---|
| `nginx` | `nginx:1.30-alpine` | reverse proxy: serves the web page, proxies everything else to the app | port `80` on the host | NodePort `30000` on the node |
| `app` | built from [`Dockerfile`](./Dockerfile) | Flask API served by Gunicorn | internal only | internal only (Service `app`) |
| `db` | `postgres:15-alpine` | stores item metadata | internal only | internal only (Service `db`) |
| object storage | S3-compatible | stores the uploaded files | **MinIO** (`9000` API, `9001` console) | **Garage** `dxflrs/garage:v2.3.0` (internal only) |

Request flow:

```
client → nginx:80 ─┬─ GET /  → static index.html (served by nginx)
                   └─ everything else → app:8000 (Gunicorn) ─┬→ db:5432         (metadata)
                                                             └→ object storage  (files, via boto3)
```

NGINX is the only public door. It serves `/` from disk and forwards every other
request - including `/uploads/*` - to the app, which streams the file back from
object storage. Components reach each other by **service name** (`db`, `app`,
`garage`), never `localhost`: Compose's network and Kubernetes' internal DNS work
the same way here.

The app talks to object storage through the S3 API (`boto3`), configured only by
`S3_*` environment variables. Switching from MinIO to Garage changes the
configuration, not the code.

## Tech stack

- **Language:** Python 3.10 (Flask, served by Gunicorn)
- **Reverse proxy:** NGINX
- **Database:** PostgreSQL 15
- **Object storage:** S3-compatible - MinIO (Compose), Garage (Kubernetes)
- **Containerisation:** Docker + Docker Compose
- **Orchestration:** Kubernetes (k3s)

## Run with Docker Compose

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose

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
`items` table, named volumes are created for Postgres and MinIO data, and the app
creates the `S3_BUCKET` bucket if it does not exist yet.

### 3. Try it

- Web UI: <http://localhost> (served through NGINX on port 80)
- MinIO console: <http://localhost:9001> (log in with your `MINIO_ROOT_*` creds)
- Health check:

  ```bash
  curl localhost/health          # {"status": "ok"}
  curl localhost/items           # {"items": []}
  ```

Stop the stack with `docker compose down` (add `-v` to also delete the volumes
and start from a clean database next time).

## Deploy on Kubernetes (k3s)

All manifests live in [`k8s/`](./k8s). Each stateful component (`db`, `garage`)
has a bootstrap script that creates its ConfigMaps and Secrets, applies its
manifest and waits for the rollout. Scripts resolve paths from their own location,
so they can be run from any directory.

### Prerequisites

- A k3s cluster and `kubectl` pointing to it
- Docker on the node (to build the app image) and `jq` (used by the Garage init script)

### 1. Import the app image into k3s

k3s uses containerd, not Docker: an image built with Docker is invisible to the
cluster until it is imported. On the k3s node, from the repository root:

```bash
docker build -t snapstash-app:0.1.0 .
docker save snapstash-app:0.1.0 | sudo k3s ctr images import -
sudo k3s crictl images | grep snapstash      # the cluster now sees the image
```

Use an explicit version tag, never `latest`: with `latest`, Kubernetes defaults to
`imagePullPolicy: Always` and tries to pull the image from Docker Hub. Bump the tag
(and `image:` in [`k8s/app.yaml`](./k8s/app.yaml)) on every code change.

### 2. Create the secret files

Real secret files are git-ignored. Create them from the templates and fill in
your own values:

```bash
cp k8s/db-secrets.yaml.example k8s/db-secrets.yaml
cp k8s/garage-secrets.yaml.example k8s/garage-secrets.yaml
```

The password is part of `DATABASE_URL`: if it contains `@`, `:` or `/`, URL-encode
those characters (e.g. `@` → `%40`).

### 3. Deploy, in this order

The order matters: the app needs the Secrets created by the Garage and db steps,
and NGINX needs the `app` Service to exist when it starts.

```bash
bash garage/bootstrap-garage.sh    # Garage + layout, access key, bucket, snapstash-s3 Secret
bash db/bootstrap-db.sh            # Postgres + db-init ConfigMap (schema) + db-secret
kubectl apply -f k8s/app-configmap.yaml -f k8s/app.yaml
kubectl rollout status deployment/snapstash-app
bash deploy/bootstrap-nginx.sh     # nginx-config ConfigMap (nginx.conf + index.html) + NGINX
```

### 4. Try it

- Web UI: `http://<node-ip>:30000`
- Test the app without NGINX:

  ```bash
  kubectl port-forward svc/app 8080:8000     # keep it running in another terminal
  curl localhost:8080/health                 # {"status": "ok"}
  curl localhost:8080/items                  # {"items": []}
  ```

### Operating notes

- **Changing a ConfigMap or a Secret does not update running pods.** Environment
  variables are read once at container start, and files mounted with `subPath`
  are never refreshed. Restart the workload after the change:
  `kubectl rollout restart deployment/<name>` (`bootstrap-nginx.sh` does it on
  every run).
- **`db/init.sql` only runs on an empty volume** (first start of Postgres). To
  replay it, delete and recreate the `db` objects, **which destroys the data**:
  `kubectl delete -f k8s/db.yaml` then `bash db/bootstrap-db.sh`.
- `POSTGRES_USER` / `POSTGRES_PASSWORD` are also only applied on an empty volume:
  changing them in `db-secret` later does not change the database credentials.

## Configuration

All configuration comes from environment variables. With Compose they come from
`.env` (see `.env.example`); on Kubernetes, non-sensitive values come from the
`app-config` ConfigMap and secrets from the `db-secret` and `snapstash-s3` Secrets.

| Variable | Used by | Description | Kubernetes source |
|---|---|---|---|
| `DATABASE_URL` | app | PostgreSQL connection string | Secret `db-secret` |
| `MAX_UPLOAD_SIZE` | app | max upload size in bytes (rejected with `413` above it) | ConfigMap `app-config` |
| `S3_ENDPOINT` | app | object storage URL (e.g. `http://garage:3900`) | ConfigMap `app-config` |
| `S3_BUCKET` | app | bucket holding the uploaded files | ConfigMap `app-config` |
| `S3_REGION` | app | object storage region (`garage` for Garage) | ConfigMap `app-config` |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | app | object storage credentials | Secret `snapstash-s3` (created by the Garage init script) |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | db | database bootstrap credentials | `POSTGRES_DB` inline, others from Secret `db-secret` |
| `POSTGRES_SERVICE` / `POSTGRES_PORT` | Compose only | used to compose `DATABASE_URL` in `.env` | - |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | minio (Compose only) | MinIO root credentials | - |

## API

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | liveness check (touches neither the database nor object storage) |
| `GET` | `/` | web UI |
| `POST` | `/items` | upload an item - multipart form: `image` (file), `title`, `target_url` |
| `GET` | `/items` | list items (newest first) |
| `GET` | `/uploads/<filename>` | stream a stored file back from object storage |

Behind NGINX, `/` is served directly by NGINX; the app's own `/` route remains as
a standalone fallback (the app still works without a proxy in front).

## Project structure

```
.
├── app.py                        # Flask application
├── storage.py                    # S3 client (boto3), configured by S3_* env vars
├── db/
│   ├── init.sql                  # schema, run on first DB init
│   └── bootstrap-db.sh           # k3s: db-init ConfigMap, db-secret, Postgres
├── deploy/
│   ├── nginx.conf                # reverse-proxy config (Compose mount / k3s ConfigMap)
│   └── bootstrap-nginx.sh        # k3s: nginx-config ConfigMap, NGINX, restart
├── garage/
│   ├── garage.toml               # Garage config
│   ├── bootstrap-garage.sh       # k3s: garage-config ConfigMap, garage-secret, Garage
│   ├── init-garage-k8s.sh        # k3s: layout, access key, bucket, snapstash-s3 Secret
│   └── init-garage-docker.sh     # same init for a Garage container run with Docker
├── k8s/
│   ├── app.yaml                  # app Deployment + Service `app`
│   ├── app-configmap.yaml        # app non-sensitive config
│   ├── db.yaml                   # Postgres Deployment + Service + PVC
│   ├── garage.yaml               # Garage Deployment + Service + PVCs
│   ├── nginx.yaml                # NGINX Deployment + NodePort Service
│   └── *-secrets.yaml.example    # Secret templates (real files are git-ignored)
├── static/
│   └── index.html                # minimal web UI
├── Dockerfile                    # builds the app image
├── docker-compose.yml            # nginx + app + postgres + minio
├── requirements.txt
└── ROADMAP.md                    # the DevOps learning path
```

## Roadmap

The full plan - 8 phases from local to orchestrated cloud - lives in
[ROADMAP.md](./ROADMAP.md).
