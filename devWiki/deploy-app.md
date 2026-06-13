# Deploy Log — Proto Stack

Log of proto-stack deployments. Add a dated entry each time you run through the deploy plan.
See [deploy-app-plan.md](deploy-app-plan.md) for the full step-by-step procedure.

---

## Log Format

```
### YYYY-MM-DD — <short description>

**Phase 1 (stack up):** <outcome / notes>
**Phase 2 (deploy source):** <outcome / notes — build time, any errors>
**Phase 3 (app verify):** <outcome — port, response, log line>
**Issues / Follow-up:** <anything that needed fixing>
```

---

<!-- Add new entries below this line, newest first -->

### 2026-06-13 — First full proto deploy executed

**Phase 1 (stack up):** `metaMongoDB` recreated and reached healthy in ~30 s. `bigdbc` was already running and held while Mongo came up.
**Phase 2 (deploy source):** `docker compose build bigdbc` completed successfully — all 24 build layers cached (prior build present). Container recreated with `up -d --no-deps bigdbc`.
**Phase 3 (app verify):** `Now listening on: http://[::]:8080` confirmed in logs. `curl http://localhost:42080/` returned HTTP 200.
**Issues / Follow-up:** Two DataProtection warnings (keys not persisted outside container, no XML encryptor). Non-blocking for proto stage — revisit before any persistent-session feature.
