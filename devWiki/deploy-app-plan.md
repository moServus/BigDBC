# Proto Deploy Plan

Step-by-step plan for starting the proto stack, deploying local source into the container image, and running the app.

---

## Phase 1 — Start the Proto Docker Stack

**Goal:** Bring up `metaMongoDB` and ensure it passes its health check before the app container starts.

**Pre-conditions:**
- OrbStack (or Docker Desktop) is running
- `.env` file exists at `docker/.env` with `MONGO_USERNAME` and `MONGO_PASSWORD` set (copy from `docker/.env.example`)

**Steps:**

```bash
# From repo root
docker compose -f docker/docker-compose.proto.yml up -d
```

**Verify:**
```bash
docker compose -f docker/docker-compose.proto.yml ps
# metaMongoDB should show: healthy
# bigdbc should show: running (or starting)
```

Health check waits up to ~130 s (30 s start_period + 10 retries × 10 s interval). The `bigdbc` service will not start until `metaMongoDB` is healthy.

---

## Phase 2 — Deploy Local App Files into the Container

The `bigdbc` container is built from local source via the two-stage `docker/Dockerfile`. "Deploying local files" means rebuilding the image from the current working tree and recreating the container.

**Steps:**

```bash
# Rebuild the bigdbc image from local source (runs dotnet publish inside build stage)
docker compose -f docker/docker-compose.proto.yml build bigdbc

# Recreate the container with the new image (no-deps keeps metaMongoDB untouched)
docker compose -f docker/docker-compose.proto.yml up -d --no-deps bigdbc
```

**What the build does (Dockerfile summary):**
1. Stage 1 (`build`) — `dotnet restore` → `dotnet publish -c Release -o /app/publish`
2. Stage 2 (`runtime`) — copies `/app/publish` into `mcr.microsoft.com/dotnet/aspnet:9.0`

**Tip — faster inner loop:** If you only need to iterate on static assets or Razor views, you can publish locally and copy the output directly:

```bash
dotnet publish src/SqlSpaExplorer.Web/SqlSpaExplorer.Web.csproj -c Release -o /tmp/bigdbc-publish
docker cp /tmp/bigdbc-publish/. bigdbc:/app/
docker restart bigdbc
```

Use `docker build` for a clean, reproducible deploy; use `docker cp` for quick dev iteration only.

---

## Phase 3 — Run the App in the Container

The app starts automatically as the container's `ENTRYPOINT` (`dotnet SqlSpaExplorer.Web.dll`). No manual start command is needed once the container is up.

**Verify the app is running:**
```bash
# Tail logs — look for "Now listening on: http://[::]:8080"
docker logs -f bigdbc

# Hit the health endpoint from the host
curl -s http://localhost:42080/
```

**Access the app:**
- Host URL: `http://localhost:42080`
- Internal port (container-to-container): `http://bigdbc:8080`

**Tear down:**
```bash
docker compose -f docker/docker-compose.proto.yml down
# Add -v to also remove mongo_data and protoSQLite volumes (destructive — clears all data)
```

---

## Summary

| Phase | Command | Done when |
|-------|---------|-----------|
| 1 — Start stack | `docker compose … up -d` | `metaMongoDB` health = **healthy** |
| 2 — Deploy source | `docker compose … build bigdbc` + `up -d --no-deps bigdbc` | `bigdbc` container recreated |
| 3 — Verify app | `docker logs -f bigdbc` + `curl localhost:42080` | "Now listening on …" in logs, HTTP 200 from curl |
