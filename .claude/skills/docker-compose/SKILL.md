# Skill: docker-compose

Covers the 7-container stack in `docker/docker-compose.yml`.

## Container Inventory

| Service | Image | Platform | Notes |
|---|---|---|---|
| `postgres` | `postgres:16` | arm64 native | |
| `sqlserver` | `mcr.microsoft.com/mssql/server:2022-latest` | `linux/amd64` (Rosetta) | |
| `oracle` | `gvenzl/oracle-free:latest` | arm64 native | Community image, no account required |
| `mongo` | `mongo:7` | arm64 native | |
| `sqlite` | n/a — file-based | n/a | No container; `.db` file path set in config |
| `exasol` | `exasol/docker-db:latest` | `linux/amd64` (Rosetta) | Slow startup (60–120 s) |
| `app` | built from `docker/Dockerfile` | arm64 native | Depends on all DB services |

## Platform Pinning

Services without arm64 images must declare `platform: linux/amd64`:

```yaml
sqlserver:
  image: mcr.microsoft.com/mssql/server:2022-latest
  platform: linux/amd64
```

## Health Checks

All DB services need health checks. The `app` service uses `depends_on: condition: service_healthy` so it never starts before DBs are ready:

```yaml
depends_on:
  postgres:
    condition: service_healthy
  sqlserver:
    condition: service_healthy
  # …etc
```

Oracle and Exasol need generous `start_period` values (90–120 s).

## Init Scripts

Per-DB SQL/JS init scripts in `docker/init-scripts/<db>/` are volume-mounted into the containers' standard init-script locations (e.g., `/docker-entrypoint-initdb.d/` for Postgres/Mongo). They create the sample schema used by integration tests.

## Environment Variables

Secrets (passwords, connection strings) come from `docker/.env`. The repo ships a `docker/.env.example` with placeholder values — copy to `.env` and fill in before running `docker compose up`.

## Common Commands

```bash
# Start all DBs (detached)
docker compose -f docker/docker-compose.yml up -d

# Tail logs for a slow-starting service
docker compose -f docker/docker-compose.yml logs -f exasol

# Tear down and remove volumes (full reset)
docker compose -f docker/docker-compose.yml down -v
```
