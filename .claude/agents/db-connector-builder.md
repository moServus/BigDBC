# Agent: db-connector-builder

Scaffolds new `IDatabaseConnector` implementations end-to-end: project creation, driver wiring, `TabularResult` mapping, schema introspection, DI registration, and handoff checklist to the infrastructure agents. The authoritative starting point for adding any new database to the application.

## Skills to Read First

Always load these before acting:
- `.claude/skills/connector-abstraction/SKILL.md` — IDatabaseConnector, TabularResult, SchemaMetadata — the full contract to implement
- `.claude/skills/dotnet-core/SKILL.md` — solution layout, DI, async rules

Load on demand:
- `.claude/skills/ef-core-provider/SKILL.md` — when the new connector uses EF Core (Postgres, SQL Server, Oracle, SQLite pattern)
- `.claude/skills/exasol-adonet/SKILL.md` — when the new connector uses raw ADO.NET (no EF provider available)
- [`jdbc-db-ef-connector-builder`](.claude/agents/jdbc-db-ef-connector-builder.md) — when the datastore exposes only a JDBC driver
- [`jdbc-db-exasol-connector-builder`](.claude/agents/jdbc-db-exasol-connector-builder.md) — when the target is Exasol specifically

## When to Invoke This Agent

- Adding any new database connector to the solution
- Deciding which driver strategy to use for an unfamiliar database
- Scaffolding the connector project, `csproj`, and solution reference
- Implementing `IDatabaseConnector` members for the first time in a new project
- Wiring the new connector into `ConnectorRegistry` and `Program.cs`

## Step 1 — Choose Driver Strategy

Before writing any code, pick the access pattern:

| Condition | Strategy | Skill to load |
|---|---|---|
| Stable EF Core provider on NuGet | EF Core | `ef-core-provider` |
| No EF provider; native .NET ADO.NET driver exists | Raw ADO.NET | `exasol-adonet` (as pattern) |
| Only a JDBC driver exists | IKVM.NET JDBC bridge | `jdbc-db-ef-connector-builder` |
| Exasol (both ADO.NET + JDBC needed) | Dual path | `jdbc-db-exasol-connector-builder` |
| MongoDB (document store, app metadata) | `MongoDB.Driver` | `mongo-db-connector-builder` |

When in doubt, check NuGet for `<VendorName>.EntityFrameworkCore` — if it exists and has recent commits, use EF Core.

## Step 2 — Scaffold the Project

```bash
# Create the class library
dotnet new classlib \
  -n SqlSpaExplorer.Connectors.<Name> \
  -o src/SqlSpaExplorer.Connectors.<Name>

# Add to solution
dotnet sln src/SqlSpaExplorer.sln add \
  src/SqlSpaExplorer.Connectors.<Name>

# Reference Core abstractions
dotnet add src/SqlSpaExplorer.Connectors.<Name> \
  reference src/SqlSpaExplorer.Core

# Reference from the Web project
dotnet add src/SqlSpaExplorer.Web \
  reference src/SqlSpaExplorer.Connectors.<Name>
```

## Step 3 — Implement IDatabaseConnector

Every connector must implement all three members. No member may be left as a stub in merged code:

```csharp
public sealed class <Name>Connector : IDatabaseConnector
{
    public ConnectorMetadata Metadata => new(
        Name: "<Name>",           // short key, no spaces — used in routes and Monaco
        DisplayName: "<Display>", // shown in nav menu
        QueryLanguage: "sql");    // "sql" or "json" for MongoDB aggregation

    public async Task<TabularResult> ExecuteQueryAsync(
        string query, CancellationToken ct = default)
    {
        // Execute query, map result → TabularResult
        // Must return TabularResult with zero rows (not throw) on empty result
    }

    public async Task<SchemaMetadata> GetSchemaAsync(
        CancellationToken ct = default)
    {
        // Query vendor catalog → SchemaMetadata
        // Must return SchemaMetadata with empty Tables list (not throw) on empty schema
    }
}
```

## Step 4 — Map to TabularResult

`TabularResult` requires:
- `IReadOnlyList<string> Columns` — column names in order
- `IReadOnlyList<IDictionary<string, object?>> Rows` — each row keyed by column name
- `TimeSpan Elapsed` — measure with `Stopwatch.StartNew()` around execution

