# Agent: infra-architect

Owns everything outside the .NET source tree: the Docker Compose stack, GitHub Actions pipelines, setup scripts, and the DocFX documentation site. Makes calls on container configuration, platform pinning, CI structure, and docs publishing.

## Skills to Read First

Always load these before acting:
- `.claude/skills/docker-compose/SKILL.md` — 7-container stack, platform pinning, health checks, init scripts
- `.claude/skills/github-workflows/SKILL.md` — CI/CD pipeline structure and CODEOWNERS rules
- `.claude/skills/powershell-scripts/SKILL.md` — setup.ps1 conventions and image list maintenance

Load on demand:
- `.claude/skills/github-pages-docfx/SKILL.md` — when changing docs structure or the pages pipeline
- `.claude/skills/ef-core-provider/SKILL.md` — when a new EF connector needs a migration step in setup.ps1

## When to Invoke This Agent

- Adding or modifying a Docker container in the stack
- Changing platform pins (`platform: linux/amd64`) or health check timings
- Adding or editing init scripts under `docker/init-scripts/`
- Editing any workflow in `.github/workflows/`
- Changing CODEOWNERS or branch protection rules
- Editing `setup.ps1` (new image pulls, new EF migration targets, prereq checks)
- Changing DocFX config (`docs/docfx.json`, `docs/toc.yml`) or architecture articles
- Diagnosing slow-starting containers (Oracle, SQL Server, Exasol)

## Docker Compose — Container Inventory

| Service | Image | Platform | Startup note |
|---|---|---|---|
| `postgres` | `postgres:16` | arm64 native | Fast |
| `sqlserver` | `mcr.microsoft.com/mssql/server:2022-latest` | `linux/amd64` (Rosetta) | ~30 s |
| `oracle` | `gvenzl/oracle-free:latest` | arm64 native | 90–120 s — needs generous `start_period` |
| `mongo` | `mongo:7` | arm64 native | Fast |
| `exasol` | `exasol/docker-db:latest` | `linux/amd64` (Rosetta) | 60–120 s — needs generous `start_period` |
| `app` | built from `docker/Dockerfile` | arm64 native | `depends_on: condition: service_healthy` for all DBs |

SQLite has no container — it is file-based; the path is set via `appsettings.json`.

## Adding a New Container

1. Add service block to `docker/docker-compose.yml`.
2. Set `platform: linux/amd64` if the image has no arm64 build.
3. Add a `healthcheck` block. For slow starters, set `start_period: 120s`.
4. Add service to the `app` container's `depends_on` list with `condition: service_healthy`.
5. Add an init script at `docker/init-scripts/<db>/` and volume-mount it into the container's init location.
6. Add the image to `docker/.env.example` if credentials are required (passwords, license vars).
7. Update `setup.ps1` image list (see powershell-scripts skill).

## Platform Pinning Rules

Services without an arm64 image declare:
```yaml
platform: linux/amd64
```
This forces Rosetta emulation on the Mac Mini M4. Current amd64-only services: `sqlserver`, `exasol`.

Never remove a `platform: linux/amd64` pin without confirming an arm64 image exists — Rosetta fallback is silent but the container will fail to start on non-x86 Linux CI runners.

## Health Check Pattern

```yaml
healthcheck:
  test: ["CMD", "<db-specific-check>"]
  interval: 10s
  timeout: 5s
  retries: 10
  start_period: 30s   # use 120s for Oracle and Exasol
```

Per-database test commands:
- **Oracle**: `test: ["CMD", "healthcheck.sh"]` (bundled in the `gvenzl/oracle-free` image)
- **SQL Server**: `test: ["CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "$$SA_PASSWORD", "-Q", "SELECT 1"]`
- **Exasol**: use `exaplus` or an HTTP probe against the management port
- **Postgres**: `test: ["CMD-SHELL", "pg_isready -U postgres"]`
- **MongoDB**: `test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]`

## GitHub Actions — Workflow Ownership

| File | Trigger | What to protect |
|---|---|---|
| `ci.yml` | Push / PR to `main` | Keep integration tests excluded with `--filter "Category!=Integration"` |
| `docker-build.yml` | Push to `main` + tags | Must build both `linux/amd64` and `linux/arm64`; uses QEMU + Buildx |
| `docfx-pages.yml` | Push to `main` | Publishes to `gh-pages` branch; never redirect away from it |
| `codeql.yml` | Push / PR + weekly | Do not disable the weekly schedule |

## Multi-Arch Docker Build

The `docker-build.yml` workflow builds two arch targets in one job using QEMU emulation:

```yaml
- uses: docker/setup-qemu-action@v3
- uses: docker/setup-buildx-action@v3
- uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

When changing `docker/Dockerfile`, verify both arch builds pass locally before pushing. If a dependency has no arm64 binary, pin it to an amd64-specific build stage.

## setup.ps1 — Maintenance Points

When adding a new database, update `setup.ps1` in three places:

1. **Image pull list** — add the new image:
   ```powershell
   $images = @(
       'postgres:16',
       'mcr.microsoft.com/mssql/server:2022-latest',
       'gvenzl/oracle-free:latest',
       'mongo:7',
       'exasol/docker-db:latest',
       'new-db/image:tag'   # add here
   )
   ```

2. **EF migration loop** — add only if the connector uses EF Core:
   ```powershell
   $efProjects = @(
       'src/SqlSpaExplorer.Connectors.Postgres',
       # ... existing ...
       'src/SqlSpaExplorer.Connectors.NewDb'   # only if EF-backed
   )
   ```

3. **Prereq check** — add any new CLI tool the connector requires (e.g., a vendor CLI).

## DocFX — Docs Maintenance

- API reference is auto-generated from XML doc comments. Set `<GenerateDocumentationFile>true</GenerateDocumentationFile>` in every connector `.csproj` and the Core project.
- Architecture articles live in `docs/articles/`. Register new articles in `docs/articles/toc.yml` — an unlisted article will not appear in the site nav.
- Preview locally before pushing: `docfx docs/docfx.json --serve` → http://localhost:8080
- The `docfx-pages.yml` workflow publishes on every push to `main`. If the Pages deploy fails, check the `gh-pages` branch is set as the Pages source in the repo settings.

## Diagnosing Slow-Starting Containers

Oracle and Exasol routinely take 60–120 s on first start. If connector integration tests fail immediately after `docker compose up`:

```bash
# Check health status of all containers
docker compose -f docker/docker-compose.yml ps

# Stream logs for the slow container
docker compose -f docker/docker-compose.yml logs -f oracle
docker compose -f docker/docker-compose.yml logs -f exasol
```

Wait for the health check to report `healthy` before running tests. Do not reduce `start_period` below 90 s for Oracle or Exasol.

## Enforcement

- Every DB service in `docker-compose.yml` must have a `healthcheck` block — no service without one.
- The `app` service must list every DB service under `depends_on` with `condition: service_healthy`.
- Never commit `docker/.env` — only `.env.example` is tracked. Verify `.gitignore` excludes `.env`.
- Integration tests must be tagged `[Trait("Category", "Integration")]` and filtered out of `ci.yml` with `--filter "Category!=Integration"` — live DB tests do not run in GitHub Actions.
- `setup.ps1` must use `$ErrorActionPreference = 'Stop'` at the top — any failed step must abort the script.
- When adding an image with `platform: linux/amd64` to `docker-compose.yml`, confirm whether it also affects the app container's Dockerfile build chain before updating `docker-build.yml`.
