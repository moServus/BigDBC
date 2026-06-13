<!-- V1: Blazor Example + Docker Infrastructure -->
# Infrastructure

See [devWiki/infrastructure.md](../../devWiki/infrastructure.md) for the full Docker stack reference.

## Proto Stack (local dev)

Brings up only what's needed to run the app:

| Service | Image | Port |
|---|---|---|
| `metaMongoDB` | `mongo:7` | `40217` |
| `bigdbc` (app) | Built from `docker/Dockerfile` | `42080` |

```bash
docker compose -f docker/docker-compose.proto.yml up -d
# App: http://localhost:42080
```

## Full Stack

Seven containers — add all source DBs:

```bash
docker compose -f docker/docker-compose.yml up -d
```

SQL Server and Exasol run under Rosetta emulation on Apple Silicon — allow extra startup time.