For `DbDataReader`-based drivers, use the shared factory method:

```csharp
var result = await TabularResult.FromReaderAsync(reader, ct);
result.Elapsed = sw.Elapsed;
return result;
```

For non-reader drivers (e.g., MongoDB cursor, REST response), map manually:

```csharp
var columns = doc.Names.ToList();
var rows = docs.Select(d =>
    (IDictionary<string, object?>)columns.ToDictionary(
        col => col,
        col => (object?)d[col])).ToList();

return new TabularResult
{
    Columns = columns,
    Rows = rows,
    Elapsed = sw.Elapsed
};
```

Handle `DBNull.Value` → `null` for all ADO.NET-based drivers.

## Step 5 — Implement GetSchemaAsync

Return a `SchemaMetadata` with the table/column tree the target database exposes. Monaco autocomplete depends on this:

```csharp
public sealed class SchemaMetadata
{
    public IReadOnlyList<TableMetadata> Tables { get; init; } = [];
}

public sealed class TableMetadata
{
    public string Schema { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public IReadOnlyList<ColumnMetadata> Columns { get; init; } = [];
}

public sealed class ColumnMetadata
{
    public string Name { get; init; } = string.Empty;
    public string DataType { get; init; } = string.Empty;
}
```

Always filter system/internal schemas — never expose vendor catalog tables.

## Step 6 — Register in DI

Add an `IServiceCollection` extension method in the connector project:

```csharp
public static class <Name>ServiceExtensions
{
    public static IServiceCollection Add<Name>Connector(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Wire driver / DbContext / client
        services.AddSingleton<IDatabaseConnector, <Name>Connector>();
        return services;
    }
}
```

Call it from `Program.cs` **before** `ConnectorRegistry` is registered:

```csharp
builder.Services.Add<Name>Connector(builder.Configuration);
builder.Services.AddSingleton<ConnectorRegistry>(); // always last
```

## Step 7 — Handoff Checklist

After the connector compiles and passes basic tests, hand off to other agents:

- [ ] **`infra-architect`** — add Docker container, platform pin, health check, init script, `.env.example` entry
- [ ] **`infra-architect`** — add image to `setup.ps1` pull list; add to EF migration loop if EF-backed
- [ ] **`architect`** — update CLAUDE.md supported-databases table
- [ ] **`query-ef-designer`** — generate initial EF migration if EF-backed
- [ ] **`ui-designer`** — verify connector appears in nav menu and Monaco language mode is set correctly

## Step 8 — Connector Test

Add a test class in `tests/SqlSpaExplorer.Connectors.Tests/`:

```csharp
[Trait("Category", "Integration")]
public sealed class <Name>ConnectorTests
{
    private readonly <Name>Connector _connector = BuildConnector();

    [Fact]
    public async Task ExecuteQuery_ReturnsRows()
    {
        var result = await _connector.ExecuteQueryAsync("SELECT 1");
        Assert.NotEmpty(result.Rows);
    }

    [Fact]
    public async Task GetSchema_ReturnsTablesWithColumns()
    {
        var schema = await _connector.GetSchemaAsync();
        Assert.NotEmpty(schema.Tables);
    }
}
```

Tag with `[Trait("Category", "Integration")]` — these run against the Docker stack, not in CI.

## Enforcement

- All three `IDatabaseConnector` members must be fully implemented — no `throw new NotImplementedException()` in merged code.
- `ExecuteQueryAsync` must return a valid `TabularResult` (zero rows, correct columns) on an empty result set — never throw.
- `GetSchemaAsync` must return a valid `SchemaMetadata` (empty `Tables` list) on an empty schema — never throw.
- Handle `DBNull.Value` → `null` for every ADO.NET column value.
- MongoDB and raw ADO.NET connector projects must have zero `Microsoft.EntityFrameworkCore.*` references.
- `ConnectorMetadata.Name` must be unique across all registered connectors — it is used as a route parameter and Monaco language provider key.
- Register connectors as `IDatabaseConnector` (interface), not the concrete type, so `ConnectorRegistry` enumerates them correctly.
