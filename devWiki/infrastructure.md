# Infrastructure

This document covers the Docker-based infrastructure for SQL SPA Explorer — the 7-container compose stack, image strategy, port layout, init scripts, and environment configuration.

## Table of Contents

- [Docker Stack Overview](#docker-stack-overview)
- [Profiles](#profiles)
- [Port Mapping](#port-mapping)
  - [BigDBC](#bigdbc-402xx)
  - [sourcedbs](#sourcedbs-4xxxx)
- [Compose Files](#compose-files)
- [Init Scripts](#init-scripts)
- [Environment Variables](#environment-variables)
- [Bring Up the Stack](#bring-up-the-stack)
- [Gotchas](#gotchas)

---

## Docker Stack Overview [↑](#table-of-contents)

The stack runs **7 containers** (6 databases + 1 app). SQLite is file-based and has no container — it mounts a named volume.

| Group | Service | Image | Platform | Host Port | Container Port |
|-------|---------|-------|----------|-----------|----------------|
| **BigDBC** | `appBlazor` | built from `docker/Dockerfile` | arm64-native | 42080 | 8080 |
|  | `metaMongoDB` | `mongo:7` | arm64-native | 40217 | 27017 |
|  | `dotaspnet` | `mcr.microsoft.com/dotnet/aspnet:9.0` | arm64-native | — | — |
|  | `dosdknet` | `mcr.microsoft.com/dotnet/sdk:9.0` | arm64-native | — | — |
| **sourceDBs** | `postgres` | `postgres:16` | arm64-native | 45432 | 5432 |
|  | `oracle` | `gvenzl/oracle-free:latest` | arm64-native | 41521 | 1521 |
|  | `sqlserver` | `mcr.microsoft.com/mssql/server:2022-latest` | linux/amd64 (Rosetta) | 41433 | 1433 |
|  | `exasol` | `exasol/docker-db:latest` | linux/amd64 (Rosetta) | 48563 | 8563 |
|  | `SQLite` | (file-based, no container) | — | — | — |

---

## Profiles [↑](#table-of-contents)

Services are activated by passing `--profile` to `docker compose`. Each profile targets a specific stage of development.

| File | Stage | `--profile` | Source DB |
|------|-------|-------------|-----------|
| `docker-compose.proto.yml` | Prototyping | — | none |
| `docker-compose.dev.yml` | Dev / unit test | `pg` | postgres |
| | | `oracle` | oracle |
| | | `mssql` | sqlserver |
| | | `exasol` | exasol |
| `docker-compose.int.yml` | Integration | — | all |

`proto` and `int` are standalone files. `dev` uses internal Docker Compose profiles to activate exactly one source DB — BigDBC services always start regardless of profile. The `app` service uses `required: false` on source DB dependencies so it waits only for the active DB.

---

## Port Mapping [↑](#table-of-contents)

Host ports are grouped by function and defined directly in each stage compose file.

### BigDBC (Ports: 402xx)

App metadata store, .NET application layer, and build images. Services owned by this project.

### sourcedbs (Ports: 4xxxx)

Queryable database engines exposed to the explorer UI and local tools (DBeaver, psql, mongosh, etc.).

---

## Compose Files [↑](#table-of-contents)

| File | Purpose |
|------|---------|
| `docker/docker-compose.proto.yml` | proto — BigDBC + SQLite only, standalone |
| `docker/docker-compose.dev.yml` | dev — BigDBC always + one source DB via `--profile` |
| `docker/docker-compose.int.yml` | int — BigDBC + all source DBs, standalone |
| `docker/Dockerfile` | Multi-stage .NET 9 build: SDK (build) → ASP.NET (runtime) |
| `docker/.env.example` | Credential template — copy to `docker/.env` before running |

---

## Init Scripts [↑](#table-of-contents)

All databases are seeded with a `categories` / `products` demo schema (3 categories, 4 products) on first startup.

| Path | Runs via | Notes |
|------|----------|-------|
| `docker/init-scripts/postgres/init.sql` | `docker-entrypoint-initdb.d` | Auto on first start |
| `docker/init-scripts/oracle/init.sql` | `container-entrypoint-initdb.d` | Auto on first start |
| `docker/init-scripts/mongo/init.js` | `docker-entrypoint-initdb.d` | Auto on first start |
| `docker/init-scripts/sqlserver/init.sql` | `entrypoint.sh` | Custom entrypoint polls readiness then runs sqlcmd |
| `docker/init-scripts/sqlserver/entrypoint.sh` | Compose `entrypoint:` | Starts sqlservr, polls, runs init.sql, waits |
| `docker/init-scripts/exasol/init.sql` | `setup.ps1` (manual) | No auto-init mechanism in exasol/docker-db |

---

## Environment Variables [↑](#table-of-contents)

Copy `.env.example` to `.env` and fill in values before first run:

```bash
cp docker/.env.example docker/.env
```

| Variable | Used by | Notes |
|----------|---------|-------|
| `POSTGRES_PASSWORD` | PostgreSQL | Any value |
| `SA_PASSWORD` | SQL Server | Min 8 chars, upper + lower + digit + symbol |
| `ORACLE_PASSWORD` | Oracle SYS/SYSTEM | Any value |
| `ORACLE_APP_PASSWORD` | Oracle app user `explorer` | Any value |
| `MONGO_USERNAME` | MongoDB root | Any value |
| `MONGO_PASSWORD` | MongoDB root | Any value |
| `EXASOL_SYS_PASSWORD` | Exasol sys user | Any value |
| `EXASOL_MEM_LIMIT` | Exasol container | Default: `2GiB` |

`docker/.env` is git-ignored — never commit real credentials.

---

## Bring Up the Stack [↑](#table-of-contents)

Services are activated via Docker Compose profiles. First-time setup:

```bash
cp docker/.env.example docker/.env
```

### Profiles

| Profile | Stage | Services |
|---------|-------|----------|
| `proto` | Prototyping | BigDBC + SQLite |
| `dev-pg` | Dev / unit test | BigDBC + postgres |
| `dev-oracle` | Dev / unit test | BigDBC + oracle |
| `dev-mssql` | Dev / unit test | BigDBC + sqlserver |
| `dev-exasol` | Dev / unit test | BigDBC + exasol |
| `int` | Integration test | BigDBC + all source DBs |

```bash
# proto
docker compose -f docker/docker-compose.proto.yml up -d

# dev — pick one source DB via --profile
docker compose -f docker/docker-compose.dev.yml --profile pg up -d
docker compose -f docker/docker-compose.dev.yml --profile oracle up -d
docker compose -f docker/docker-compose.dev.yml --profile mssql up -d
docker compose -f docker/docker-compose.dev.yml --profile exasol up -d

# int — all source DBs (allow 2+ min for oracle/exasol)
docker compose -f docker/docker-compose.int.yml up -d

# Check health
docker compose -f docker/docker-compose.<stage>.yml ps

# Tear down (keep volumes)
docker compose -f docker/docker-compose.<stage>.yml down

# Tear down + wipe all data
docker compose -f docker/docker-compose.<stage>.yml down -v
```

---

## Gotchas [↑](#table-of-contents)

- **SQL Server & Exasol** run under Rosetta — allow 2+ minutes before connector tests run against them.
- **SQL Server SA password** must meet complexity requirements (8+ chars, upper + lower + digit + symbol) or the container will exit silently.
- **Oracle** uses `gvenzl/oracle-free` (arm64-native, no account required), not Oracle's official image which requires a license agreement.
- **Exasol init** does not run automatically — execute `docker/init-scripts/exasol/init.sql` manually via `setup.ps1` after the container reaches healthy.
- **Exasol requires `privileged: true`** in the compose service definition — do not remove it.
- **`docker/.env` must exist** before running `docker compose up` or all `${VAR}` substitutions will be empty strings, causing silent auth failures.
