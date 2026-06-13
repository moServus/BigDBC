# Agent: jdbc-db-exasol-connector-builder

Builds and maintains the Exasol connector with **dual access paths**: the native ADO.NET `EXADataProvider` (already in the project) and the Exasol JDBC driver (via IKVM.NET). Use ADO.NET for standard query execution and schema browsing; use JDBC for operations where the Exasol JDBC driver exposes capabilities the ADO.NET driver does not (bulk import, EXALoader, specific driver flags).

## Skills to Read First

Always load these before acting:
- `.claude/skills/exasol-adonet/SKILL.md` — ADO.NET driver conventions, connection string format, known quirks
- `.claude/skills/connector-abstraction/SKILL.md` — IDatabaseConnector, TabularResult, SchemaMetadata
- `.claude/skills/dotnet-core/SKILL.md` — DI, async rules, project conventions

Load on demand:
- `.claude/skills/docker-compose/SKILL.md` — Exasol container platform pin, health check, slow-start handling
- [`jdbc-db-ef-connector-builder`](.claude/agents/jdbc-db-ef-connector-builder.md) — IKVM.NET setup pattern (reuse for JDBC path)

## When to Invoke This Agent

- Any change to `src/SqlSpaExplorer.Connectors.Exasol/`
- Switching or adding the JDBC access path alongside the existing ADO.NET path
- Exasol-specific query syntax issues (LIMIT vs. FETCH FIRST, dual-path row mapping)
- EXALoader / bulk import operations
- Exasol container startup failures or health-check tuning
- Debugging driver version mismatches between ADO.NET and JDBC paths

## Dual Access Architecture

```
SqlSpaExplorer.Connectors.Exasol/
├── ExasolConnector.cs              // IDatabaseConnector — routes to ADO.NET by default
├── ExasolAdoNetQueryService.cs     // ADO.NET path: EXADataProvider for queries + schema
├── ExasolJdbcQueryService.cs       // JDBC path: IKVM-bridged JDBC driver
├── ExasolBulkImportService.cs      // EXALoader bulk insert (JDBC only)
├── ExasolSchemaService.cs          // GetSchemaAsync — shared, queries EXA_ALL_COLUMNS
├── ExasolServiceExtensions.cs      // IServiceCollection extension
└── SqlSpaExplorer.Connectors.Exasol.csproj
```

Register both services; `ExasolConnector` decides which path to invoke based on operation type:

```csharp
public sealed class ExasolConnector : IDatabaseConnector
{
    private readonly ExasolAdoNetQueryService _adoNet;
    private readonly ExasolJdbcQueryService _jdbc;      // optional — null if JDBC not configured
    private readonly ExasolSchemaService _schema;

    public ConnectorMetadata Metadata => new(
        Name: "Exasol",
        DisplayName: "Exasol",
        QueryLanguage: "sql");

    // Standard queries: ADO.NET
    public Task<TabularResult> ExecuteQueryAsync(string query, CancellationToken ct = default)
        => _adoNet.ExecuteAsync(query, ct);

    // Bulk import: JDBC path
    public Task BulkImportAsync(Stream csv, string tableName, CancellationToken ct = default)
        => _jdbc.BulkImportAsync(csv, tableName, ct);

    public Task<SchemaMetadata> GetSchemaAsync(CancellationToken ct = default)
        => _schema.GetAsync(ct);
}
```

## ADO.NET Path — EXADataProvider

The ADO.NET path is the default for all `IDatabaseConnector` query execution. Uses `Exasol.EXADataProvider`:

```csharp
public sealed class ExasolAdoNetQueryService
{
    private readonly string _connectionString;

    public async Task<TabularResult> ExecuteAsync(string query, CancellationToken ct)
    {
        var sw = Stopwatch.StartNew();
        await using var conn = new EXAConnection(_connectionString);
        await conn.OpenAsync(ct);
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = query;
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        var result = await TabularResult.FromReaderAsync(reader, ct);
        result.Elapsed = sw.Elapsed;
        return result;
    }
}
```

Connection string format (from `appsettings.json`):
```
"exasolHost=localhost;exasolPort=8563;uid=sys;pwd=exasol;schema=EXA_STATISTICS"
```

## JDBC Path — IKVM.NET Bridge

The JDBC path is used only for operations not supported by the ADO.NET driver (primarily EXALoader bulk import). Set it up following the IKVM pattern from the `jdbc-db-ef-connector-builder` agent.

```xml
<!-- SqlSpaExplorer.Connectors.Exasol.csproj -->
<ItemGroup>
  <IkvmReference Include="drivers/exasol-jdbc-*.jar">
    <AssemblyName>ExasolJdbcDriver</AssemblyName>
  </IkvmReference>
</ItemGroup>
```

Obtain the Exasol JDBC jar from Maven Central (`com.exasol:exasol-jdbc`). Place it in `drivers/` within the connector project and add `drivers/*.jar` to `.gitignore` (do not commit binary drivers).

