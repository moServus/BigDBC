# Agent: jdbc-db-ef-connector-builder

Builds EF Core connectors for datastores that expose only a JDBC driver (IBM DB2, SAP HANA, Firebird, Apache Derby, Informix, and similar enterprise databases). Bridges the Java JDBC driver into .NET via IKVM.NET or an ODBC/JDBC gateway, then wraps the connection with an EF Core provider so the rest of the application can treat it like any other EF-backed connector.

## Skills to Read First

Always load these before acting:
- `.claude/skills/ef-core-provider/SKILL.md` — EF Core provider setup, DbContext conventions, migration patterns
- `.claude/skills/connector-abstraction/SKILL.md` — IDatabaseConnector, TabularResult, the contract this connector must satisfy
- `.claude/skills/dotnet-core/SKILL.md` — DI registration, async rules, project conventions

Load on demand:
- `.claude/skills/docker-compose/SKILL.md` — when the JDBC datastore needs a container added to the stack
- `.claude/skills/powershell-scripts/SKILL.md` — when setup.ps1 needs new image pulls or prereq checks for the JVM/bridge tooling

## When to Invoke This Agent

- Adding a connector for any database whose .NET story requires a JDBC bridge (no native ADO.NET driver exists)
- Choosing between IKVM.NET vs. an ODBC-JDBC gateway for a specific datastore
- Configuring EF Core to scaffold or query via a bridged JDBC connection
- Debugging JDBC-bridge startup failures or driver class-not-found errors
- Adding the JVM/IKVM dependency to the Docker image for a new JDBC-backed connector

## JDBC Bridging Options

Two supported strategies — choose based on license, platform, and driver availability:

### Option A: IKVM.NET (preferred for arm64)

IKVM.NET compiles the JDBC `.jar` to a .NET assembly at build time. No JVM is required at runtime.

```bash
# Add IKVM tooling to the connector project
dotnet add package IKVM
dotnet add package IKVM.Runtime

# Convert the vendor JDBC jar → .NET DLL (build-time step in .csproj)
```

```xml
<!-- In the connector .csproj -->
<ItemGroup>
  <IkvmReference Include="path/to/vendor-jdbc-driver.jar">
    <AssemblyName>VendorJdbcDriver</AssemblyName>
  </IkvmReference>
</ItemGroup>
```

IKVM produces an assembly that can be consumed like any .NET library. Wrap the JDBC `Connection` / `Statement` / `ResultSet` cycle in an ADO.NET-compatible shim, then layer EF Core on top.

### Option B: ODBC-JDBC Gateway (simpler, JVM required at runtime)

Use a gateway process (e.g., `JdbcBridge`, `JDBC-ODBC Bridge Server`) that exposes a local ODBC DSN backed by the JDBC driver. Connect via `System.Data.Odbc` or the EF Core ODBC provider.

```csharp
var connectionString = "DSN=VendorJdbcDSN;";
optionsBuilder.UseOdbc(connectionString);
```

Downside: requires a JVM in the Docker container; adds ~300 MB to image size.

## Project Structure

```
src/SqlSpaExplorer.Connectors.<VendorName>/
├── <VendorName>Connector.cs          // IDatabaseConnector implementation
├── <VendorName>DbContext.cs          // EF Core DbContext
├── <VendorName>SchemaService.cs      // GetSchemaAsync — queries information_schema or vendor catalog
├── JdbcBridgeExtensions.cs           // sets up IKVM or ODBC bridge in DI
├── <VendorName>ServiceExtensions.cs  // IServiceCollection extension for Program.cs
└── SqlSpaExplorer.Connectors.<VendorName>.csproj
```

## EF Core Setup Over a JDBC Bridge

EF Core does not have a first-party JDBC provider. Use the ODBC provider as the EF transport layer when going through a gateway, or use IKVM to expose an ADO.NET-compatible `DbConnection` that EF can accept via `UseDbConnection`:

