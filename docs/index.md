<!-- V1: Blazor Example + Docker Infrastructure -->
# SQL SPA Explorer

SQL SPA Explorer is an open-source Blazor web application for browsing schemas and running queries across multiple database engines through a single unified UI.

## Quick Start

```bash
pwsh ./setup.ps1
# Then open http://localhost:42080
```

## Supported Databases

| Database   | Access pattern       | EF Core |
|------------|----------------------|---------|
| MongoDB    | `MongoDB.Driver`     | No      |
| SQLite     | EF Core              | Full    |
| PostgreSQL | EF Core              | Full    |
| Oracle     | EF Core              | Full    |
| SQL Server | EF Core              | Full    |
| Exasol     | Raw ADO.NET          | No      |

## Learn More

- [Architecture](articles/architecture.md) — connector design and `TabularResult` contract
- [Infrastructure](articles/infrastructure.md) — Docker stack, port layout, init scripts
- [API Reference](api/index.md) — generated from XML doc comments
