# Skill: connector-abstraction

Covers `IDatabaseConnector`, `TabularResult`, `ConnectorMetadata`, and `ConnectorRegistry` in `SqlSpaExplorer.Core`.

## IDatabaseConnector

```csharp
public interface IDatabaseConnector
{
    ConnectorMetadata Metadata { get; }
    Task<TabularResult> ExecuteQueryAsync(string query, CancellationToken ct = default);
    Task<SchemaMetadata> GetSchemaAsync(CancellationToken ct = default);
}
```

- `Metadata` — name, icon, display color; read by the UI nav menu.
- `ExecuteQueryAsync` — runs an arbitrary query string; must return `TabularResult` (never throw on empty result sets, return zero rows instead).
- `GetSchemaAsync` — returns table/column metadata used to populate Monaco autocomplete.

## TabularResult

```csharp
public class TabularResult
{
    public IReadOnlyList<string> Columns { get; init; }
    public IReadOnlyList<IReadOnlyList<object?>> Rows { get; init; }
    public TimeSpan Elapsed { get; init; }
}
```

The UI's `ResultGrid.razor` binds directly to this shape via `RadzenDataGrid`. Column order in `Columns` defines grid column order. Null cells are valid.

## SchemaMetadata

```csharp
public class SchemaMetadata
{
    public IReadOnlyList<TableInfo> Tables { get; init; }
}

public class TableInfo
{
    public string Name { get; init; }
    public IReadOnlyList<ColumnInfo> Columns { get; init; }
}
```

Even for non-SQL databases (MongoDB, Exasol) implement this — Monaco autocomplete depends on it.

## ConnectorRegistry

Singleton; injected wherever the UI needs to enumerate or look up connectors:

```csharp
public class ConnectorRegistry
{
    public IReadOnlyList<IDatabaseConnector> All { get; }
    public IDatabaseConnector GetByName(string name);
}
```

It is populated from the DI container — each connector registers itself, and the registry receives `IEnumerable<IDatabaseConnector>` via constructor injection.

## Implementing a New Connector — Checklist

1. Create connector project (see `dotnet-core` skill).
2. Implement `IDatabaseConnector`.
3. Map native results → `TabularResult` (handle `DBNull`, `BsonDocument`, etc.).
4. Implement `GetSchemaAsync` to surface table/column names.
5. Register via `IServiceCollection` extension method.
6. Call extension method from `Program.cs` in Web project.
7. Update `docker-compose.yml`, `.env.example`, and `setup.ps1` image list.
