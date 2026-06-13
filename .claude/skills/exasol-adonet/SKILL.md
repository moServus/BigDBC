# Skill: exasol-adonet

Covers the Exasol connector, which uses raw ADO.NET via `EXADataProvider`. No EF Core — do not add any `Microsoft.EntityFrameworkCore.*` reference to this project.

## Package

```xml
<PackageReference Include="Exasol.EXADataProvider" Version="..." />
```

Check NuGet for the latest compatible version. There is no official arm64 build; the package runs under Rosetta on Apple Silicon.

## Connection Pattern

```csharp
using Exasol.EXADataProvider;

await using var conn = new EXAConnection(_options.ConnectionString);
await conn.OpenAsync(ct);
await using var cmd = conn.CreateCommand();
cmd.CommandText = query;
await using var reader = await cmd.ExecuteReaderAsync(ct);
```

Map `IDataReader` → `TabularResult` the same way all ADO.NET connectors do (see `connector-abstraction` skill).

## Schema Query

Exasol exposes schema information through `EXA_ALL_TABLES` and `EXA_ALL_COLUMNS` system tables:

```sql
SELECT TABLE_SCHEMA, TABLE_NAME FROM EXA_ALL_TABLES ORDER BY 1, 2;
SELECT COLUMN_TABLE, COLUMN_NAME, COLUMN_TYPE FROM EXA_ALL_COLUMNS ORDER BY 1, 2;
```

## Docker / Rosetta Note

The Exasol community Docker image (`exasol/docker-db`) has no arm64 native build. In `docker-compose.yml` it must be pinned with `platform: linux/amd64` to force Rosetta emulation:

```yaml
exasol:
  image: exasol/docker-db:latest
  platform: linux/amd64
```

Startup is slow (60–120 s). Integration tests that target Exasol must wait for the health check to pass before connecting. Add a `healthcheck` in compose and use `depends_on: condition: service_healthy` in the app service.

## No EF Enforcement

If a PR accidentally adds an EF package transitive dep to this project, catch it with:

```bash
dotnet list src/SqlSpaExplorer.Connectors.Exasol package --include-transitive | grep EntityFramework
```

Should return nothing.
