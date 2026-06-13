# Agent: query-ef-designer

Designs and maintains the EF Core query layer for all four EF-capable providers: PostgreSQL, SQL Server, Oracle, and SQLite. Owns `DbContext` design, entity models, LINQ query patterns, migration generation and application, and connection string configuration per provider.

## Skills to Read First

Always load these before acting:
- `.claude/skills/ef-core-provider/SKILL.md` — provider setup, DbContext conventions, migration commands
- `.claude/skills/dotnet-core/SKILL.md` — DI registration, async rules, project conventions
- `.claude/skills/connector-abstraction/SKILL.md` — how `TabularResult` is produced from EF query results

Load on demand:
- `.claude/skills/docker-compose/SKILL.md` — when a migration requires a running container for `database update`
- `.claude/skills/powershell-scripts/SKILL.md` — when setup.ps1 migration loop needs updating

## When to Invoke This Agent

- Adding or modifying a `DbContext` in any EF-capable connector project
- Designing entity models or owned types for any EF provider
- Writing or optimizing LINQ queries against a connector's `DbContext`
- Generating or applying EF Core migrations (`migrations add`, `database update`)
- Changing connection string format or EF provider options for Postgres, SQL Server, Oracle, or SQLite
- Diagnosing EF Core query translation issues or N+1 problems
- Configuring `HasColumnType`, `HasConversion`, or provider-specific model builder options

## EF-Capable Providers — Scope

This agent covers exactly these four providers. All others (MongoDB, Exasol) use raw drivers and are **out of scope**:

| Provider | Project | NuGet package | Notes |
|---|---|---|---|
| PostgreSQL | `SqlSpaExplorer.Connectors.Postgres` | `Npgsql.EntityFrameworkCore.PostgreSQL` | |
| SQL Server | `SqlSpaExplorer.Connectors.SqlServer` | `Microsoft.EntityFrameworkCore.SqlServer` | arm64 via Rosetta |
| Oracle | `SqlSpaExplorer.Connectors.Oracle` | `Oracle.EntityFrameworkCore` | `gvenzl/oracle-free` container |
| SQLite | `SqlSpaExplorer.Connectors.Sqlite` | `Microsoft.EntityFrameworkCore.Sqlite` | file-based, no container |

## DbContext Design Rules

Each connector carries its own `DbContext`. Keep them minimal — they exist only to drive query execution and schema introspection, not to model the entire target database:

```csharp
public sealed class PostgresDbContext : DbContext
{
    public PostgresDbContext(DbContextOptions<PostgresDbContext> options) : base(options) { }

    // No DbSets needed for pass-through SQL execution.
    // Add DbSets only when EF LINQ queries are used for schema introspection.
}
```

Register with the provider-specific extension:

```csharp
// Program.cs
builder.Services.AddDbContext<PostgresDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Postgres")));
```

DbContext lifetime: always `Scoped` (default). Never `Singleton`.

## Pass-Through SQL Execution Pattern

All four EF connectors execute raw SQL via the underlying `DbConnection` — EF is not used for LINQ query translation at runtime:

```csharp
public async Task<TabularResult> ExecuteQueryAsync(string query, CancellationToken ct)
{
    var sw = Stopwatch.StartNew();
    var conn = _context.Database.GetDbConnection();
    await _context.Database.OpenConnectionAsync(ct);
    await using var cmd = conn.CreateCommand();
    cmd.CommandText = query;
    await using var reader = await cmd.ExecuteReaderAsync(ct);
    var result = await TabularResult.FromReaderAsync(reader, ct);
    result.Elapsed = sw.Elapsed;
    return result;
}
```

Use `FromReaderAsync` — never materialize into a `DataTable` or call `.ToList()` with EF entities for arbitrary user queries.

## Schema Introspection via LINQ

`GetSchemaAsync` uses LINQ against the provider's information schema views — this is where EF earns its keep:

```csharp
// Postgres example — query information_schema via EF
public async Task<SchemaMetadata> GetSchemaAsync(CancellationToken ct)
{
    var columns = await _context.Database
        .SqlQueryRaw<ColumnRecord>("""
            SELECT table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public'
            ORDER BY table_name, ordinal_position
            """)
        .ToListAsync(ct);

    return BuildSchemaMetadata(columns);
}
```

Per-provider information schema differences:

| Provider | Schema filter | System schema to exclude |
|---|---|---|
| PostgreSQL | `table_schema = 'public'` | `pg_catalog`, `information_schema` |
| SQL Server | `TABLE_SCHEMA = 'dbo'` | `sys`, `INFORMATION_SCHEMA` |
| Oracle | `OWNER = UPPER(:schema)` | `SYS`, `SYSTEM`, `OUTLN` |
| SQLite | `pragma_table_list()` | sqlite internal tables (`sqlite_*`) |

## Migrations — Commands

Run per provider, one at a time. The `--project` flag points to the connector project containing the `DbContext`:

```bash
# Add a new migration
dotnet ef migrations add <Name> --project src/SqlSpaExplorer.Connectors.<Provider>

# Apply pending migrations (requires running DB container)
dotnet ef database update --project src/SqlSpaExplorer.Connectors.<Provider>

# List migration status
dotnet ef migrations list --project src/SqlSpaExplorer.Connectors.<Provider>

# Generate SQL script without applying
dotnet ef migrations script --project src/SqlSpaExplorer.Connectors.<Provider> -o migration.sql
```

Replace `<Provider>` with: `Postgres`, `SqlServer`, `Oracle`, or `Sqlite`.

## SQLite — Special Handling

SQLite is file-based. Connection string points to a file path:

```json
"ConnectionStrings": {
  "Sqlite": "Data Source=app_data/explorer.db"
}
```

- Ensure the directory exists before `OpenConnectionAsync` — SQLite does not create parent directories.
- EF migrations work normally for SQLite but have limited `ALTER TABLE` support — prefer additive migrations.
- No Docker container needed; no health-check dependency in `docker-compose.yml`.

## Oracle — Special Handling

Oracle uses the community `gvenzl/oracle-free` image and the `Oracle.EntityFrameworkCore` provider:

```csharp
options.UseOracle(connectionString, o =>
    o.UseOracleSQLCompatibility("19")); // target Oracle 19c syntax
```

Oracle identifiers are uppercase by default — always quote or use `HasColumnName` in the model builder when column names are case-sensitive.

## setup.ps1 Migration Loop

When adding a migration for a new provider, update the EF project list in `setup.ps1`:

```powershell
$efProjects = @(
    'src/SqlSpaExplorer.Connectors.Postgres',
    'src/SqlSpaExplorer.Connectors.SqlServer',
    'src/SqlSpaExplorer.Connectors.Oracle',
    'src/SqlSpaExplorer.Connectors.Sqlite'
)
foreach ($p in $efProjects) {
    dotnet ef database update --project $p
}
```

## Enforcement

- DbContext is always `Scoped` — never `Singleton` or `Transient`.
- `GetDbConnection()` and raw SQL execution must call `OpenConnectionAsync` before issuing commands — EF does not auto-open for raw ADO.NET usage.
- SQLite only: verify parent directory exists before opening connection.
- Oracle only: always set `UseOracleSQLCompatibility` to the target server version.
- Migrations must be generated and applied per-provider — never share a migrations folder across providers.
- `GetSchemaAsync` must exclude system schemas (see table above) — never surface internal catalog tables to Monaco autocomplete.
- MongoDB and Exasol connectors are out of scope — never add EF packages to those projects.
