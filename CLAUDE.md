# CLAUDE.md

This file provides guidance to Claude Code (and other contributors) when working in this repository.

## Table of Contents

- [Project Overview](#project-overview)
- [Supported Databases](#supported-databases-6)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Key Conventions](#key-conventions)
- [Build & Run](#build--run)
- [Testing](#testing)
- [Claude Code Configuration](#claude-code-configuration)
  - [Skills](#skills-claudeskills)
  - [Agents](#agents-claudeagents)
  - [Commands](#commands-claudecommands)
- [Gotchas](#gotchas)

## Project Overview [↑](#table-of-contents)

**SQL SPA Explorer** is an open-source Blazor/Razor web application for browsing schemas and running queries against multiple database engines through a single unified UI. It targets local development on a **Mac Mini M4 (Apple Silicon)** but is designed to run cross-platform via Docker.

The core idea: a single `IDatabaseConnector` abstraction normalizes access across relational, document, and ADO.NET-only databases, returning a common `TabularResult` shape that the UI renders identically regardless of source.

## Supported Databases (6) [↑](#table-of-contents)

| # | Database | Access pattern | EF Core support |
|---|---|---|---|
| 1 | MongoDB | `MongoDB.Driver` (native) | Preview only — not used |
| 2 | SQLite | EF Core | Full (`Microsoft.EntityFrameworkCore.Sqlite`) |
| 3 | PostgreSQL | EF Core | Full (`Npgsql.EntityFrameworkCore.PostgreSQL`) |
| 4 | Oracle | EF Core | Full (`Oracle.EntityFrameworkCore`) |
| 5 | SQL Server | EF Core | Full (`Microsoft.EntityFrameworkCore.SqlServer`) |
| 6 | Exasol | Raw ADO.NET (`EXADataProvider`) | None — no EF provider exists |

**Platform note (arm64):** SQL Server and Exasol have no native arm64 Docker images and run under Rosetta emulation. All other containers are arm64-native.

## Tech Stack [↑](#table-of-contents)

- **.NET 8** — Razor Components (Blazor)
- **Radzen.Blazor** — `RadzenDataGrid` for dynamic/runtime-defined result columns, `RadzenDialogService`/`NotificationService` for UX
- **Monaco Editor** — SQL input via JS interop, with per-connector schema-aware autocomplete
- **Docker / OrbStack** — 7 containers total (6 DBs + app)
- **DocFX** — API docs (from XML comments) + architecture docs, published to GitHub Pages

## Repository Structure [↑](#table-of-contents)

```
sql-spa-explorer/
├── .claude/
│   ├── settings.json
│   ├── settings.local.json
│   ├── agents/
│   │   ├── architect.md
│   │   ├── infra-architect.md
│   │   ├── mongo-db-connector-builder.md
│   │   ├── jdbc-db-ef-connector-builder.md
│   │   ├── jdbc-db-exasol-connector-builder.md
│   │   ├── radzen-ui-designer.md
│   │   ├── db-connector-builder.md
│   │   ├── query-ef-designer.md
│   │   ├── docker-stack-doctor.md
│   │   └── ui-designer.md
│   ├── skills/
│   │   ├── dotnet-core/SKILL.md
│   │   ├── connector-abstraction/SKILL.md
│   │   ├── ef-core-provider/SKILL.md
│   │   ├── exasol-adonet/SKILL.md
│   │   ├── razor-components/SKILL.md
│   │   ├── radzen-components/SKILL.md
│   │   ├── monaco-editor/SKILL.md
│   │   ├── docker-compose/SKILL.md
│   │   ├── github-workflows/SKILL.md
│   │   ├── github-pages-docfx/SKILL.md
│   │   └── powershell-scripts/SKILL.md
│   └── commands/
│       ├── new-connector.md
│       ├── db-up.md
│       └── ef-migrate.md
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   ├── docker-build.yml
│   │   ├── docfx-pages.yml
│   │   └── codeql.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS
│
├── docker/
│   ├── docker-compose.yml
│   ├── docker-compose.override.yml
│   ├── Dockerfile
│   ├── .env.example
│   └── init-scripts/
│       ├── postgres/init.sql
│       ├── sqlserver/init.sql
│       ├── oracle/init.sql
│       ├── mongo/init.js
│       └── exasol/init.sql
│
├── docs/
│   ├── docfx.json
│   ├── toc.yml
│   ├── index.md
│   └── articles/
│
├── src/
│   ├── SqlSpaExplorer.sln
│   ├── SqlSpaExplorer.Web/
│   │   ├── Components/
│   │   │   ├── Pages/
│   │   │   │   ├── Home.razor
│   │   │   │   └── QueryExplorer.razor
│   │   │   ├── Shared/
│   │   │   │   ├── MainLayout.razor
│   │   │   │   └── NavMenu.razor
│   │   │   └── QueryEditor/
│   │   │       ├── MonacoSqlEditor.razor
│   │   │       └── ResultGrid.razor
│   │   ├── wwwroot/
│   │   │   ├── js/monaco-interop.js
│   │   │   └── css/app.css
│   │   ├── Program.cs
│   │   ├── appsettings.json
│   │   ├── appsettings.Development.json
│   │   └── SqlSpaExplorer.Web.csproj
│   ├── SqlSpaExplorer.Core/
│   │   ├── Abstractions/
│   │   │   ├── IDatabaseConnector.cs
│   │   │   ├── IQueryResult.cs
│   │   │   └── ConnectorMetadata.cs
│   │   ├── Models/
│   │   │   ├── TabularResult.cs
│   │   │   └── SchemaMetadata.cs
│   │   ├── Registry/
│   │   │   └── ConnectorRegistry.cs
│   │   └── SqlSpaExplorer.Core.csproj
│   ├── SqlSpaExplorer.Connectors.Postgres/
│   ├── SqlSpaExplorer.Connectors.SqlServer/
│   ├── SqlSpaExplorer.Connectors.Oracle/
│   ├── SqlSpaExplorer.Connectors.Sqlite/
│   ├── SqlSpaExplorer.Connectors.Mongo/
│   └── SqlSpaExplorer.Connectors.Exasol/
│
├── tests/
│   ├── SqlSpaExplorer.Core.Tests/
│   ├── SqlSpaExplorer.Connectors.Tests/
│   └── SqlSpaExplorer.Web.Tests/
│
└── setup.ps1
```


## Key Conventions [↑](#table-of-contents)

- **One connector project per database**, each implementing `IDatabaseConnector` from `Core`. EF-backed connectors (Postgres, SQL Server, Oracle, SQLite) carry their own `DbContext`; MongoDB and Exasol do **not** reference EF Core at all — keep that separation strict.
- **`TabularResult`** is the universal contract between connectors and the UI. Any new connector must map its native result shape (rows/docs/cursors) into this format — this is what lets `RadzenDataGrid` render any database's output with the same component.
- **Monaco autocomplete** is schema-driven: connectors expose table/column metadata, which feeds Monaco's per-database language provider. When adding a connector, implement the schema-metadata method even if the query language itself (e.g., Mongo aggregation JSON) isn't classic SQL.
- **Async-first**: all connector I/O is `async`/`await`. No blocking calls on DB drivers.

## Build & Run [↑](#table-of-contents)

```bash
# Full first-time setup (tools, images, env, compose, restore)
pwsh ./setup.ps1

# Subsequent runs — just bring up the DB stack
docker compose -f docker/docker-compose.yml up -d

# Run the app locally (outside container, against containerized DBs)
dotnet run --project src/SqlSpaExplorer.Web
```

EF migrations (per provider — Postgres, SQL Server, Oracle, SQLite only):

```bash
dotnet ef migrations add <Name> --project src/SqlSpaExplorer.Connectors.<Provider>
dotnet ef database update --project src/SqlSpaExplorer.Connectors.<Provider>
```

## Testing [↑](#table-of-contents)

- `tests/SqlSpaExplorer.Core.Tests/` — abstraction-layer unit tests, no live DB needed
- `tests/SqlSpaExplorer.Connectors.Tests/` — one test class per connector; run against the Docker-compose stack (Oracle/SQL Server/Exasol have slow startup — allow for health checks before running these)
- `tests/SqlSpaExplorer.Web.Tests/` — component tests (bUnit)

## Claude Code Configuration [↑](#table-of-contents)

### Skills (`.claude/skills/`) [↑](#table-of-contents)

| Skill | Use when... |
|---|---|
| [`dotnet-core`](.claude/skills/dotnet-core/SKILL.md) | General .NET conventions, DI, connector registration |
| [`connector-abstraction`](.claude/skills/connector-abstraction/SKILL.md) | Implementing/modifying `IDatabaseConnector` or `TabularResult` |
| [`ef-core-provider`](.claude/skills/ef-core-provider/SKILL.md) | Adding/configuring an EF Core provider (Postgres/SQL Server/Oracle/SQLite) |
| [`exasol-adonet`](.claude/skills/exasol-adonet/SKILL.md) | Working on the Exasol connector (raw ADO.NET, no EF) |
| [`razor-components`](.claude/skills/razor-components/SKILL.md) | House-style Razor components, shared layout, page structure |
| [`radzen-components`](.claude/skills/radzen-components/SKILL.md) | `RadzenDataGrid` dynamic columns, dialogs, notifications, theming |
| [`monaco-editor`](.claude/skills/monaco-editor/SKILL.md) | SQL editor JS interop, language modes, schema-driven autocomplete |
| [`docker-compose`](.claude/skills/docker-compose/SKILL.md) | Editing the 7-container stack, platform pinning, health checks, init scripts |
| [`github-workflows`](.claude/skills/github-workflows/SKILL.md) | CI/CD pipelines, multi-arch builds, CODEOWNERS |
| [`github-pages-docfx`](.claude/skills/github-pages-docfx/SKILL.md) | Docs site structure and DocFX build/publish |
| [`powershell-scripts`](.claude/skills/powershell-scripts/SKILL.md) | `setup.ps1` and other cross-platform scripts |

### Agents (`.claude/agents/`) [↑](#table-of-contents)

| Agent | Purpose |
|---|---|
| [`architect`](.claude/agents/architect.md) | Owns Core abstractions (`IDatabaseConnector`, `TabularResult`, `ConnectorRegistry`); decides connector design, solution structure, and cross-layer changes |
| [`infra-architect`](.claude/agents/infra-architect.md) | Owns Docker Compose stack, GitHub Actions workflows, `setup.ps1`, and DocFX/Pages publishing |
| [`mongo-db-connector-builder`](.claude/agents/mongo-db-connector-builder.md) | Builds MongoDB data access for application metadata (saved queries, history, schema cache) — raw `MongoDB.Driver`, no EF |
| [`jdbc-db-ef-connector-builder`](.claude/agents/jdbc-db-ef-connector-builder.md) | Builds EF Core connectors for JDBC-only datastores (DB2, SAP HANA, Firebird, etc.) via IKVM.NET or ODBC-JDBC gateway |
| [`jdbc-db-exasol-connector-builder`](.claude/agents/jdbc-db-exasol-connector-builder.md) | Builds the Exasol connector with dual access: ADO.NET (`EXADataProvider`) for queries + JDBC (IKVM) for EXALoader bulk import |
| [`db-connector-builder`](.claude/agents/db-connector-builder.md) | Scaffolds a new `IDatabaseConnector` implementation end-to-end — driver strategy decision, project scaffold, `TabularResult` mapping, DI registration, handoff checklist |
| [`query-ef-designer`](.claude/agents/query-ef-designer.md) | Designs EF Core query layer, `DbContext`, LINQ patterns, and migrations for all 4 EF-capable providers (Postgres, SQL Server, Oracle, SQLite) |
| [`docker-stack-doctor`](.claude/agents/docker-stack-doctor.md) | Diagnoses container/compose issues: unhealthy services, Rosetta failures, port conflicts, init-script errors, volume resets |
| [`ui-designer`](.claude/agents/ui-designer.md) | Builds the query explorer page, Monaco editor interop, result grid, and connector navigation |
| [`radzen-ui-designer`](.claude/agents/radzen-ui-designer.md) | Owns `RadzenDataGrid` dynamic columns, dialogs, notifications, and application theming |

### Commands (`.claude/commands/`) [↑](#table-of-contents)

- `/new-connector <db-name>` — scaffold a new connector project + registration
- `/db-up` — bring up the compose stack
- `/ef-migrate <provider> <name>` — run EF migration for one provider

## Gotchas [↑](#table-of-contents)

- **Exasol & SQL Server** run under Rosetta — slower startup, allow extra time in health checks before connector tests run against them.
- **MongoDB and Exasol projects must not reference any `Microsoft.EntityFrameworkCore.*` package** — this is enforced by convention, watch for accidental transitive references.
- **Oracle** uses the community `gvenzl/oracle-free` image (arm64-native), not Oracle's official image (requires account/license).
- When adding a new database, update: connector project, `ConnectorRegistry`, `docker-compose.yml`, `.env.example`, `setup.ps1` image list, and the relevant skill docs.