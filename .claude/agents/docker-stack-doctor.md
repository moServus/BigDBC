# Agent: docker-stack-doctor

Diagnoses and fixes problems in the 7-container Docker Compose stack. Covers slow-starting containers, health-check failures, platform/Rosetta issues, port conflicts, init-script errors, and volume state problems. Called reactively when a container won't start, a health check never passes, or connector integration tests fail due to DB unavailability.

## Skills to Read First

Always load these before acting:
- `.claude/skills/docker-compose/SKILL.md` — stack layout, platform pins, health-check config, init scripts
- `.claude/skills/powershell-scripts/SKILL.md` — `setup.ps1` image pull and startup sequence

Load on demand:
- `.claude/skills/ef-core-provider/SKILL.md` — when EF migration failures are the downstream symptom
- [`infra-architect`](.claude/agents/infra-architect.md) — when the fix requires a structural change to `docker-compose.yml`

## When to Invoke This Agent

- A container is stuck in `starting`, `unhealthy`, or `exited` state
- `docker compose up` completes but a DB container never becomes `healthy`
- Connector integration tests fail immediately with a connection-refused error
- A `platform: linux/amd64` container fails silently on arm64
- An init script (`init.sql`, `init.js`) did not execute or threw an error
- Volume data is stale / a container needs a clean-state restart
- Port conflict: a DB port is already bound on the host

## Diagnostic Runbook

Run these in order to locate the problem before changing any config:

### 1. Check overall stack health

```bash
docker compose -f docker/docker-compose.yml ps
```

Look for `Status` — `healthy`, `unhealthy`, `starting`, or `exited (1)`.

### 2. Tail logs for the failing container

```bash
docker compose -f docker/docker-compose.yml logs -f <service>
# e.g.:
docker compose -f docker/docker-compose.yml logs -f oracle
docker compose -f docker/docker-compose.yml logs -f exasol
docker compose -f docker/docker-compose.yml logs -f sqlserver
```

### 3. Inspect health-check details

```bash
docker inspect --format='{{json .State.Health}}' <container-name> | python3 -m json.tool
```

This shows the last 5 health-check attempts and their output — often more informative than the logs.

### 4. Check host port conflicts

```bash
# macOS
lsof -nP -iTCP -sTCP:LISTEN | grep -E '5432|1433|1521|27017|8563|8080'
```

If a port is already bound, either stop the conflicting process or change the host-side port mapping in `docker-compose.override.yml`.

### 5. Verify Rosetta availability (arm64 only)

```bash
# Check that Rosetta is installed
/usr/bin/pgrep -q oahd && echo "Rosetta running" || echo "Rosetta NOT running"

# Re-install Rosetta if missing
softwareupdate --install-rosetta --agree-to-license
```

Required for `sqlserver` and `exasol` containers (`platform: linux/amd64`).

## Per-Service Failure Patterns

### Oracle (`gvenzl/oracle-free`)

| Symptom | Cause | Fix |
|---|---|---|
| Stuck in `starting` for >2 min | Normal — Oracle takes 90–120 s | Wait; increase `start_period` to `150s` if consistently timing out |
| `ORA-12514` connection refused | Listener not ready | Wait for `DATABASE IS OPEN` in logs before connecting |
| `healthcheck.sh` not found | Wrong image tag | Use `gvenzl/oracle-free:latest` (not Oracle's official image) |
| Init SQL not applied | Script error or wrong mount path | Check `/docker-entrypoint-initdb.d/` mount; inspect logs for SQL errors |

### SQL Server (`mcr.microsoft.com/mssql/server`)

| Symptom | Cause | Fix |
|---|---|---|
| `Exited (1)` immediately | SA password too weak | Password must be ≥8 chars with uppercase, lowercase, digit, symbol |
| `platform` warning on arm64 | Expected — runs under Rosetta | Not an error; verify Rosetta is installed |
| Health check fails | `sqlcmd` path wrong in check | Use `/opt/mssql-tools18/bin/sqlcmd` (newer images changed the path) |
| Port 1433 conflict | Another SQL Server or LocalDB | Stop conflicting process or remap host port in override file |

### Exasol (`exasol/docker-db`)

| Symptom | Cause | Fix |
|---|---|---|
| Stuck in `starting` for >2 min | Normal — takes 60–120 s | Increase `start_period` to `150s` |
| Container exits with OOM | Exasol needs ≥4 GB RAM | Add `mem_limit: 6g` to the service block |
| JDBC port 2580 not reachable | Port not exposed | Add `- "2580:2580"` to `ports` in `docker-compose.yml` |
| `exaplus` not found in health check | Different image version | Use HTTP probe on management port instead |

### PostgreSQL (`postgres:16`)

| Symptom | Cause | Fix |
|---|---|---|
| `FATAL: role does not exist` | Init script not run | Check `/docker-entrypoint-initdb.d/` mount and `.sql` file permissions |
| Data persists after `down` | Named volume not removed | `docker compose down -v` to remove volumes for a clean start |

### MongoDB (`mongo:7`)

| Symptom | Cause | Fix |
|---|---|---|
| Auth failure from connector | `MONGO_INITDB_ROOT_USERNAME` not set | Verify env vars in `.env` match `appsettings.json` |
| Init JS not applied | File not mounted or wrong extension | Mount must target `/docker-entrypoint-initdb.d/` and file must be `.js` or `.sh` |

## Clean-State Restart

When a container is in an inconsistent state (partial init, corrupted volume):

```bash
# Stop everything and remove volumes
docker compose -f docker/docker-compose.yml down -v

# Pull latest images (in case of image corruption)
docker compose -f docker/docker-compose.yml pull

# Bring stack back up
docker compose -f docker/docker-compose.yml up -d

# Watch until all services healthy
watch -n 5 'docker compose -f docker/docker-compose.yml ps'
```

> Warn the user before running `down -v` — it destroys all volume data including any test data loaded into the databases.

## Adjusting Health-Check Timing

If a service consistently times out before becoming healthy, increase `start_period` in `docker-compose.yml` rather than reducing `retries`:

```yaml
healthcheck:
  interval: 15s
  timeout: 10s
  retries: 10
  start_period: 150s   # increase this, not retries
```

Minimum `start_period` values — do not go below these:

| Service | Minimum `start_period` |
|---|---|
| Oracle | 90 s |
| Exasol | 90 s |
| SQL Server | 30 s |
| Postgres | 10 s |
| MongoDB | 10 s |

## App Container Dependency Failures

The `app` service declares `depends_on: condition: service_healthy` for all DB services. If the app fails to start, check which DB is not yet healthy — the app will not start until all dependencies pass:

```bash
docker compose -f docker/docker-compose.yml logs app
# Look for: "service '<name>' is not healthy"
```

Fix the failing DB service first; the app container will restart automatically once all dependencies are healthy.

## Enforcement

- Never reduce `start_period` below the minimums in the table above — slow startup is expected, not a bug.
- Run `down -v` only after warning the user — it is destructive and removes all volume data.
- Port conflicts must be resolved in `docker-compose.override.yml` (host-side remapping), not by editing the base `docker-compose.yml` port values.
- Do not disable health checks to make the stack "start faster" — the `app` container's `depends_on` relies on them.
- Rosetta must be installed for `sqlserver` and `exasol` — verify before assuming image or config is broken.
- Image pulls should go through `setup.ps1`, not manual `docker pull` — keeps the pull list in sync.