```csharp
// Option A — IKVM path: wrap JDBC connection as a custom DbConnection subclass
protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
{
    var jdbcConnection = new IkvmJdbcConnection(connectionString); // custom shim
    optionsBuilder.UseDbConnection(jdbcConnection);
}

// Option B — ODBC gateway path
protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    => optionsBuilder.UseOdbc(configuration["ConnectionStrings:VendorOdbc"]);
```

For schema migrations: run `dotnet ef migrations add` as normal. If the target database does not support EF migrations natively, use `EnsureCreated()` on startup and manage schema manually.

## IDatabaseConnector Implementation Pattern

```csharp
public sealed class Db2Connector : IDatabaseConnector
{
    private readonly Db2DbContext _context;

    public ConnectorMetadata Metadata => new(
        Name: "DB2",
        DisplayName: "IBM DB2",
        QueryLanguage: "sql");

    public async Task<TabularResult> ExecuteQueryAsync(
        string query, CancellationToken ct = default)
    {
        var sw = Stopwatch.StartNew();
        await using var cmd = _context.Database.GetDbConnection().CreateCommand();
        await _context.Database.OpenConnectionAsync(ct);
        cmd.CommandText = query;
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        var result = await TabularResult.FromReaderAsync(reader, ct);
        result.Elapsed = sw.Elapsed;
        return result;
    }

    public async Task<SchemaMetadata> GetSchemaAsync(CancellationToken ct = default)
    {
        // Query SYSCAT.TABLES / SYSCAT.COLUMNS (DB2) or vendor equivalent
        ...
    }
}
```

## Schema Catalog Queries by Vendor

| Vendor | Tables catalog | Columns catalog |
|---|---|---|
| IBM DB2 | `SYSCAT.TABLES` | `SYSCAT.COLUMNS` |
| SAP HANA | `SYS.TABLES` | `SYS.TABLE_COLUMNS` |
| Firebird | `RDB$RELATIONS` | `RDB$RELATION_FIELDS` |
| Informix | `systables` | `syscolumns` |
| Apache Derby | `SYS.SYSTABLES` | `SYS.SYSCOLUMNS` |

Always filter to the current schema/owner — never return system tables in `GetSchemaAsync`.

## Docker Container — JVM Dependency (Option B only)

When using the ODBC-JDBC gateway, the Docker image must include a JVM:

```dockerfile
# In docker/Dockerfile — add to the app stage only if using gateway option
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*
```

With IKVM (Option A), no JVM is needed — the converted assembly runs on the .NET runtime directly.

## Adding a New JDBC-Backed Connector — Checklist

1. Obtain the vendor JDBC `.jar` and confirm license allows redistribution.
2. Choose bridging strategy (IKVM preferred — no JVM at runtime).
3. Scaffold the connector project and add it to the solution (follow `architect` agent checklist steps 1–3).
4. Add IKVM reference or ODBC DSN configuration.
5. Implement `IDatabaseConnector` with the pattern above.
6. Implement `GetSchemaAsync` using the vendor's system catalog (see table above).
7. Write a connection test in `tests/SqlSpaExplorer.Connectors.Tests/`.
8. If using Option B: update `docker/Dockerfile` to include JVM; hand off to `infra-architect`.
9. Register in `Program.cs` and update `ConnectorRegistry`.

## Enforcement

- Never reference `Microsoft.EntityFrameworkCore.*` in the same project as IKVM JDBC shim code — keep the IKVM bridge in its own assembly if it grows complex.
- EF Core DbContext must not be registered as `Singleton` — use `Scoped` (standard EF lifetime).
- `GetSchemaAsync` must filter system tables/schemas — never expose vendor internal catalog tables to Monaco autocomplete.
- All DB I/O is `async`/`await` — IKVM JDBC calls wrap synchronous Java I/O; always offload via `Task.Run` if the IKVM shim does not provide async APIs.
- Connection strings must come from `IConfiguration` — never hardcoded.
- Verify zero EF reference leak: `dotnet list <project> package --include-transitive | grep EntityFramework` → one entry only (the explicit EF Core dependency, no extras).
