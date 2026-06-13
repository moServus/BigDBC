# Session Log

## 2026-06-13

---

### Prompt `2026-06-13` `#Setup`
Connect this VS Code workspace to my GitHub repo https://github.com/moServus/BigDBC

### Response
Initialized a git repository in the workspace, added `origin` pointing to `https://github.com/moServus/BigDBC.git`, fetched and pulled the remote `main` branch (which contained `LICENSE` and `README.md`), renamed local branch from `master` to `main`, and set it to track `origin/main`. Local files `CLAUDE.md` and `.claude/` remain untracked — push deferred by user.

---

### Prompt `2026-06-13` `#Setup`
Create a claudeWiki.md and a subdirectory "claudeWiki" plus a log.md with all prompts from now on and logging your answers. The claudeWiki.md will be an overview of md files. Put the link to the log.md for starters.

### Response
Created `claudeWiki/` subdirectory, `claudeWiki/log.md` (this file), and `claudeWiki.md` as a wiki index. `claudeWiki.md` links to this log. Both files are untracked pending a future push.

---

### Prompt `2026-06-13` `#Setup`
Now lets plan the agent setup starting with the architect and infrastructure architect for this project.

### Response
Planned and created two new agent files in `.claude/agents/`:

- **`architect.md`** — owns Core abstractions (`IDatabaseConnector`, `TabularResult`, `SchemaMetadata`, `ConnectorRegistry`); decides EF vs. raw ADO.NET per connector; includes 9-step new-connector checklist, breaking-change protocol, DI wiring example, and enforcement rules. Always loads `connector-abstraction` + `dotnet-core` skills.

- **`infra-architect.md`** — owns Docker Compose stack (6 services + platform pins), GitHub Actions workflows (ci.yml, docker-build.yml, docfx-pages.yml, codeql.yml), `setup.ps1`, and DocFX/Pages. Includes container inventory table, health-check templates, multi-arch build snippet, slow-container diagnostics, and enforcement rules. Always loads `docker-compose` + `github-workflows` + `powershell-scripts` skills.

Also updated `CLAUDE.md` (agents table now has 6 rows, structure tree updated) and `claudeWiki.md` (new Agents section with links to both files).

---

### Prompt `2026-06-13` `#Setup`
Add a mongo-db-connector-builder for accessing the application metadata stored.

### Response
Created `.claude/agents/mongo-db-connector-builder.md` — an agent for building MongoDB data access for application-internal metadata (saved queries, connection profiles, query history, schema cache). Key decisions captured: separate project `SqlSpaExplorer.Metadata.Mongo` (not the user-facing connector), raw `MongoDB.Driver` with no EF, singleton `IMongoClient`/`IMongoDatabase` via DI, repository pattern with `EnsureIndexes()` in constructor, schema cache stored as JSON string. Updated CLAUDE.md (7 rows in agents table) and `claudeWiki.md`.

---

### Prompt `2026-06-13` `#Setup`
Add agent jdbc-db-ef-connector-builder for accessing only jdbc datastores, plus jdbc-db-exasol-connector-builder for accessing only exasol databases with jdbc and ADO.NET.

### Response
Created two new agent files:

- **`jdbc-db-ef-connector-builder.md`** — for JDBC-only datastores (DB2, SAP HANA, Firebird, Informix, Derby). Two bridging strategies: IKVM.NET (preferred, no JVM at runtime — converts JDBC jar to .NET assembly at build time) and ODBC-JDBC gateway (simpler, needs JVM in Docker). EF Core sits on top via `UseDbConnection` or `UseOdbc`. Includes vendor schema catalog query table, Docker JVM setup, and 9-step checklist.

- **`jdbc-db-exasol-connector-builder.md`** — dual access path for Exasol: ADO.NET `EXADataProvider` as default for all standard queries, JDBC via IKVM for EXALoader bulk import (port 2580). Covers `EXA_ALL_COLUMNS` schema query, Exasol-specific SQL syntax table (FETCH FIRST, not LIMIT), Docker arm64/Rosetta container config, and DI registration with optional JDBC path. Cross-references `jdbc-db-ef-connector-builder` for IKVM setup pattern.

Updated `CLAUDE.md` (9 rows in agents table) and `claudeWiki.md`.

---

### Prompt `2026-06-13` `#Setup`
Add agent radzen-ui-designer. Rename ef-migration-runner to query-ef-designer (still responsible for EF capable providers). Rename query-ui-designer to ui-designer. Create md files for all.

### Response
Created three agent files:

- **`radzen-ui-designer.md`** — owns all Radzen Blazor component usage: `RadzenDataGrid` dynamic column pattern (with mandatory `Width`), `RadzenDialogService` modals, `RadzenNotificationService` toasts (duration rules), theme overrides in `app.css`. Includes `AddRadzenComponents()` registration, `TabularResult` → grid binding, and enforcement rules.

- **`query-ef-designer.md`** (renamed from `ef-migration-runner`) — designs and maintains the EF Core query layer for all 4 EF-capable providers (Postgres, SQL Server, Oracle, SQLite). Covers pass-through SQL execution via `GetDbConnection()`, `GetSchemaAsync` LINQ per provider, migration commands, SQLite/Oracle special handling, and `setup.ps1` migration loop.

- **`ui-designer.md`** (renamed from `query-ui-designer`) — owns the full query UI flow: `QueryExplorer.razor` page state model, `MonacoSqlEditor` JS interop timing, schema feed caching, `ResultGrid` null/binary rendering, connector navigation in `NavMenu`. Includes enforcement rules for `firstRender` guard, error notification duration, and `finally` block on execution state.

Updated CLAUDE.md (structure tree + 11 rows in agents table) and `claudeWiki.md`.

---

### Prompt `2026-06-13` `#Setup`
Create the last 2 agents: db-connector-builder and docker-stack-doctor.

### Response
Created two final agent files:

- **`db-connector-builder.md`** — 8-step scaffolding guide for any new `IDatabaseConnector`: driver strategy decision table (EF / raw ADO.NET / JDBC / dual-path / MongoDB), `dotnet new` + `sln add` commands, `IDatabaseConnector` implementation template, `TabularResult` mapping patterns (reader-based and manual), `GetSchemaAsync` shape, DI extension method, handoff checklist to `infra-architect` / `architect` / `query-ef-designer` / `ui-designer`, and integration test scaffold with `[Trait("Category","Integration")]`.

- **`docker-stack-doctor.md`** — reactive diagnostic runbook: 5-step ordered diagnosis (ps → logs → inspect health → port conflicts → Rosetta check), per-service failure pattern tables for Oracle / SQL Server / Exasol / Postgres / MongoDB, clean-state restart sequence (with `down -v` warning), health-check timing minimums per service, and app container dependency failure diagnosis.

All 10 agent files now exist. Updated `CLAUDE.md` (all rows linked) and `claudeWiki.md`.

---

### Prompt `2026-06-13 12:01` `#Setup`
Add the timestamp to the session log.

### Response
Added `YYYY-MM-DD` timestamps to all past entries (date only — clock times not available for earlier messages). Added `YYYY-MM-DD HH:MM` format to this entry and all future entries.

---

### Prompt `2026-06-13 12:03` `#Setup`
Also add a session tag default for all now "Setup".

### Response
Added `` `#Setup` `` tag to all entries using `replace_all`. Format is now `### Prompt \`YYYY-MM-DD HH:MM\` \`#Setup\`` for timed entries and `### Prompt \`YYYY-MM-DD\` \`#Setup\`` for date-only entries.

---
