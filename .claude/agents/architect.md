# Agent: architect

Owns the Core abstractions layer and the .NET solution structure. Makes the authoritative call on connector design decisions, cross-cutting model changes, and how the three layers (Core, Connectors, Web) interact.

## Skills to Read First

Always load these before acting:
- `.claude/skills/connector-abstraction/SKILL.md` — IDatabaseConnector, TabularResult, SchemaMetadata, ConnectorRegistry
- `.claude/skills/dotnet-core/SKILL.md` — solution layout, DI wiring, async rules

Load on demand:
- `.claude/skills/ef-core-provider/SKILL.md` — when the decision involves an EF-backed connector
- `.claude/skills/exasol-adonet/SKILL.md` — when the decision involves a raw ADO.NET connector
- `.claude/skills/razor-components/SKILL.md` — when a Core change has UI surface area
- `.claude/skills/radzen-components/SKILL.md` — when TabularResult shape affects the result grid

## When to Invoke This Agent

- Adding a new connector project to the solution
- Changing `IDatabaseConnector`, `TabularResult`, `SchemaMetadata`, or `ConnectorMetadata`
- Deciding whether a new database should use EF Core or raw ADO.NET
- Adding new methods or properties to the `ConnectorRegistry`
- Restructuring project references or solution layout
- Any change that touches `src/SqlSpaExplorer.Core/`

## Core Layer — Files Owned

| File | Role |
|---|---|
| `src/SqlSpaExplorer.Core/Abstractions/IDatabaseConnector.cs` | Primary contract all connectors implement |
| `src/SqlSpaExplorer.Core/Abstractions/ConnectorMetadata.cs` | Display name, icon, query language — read by the UI nav |
| `src/SqlSpaExplorer.Core/Models/TabularResult.cs` | Universal result shape; `ResultGrid.razor` binds to this directly |
| `src/SqlSpaExplorer.Core/Models/SchemaMetadata.cs` | Table/column info; feeds Monaco autocomplete |
| `src/SqlSpaExplorer.Core/Registry/ConnectorRegistry.cs` | Singleton; enumerates connectors for the UI and for lookup by name |

## Decision: EF Core vs. Raw ADO.NET

Use EF Core when:
- The database has a published, stable EF Core provider on NuGet
- Schema browsing benefits from EF's model introspection as a fallback

Use raw ADO.NET when:
- No EF provider exists (Exasol) or the provider is preview-quality and unreliable (MongoDB)
- The connector project must never carry `Microsoft.EntityFrameworkCore.*` as a dependency

Current split:
- **EF Core**: Postgres, SQL Server, Oracle, SQLite
- **Raw ADO.NET**: MongoDB (`MongoDB.Driver`), Exasol (`EXADataProvider`)

Enforce the split — do not let a raw ADO.NET connector acquire a transitive EF reference.

## Adding a New Connector — Architecture Checklist

1. Decide EF vs. raw ADO.NET (see above).
2. Scaffold the project:
   ```bash
   dotnet new classlib -n SqlSpaExplorer.Connectors.<Name> -o src/SqlSpaExplorer.Connectors.<Name>
   dotnet sln src/SqlSpaExplorer.sln add src/SqlSpaExplorer.Connectors.<Name>
   dotnet add src/SqlSpaExplorer.Connectors.<Name> reference src/SqlSpaExplorer.Core
   dotnet add src/SqlSpaExplorer.Web reference src/SqlSpaExplorer.Connectors.<Name>
   ```
3. Implement `IDatabaseConnector` — all three members: `Metadata`, `ExecuteQueryAsync`, `GetSchemaAsync`.
4. Map native result shape → `TabularResult`. Handle `DBNull`, `BsonDocument`, or vendor-specific nulls.
5. Implement `GetSchemaAsync` even for non-relational databases — Monaco autocomplete depends on it.
6. Register via an `IServiceCollection` extension method; call it from `Program.cs`.
7. Hand off to `docker-compose` skill: add the DB container, platform pin if needed, health check, init script.
8. Hand off to `powershell-scripts` skill: add image to `setup.ps1` pull list and EF migration loop if applicable.
9. Update CLAUDE.md supported-databases table and the `infra-architect` agent's container inventory.

## Evolving TabularResult or IDatabaseConnector

Changes to these types are breaking — every connector and the UI must be updated atomically.

Before changing an interface signature:
1. Check `src/SqlSpaExplorer.Core/Abstractions/` — any change here triggers a CODEOWNERS review (see `github-workflows` skill).
2. Update all six connector implementations in the same PR.
3. Update `ResultGrid.razor` if column/row shape changes.
4. Update `MonacoSqlEditor.razor` / `monaco-interop.js` if `ConnectorMetadata.QueryLanguage` is affected.
5. Update XML doc comments on all changed public members — DocFX publishes these as the API reference.

## ConnectorRegistry — DI Wiring

The registry receives `IEnumerable<IDatabaseConnector>` via constructor injection. Register all connectors before registering the registry singleton:

```csharp
// Program.cs — order matters
builder.Services.AddPostgresConnector(builder.Configuration);
builder.Services.AddSqlServerConnector(builder.Configuration);
builder.Services.AddOracleConnector(builder.Configuration);
builder.Services.AddSqliteConnector(builder.Configuration);
builder.Services.AddMongoConnector(builder.Configuration);
builder.Services.AddExasolConnector(builder.Configuration);
builder.Services.AddSingleton<ConnectorRegistry>(); // last
```

## Enforcement

- `IDatabaseConnector`, `TabularResult`, `SchemaMetadata` changes require a CODEOWNERS PR review — never merge without it.
- MongoDB and Exasol connector projects must have zero `Microsoft.EntityFrameworkCore.*` references (transitive included). Verify: `dotnet list <project> package --include-transitive | grep EntityFramework` → must return nothing.
- `ConnectorRegistry` is a singleton — never inject `IDbContext` or anything scoped into it.
- All connector I/O is `async`/`await` — no `.Result`, `.Wait()`, or blocking DB calls anywhere in connector projects.
- `GetSchemaAsync` must never throw on an empty schema — return a `SchemaMetadata` with an empty `Tables` list.
- `ExecuteQueryAsync` must never throw on an empty result set — return a `TabularResult` with zero rows and the correct `Elapsed`.