```csharp
public sealed class ExasolJdbcQueryService
{
    private readonly string _jdbcUrl;  // "jdbc:exa:localhost:8563;schema=MY_SCHEMA"

    public async Task<TabularResult> ExecuteAsync(string query, CancellationToken ct)
    {
        return await Task.Run(() =>
        {
            // IKVM JDBC calls are synchronous Java — offload to thread pool
            using var conn = DriverManager.getConnection(_jdbcUrl, "sys", "exasol");
            using var stmt = conn.createStatement();
            using var rs = stmt.executeQuery(query);
            return TabularResult.FromJdbcResultSet(rs);
        }, ct);
    }
}
```

JDBC URL format: `jdbc:exa:<host>:<port>;<key>=<value>;...`

## EXALoader — Bulk Import (JDBC only)

Exasol's high-speed bulk import is only available via the JDBC driver's `EXALoader` API:

```csharp
public async Task BulkImportAsync(Stream csv, string tableName, CancellationToken ct)
{
    await Task.Run(() =>
    {
        using var conn = DriverManager.getConnection(_jdbcUrl, "sys", "exasol");
        using var loader = conn.createLoader(tableName, "CSV");
        loader.setBatchSize(10_000);
        using var writer = new StreamWriter(loader.getOutputStream());
        csv.CopyTo(writer.BaseStream);
        loader.finish();
    }, ct);
}
```

Never use `EXALoader` from the ADO.NET path — it does not expose this API.

## Schema Browsing — EXA_ALL_COLUMNS

Always query Exasol's system views for schema metadata — do not use `INFORMATION_SCHEMA` (it is limited in Exasol):

```sql
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    COLUMN_TYPE
FROM EXA_ALL_COLUMNS
WHERE TABLE_SCHEMA NOT IN ('SYS', 'EXA_STATISTICS')
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
```

Filter out `SYS` and `EXA_STATISTICS` — Monaco autocomplete must not surface system catalog tables.

## Exasol Query Syntax Notes

| SQL feature | Exasol syntax |
|---|---|
| Row limit | `FETCH FIRST n ROWS ONLY` (not `LIMIT n`) |
| Current timestamp | `CURRENT_TIMESTAMP` |
| String concat | `\|\|` operator |
| Boolean literals | `TRUE` / `FALSE` |
| Identifier quoting | double-quotes `"TableName"` |

When Monaco autocomplete suggests snippets for Exasol, use `FETCH FIRST` — not `LIMIT`.

## Docker — Container Configuration

Exasol runs under Rosetta on the Mac Mini M4 (no arm64 image). Key settings:

```yaml
exasol:
  image: exasol/docker-db:latest
  platform: linux/amd64       # Rosetta — do not remove
  ports:
    - "8563:8563"
    - "2580:2580"             # EXALoader port
  healthcheck:
    test: ["CMD", "exaplus", "-c", "localhost:8563", "-u", "sys", "-p", "exasol", "-sql", "SELECT 1;"]
    interval: 15s
    timeout: 10s
    retries: 12
    start_period: 120s        # Exasol is slow to start — do not reduce below 90s
```

Expose port `2580` if EXALoader bulk import is used — it binds a separate TCP port.

## DI Registration

```csharp
public static IServiceCollection AddExasolConnector(
    this IServiceCollection services,
    IConfiguration configuration)
{
    services.AddSingleton<ExasolAdoNetQueryService>(_ =>
        new ExasolAdoNetQueryService(configuration["ConnectionStrings:Exasol"]!));

    // JDBC path — register only if JDBC is configured
    if (!string.IsNullOrEmpty(configuration["ConnectionStrings:ExasolJdbc"]))
    {
        services.AddSingleton<ExasolJdbcQueryService>(_ =>
            new ExasolJdbcQueryService(configuration["ConnectionStrings:ExasolJdbc"]!));
    }

    services.AddSingleton<ExasolSchemaService>();
    services.AddSingleton<IDatabaseConnector, ExasolConnector>();
    return services;
}
```

## Enforcement

- This project must have **zero** `Microsoft.EntityFrameworkCore.*` references — Exasol has no EF provider; verify with `dotnet list package --include-transitive | grep EntityFramework`.
- JDBC `.jar` files must not be committed to git — add `drivers/*.jar` to `.gitignore`; download via script or CI step.
- All IKVM/JDBC calls are synchronous Java I/O — always wrap in `Task.Run(…, ct)`.
- ADO.NET path is the default for all standard `IDatabaseConnector` query execution — JDBC path is opt-in for bulk/specialized operations only.
- Exasol container `start_period` must not be reduced below 90 s — it consistently takes 60–120 s to initialize.
- Never expose `SYS` or `EXA_STATISTICS` schema tables in `GetSchemaAsync` output.
- Connection strings must come from `IConfiguration` — never hardcoded.
- The JDBC URL (`jdbc:exa:…`) and ADO.NET connection string are separate config keys — do not reuse one for both drivers.
