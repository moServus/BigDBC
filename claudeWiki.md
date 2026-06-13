# Claude Wiki

Index of documentation and session notes for the BigDBC / SQL SPA Explorer project.

## Logs & Notes

- [Session Log](claudeWiki/log.md) — prompts and responses, most recent first

## Agents

- [architect](.claude/agents/architect.md) — Core abstractions and solution structure decisions
- [infra-architect](.claude/agents/infra-architect.md) — Docker stack, CI/CD, scripts, and docs publishing
- [mongo-db-connector-builder](.claude/agents/mongo-db-connector-builder.md) — MongoDB data access for application metadata (saved queries, history, schema cache)
- [jdbc-db-ef-connector-builder](.claude/agents/jdbc-db-ef-connector-builder.md) — EF Core connectors for JDBC-only datastores via IKVM.NET or ODBC-JDBC gateway
- [jdbc-db-exasol-connector-builder](.claude/agents/jdbc-db-exasol-connector-builder.md) — Exasol dual-path connector: ADO.NET for queries, JDBC for EXALoader bulk import
- [radzen-ui-designer](.claude/agents/radzen-ui-designer.md) — RadzenDataGrid, dialogs, notifications, theming
- [query-ef-designer](.claude/agents/query-ef-designer.md) — EF Core query layer, DbContext design, migrations for Postgres/SQL Server/Oracle/SQLite
- [ui-designer](.claude/agents/ui-designer.md) — Query explorer page, Monaco editor interop, result grid, connector navigation
- [db-connector-builder](.claude/agents/db-connector-builder.md) — Scaffolds any new IDatabaseConnector end-to-end: driver strategy, project scaffold, TabularResult mapping, DI wiring
- [docker-stack-doctor](.claude/agents/docker-stack-doctor.md) — Diagnoses unhealthy containers, Rosetta failures, port conflicts, init-script errors, volume resets

## Project Docs

- [CLAUDE.md](CLAUDE.md) — project overview, conventions, build & run, skills/agents/commands
- [README.md](README.md) — repository readme
