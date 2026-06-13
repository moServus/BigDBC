<!-- V1: Blazor Example + Docker Infrastructure -->
# Architecture

SQL SPA Explorer uses a single `IDatabaseConnector` abstraction to normalise access across all supported databases. Each connector maps its native result shape into `TabularResult`, which `RadzenDataGrid` renders identically regardless of source.

## Connector Contract

```csharp
public interface IDatabaseConnector
{
    ConnectorMetadata Metadata { get; }
    Task<TabularResult> ExecuteQueryAsync(string query, CancellationToken ct = default);
    Task<SchemaMetadata> GetSchemaAsync(CancellationToken ct = default);
    Task<bool> TestConnectionAsync(CancellationToken ct = default);
}
```

## Project Layout

| Project | Role |
|---|---|
| `SqlSpaExplorer.Core` | `IDatabaseConnector`, `TabularResult`, `SchemaMetadata`, `ConnectorRegistry` |
| `SqlSpaExplorer.Web` | Blazor UI, Monaco SQL editor, Radzen result grid |
| `SqlSpaExplorer.Connectors.Postgres` | EF Core — PostgreSQL |
| `SqlSpaExplorer.Connectors.SqlServer` | EF Core — SQL Server |
| `SqlSpaExplorer.Connectors.Oracle` | EF Core — Oracle |
| `SqlSpaExplorer.Connectors.Sqlite` | EF Core — SQLite |
| `SqlSpaExplorer.Connectors.Mongo` | `MongoDB.Driver` (no EF) |
| `SqlSpaExplorer.Connectors.Exasol` | Raw ADO.NET `EXADataProvider` (no EF) |

## Key Rules

- MongoDB and Exasol must **never** reference `Microsoft.EntityFrameworkCore.*`.
- Every connector must implement `GetSchemaAsync` to power Monaco autocomplete, even for non-SQL query languages.
- All connector I/O is `async`/`await` — no blocking DB calls.
