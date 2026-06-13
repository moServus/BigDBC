# Skill: ef-core-provider

Covers adding or modifying an EF Core-backed connector (Postgres, SQL Server, Oracle, SQLite).

## Project References

Each EF connector carries its own `DbContext` and NuGet provider. MongoDB and Exasol must **not** reference any `Microsoft.EntityFrameworkCore.*` package.

| Provider | Package |
|---|---|
| PostgreSQL | `Npgsql.EntityFrameworkCore.PostgreSQL` |
| SQL Server | `Microsoft.EntityFrameworkCore.SqlServer` |
| Oracle | `Oracle.EntityFrameworkCore` |
| SQLite | `Microsoft.EntityFrameworkCore.Sqlite` |

Also include `Microsoft.EntityFrameworkCore.Design` as a dev-time dependency for tooling.

## DbContext Pattern

Each connector uses a minimal `DbContext` (query execution only — no entity models unless schema browsing requires them). Use raw SQL via `Database.ExecuteSqlRawAsync` or `FromSqlRaw`:

```csharp
await using var ctx = _factory.CreateDbContext();
var result = await ctx.Database.ExecuteSqlRawAsync(query, ct);
```

For result-set queries, drop down to `DbConnection`:

```csharp
await using var conn = _factory.CreateDbContext().Database.GetDbConnection();
await conn.OpenAsync(ct);
await using var cmd = conn.CreateCommand();
cmd.CommandText = query;
await using var reader = await cmd.ExecuteReaderAsync(ct);
// map reader → TabularResult
```

Register with `IDbContextFactory<T>` (not `IDbContext<T>`) to support concurrent queries without shared context state.

## Migrations

Tool commands (run from repo root):

```bash
dotnet ef migrations add <Name> --project src/SqlSpaExplorer.Connectors.<Provider>
dotnet ef database update --project src/SqlSpaExplorer.Connectors.<Provider>
```

Migration files live in `src/SqlSpaExplorer.Connectors.<Provider>/Migrations/`. Commit generated migrations; never edit them by hand unless fixing a broken scaffold.

## Connection String Binding

```csharp
services.AddDbContextFactory<MyDbContext>(opts =>
    opts.UseNpgsql(configuration.GetConnectionString("Postgres")));
```

Connection strings are in `appsettings.json` under `ConnectionStrings.<Provider>`.

## Schema Query

For `GetSchemaAsync`, query information_schema (Postgres/SQL Server/SQLite) or ALL_TABLES/ALL_COLUMNS (Oracle) rather than using EF's model metadata — this reflects the live DB state, not just the mapped entities.
