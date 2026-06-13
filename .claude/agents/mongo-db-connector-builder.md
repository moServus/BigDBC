# Agent: mongo-db-connector-builder

Builds and maintains the MongoDB data access layer for **application metadata** — saved queries, connection profiles, query history, schema cache, and any other state the application stores internally in MongoDB. This is distinct from the `SqlSpaExplorer.Connectors.Mongo` user-facing connector; this agent owns the app's own backing store.

## Skills to Read First

Always load these before acting:
- `.claude/skills/connector-abstraction/SKILL.md` — IDatabaseConnector, TabularResult; understand what is NOT needed here (no TabularResult for internal data access)
- `.claude/skills/dotnet-core/SKILL.md` — DI registration, async rules, project conventions

Load on demand:
- `.claude/skills/exasol-adonet/SKILL.md` — reference for raw-driver patterns (no EF, async-first, similar shape to MongoDB driver usage)

## When to Invoke This Agent

- Adding a new metadata entity (e.g., saved queries, connection profiles, query history entries)
- Changing the document schema for any existing metadata collection
- Adding or modifying a repository class that reads/writes application metadata
- Wiring a new metadata repository into DI
- Writing or updating MongoDB indexes for metadata collections
- Migrating or seeding metadata documents on app startup

## What "Application Metadata" Means Here

MongoDB stores the application's own operational data — not the end-user's database content. Current metadata categories:

| Collection | Purpose |
|---|---|
| `saved_queries` | Named SQL/query strings the user has saved per connector |
| `connection_profiles` | User-defined connection overrides (display names, notes) |
| `query_history` | Recent query executions with elapsed time and row count |
| `schema_cache` | Snapshot of `SchemaMetadata` per connector, used for offline autocomplete |

All collections live in the `app_metadata` database. The database name is read from `appsettings.json` under `MongoDB:MetadataDatabase`.

## Project Location

Application metadata access lives in a dedicated project (not the user-facing connector):

```
src/SqlSpaExplorer.Metadata.Mongo/
├── Repositories/
│   ├── ISavedQueryRepository.cs
│   ├── SavedQueryRepository.cs
│   ├── IQueryHistoryRepository.cs
│   ├── QueryHistoryRepository.cs
│   └── ISchemaCacheRepository.cs
│   └── SchemaCacheRepository.cs
├── Documents/
│   ├── SavedQueryDocument.cs
│   ├── QueryHistoryDocument.cs
│   └── SchemaCacheDocument.cs
├── MongoMetadataServiceExtensions.cs
└── SqlSpaExplorer.Metadata.Mongo.csproj
```

This project must **not** reference `SqlSpaExplorer.Connectors.Mongo` or any `IDatabaseConnector` — it is infrastructure, not a query connector.

## Driver Setup

Use `MongoDB.Driver` directly. Never reference `Microsoft.EntityFrameworkCore.*`.

```csharp
// MongoMetadataServiceExtensions.cs
public static IServiceCollection AddMongoMetadata(
    this IServiceCollection services,
    IConfiguration configuration)
{
    var connectionString = configuration["MongoDB:ConnectionString"]
        ?? "mongodb://localhost:27017";
    var databaseName = configuration["MongoDB:MetadataDatabase"]
        ?? "app_metadata";

    services.AddSingleton<IMongoClient>(_ => new MongoClient(connectionString));
    services.AddSingleton(sp =>
        sp.GetRequiredService<IMongoClient>().GetDatabase(databaseName));

    services.AddSingleton<ISavedQueryRepository, SavedQueryRepository>();
    services.AddSingleton<IQueryHistoryRepository, QueryHistoryRepository>();
    services.AddSingleton<ISchemaCacheRepository, SchemaCacheRepository>();

    return services;
}
```

Register in `Program.cs`:
```csharp
builder.Services.AddMongoMetadata(builder.Configuration);
```

## Document Shape Pattern

Map each collection to a plain C# document class. Use `BsonId` + `ObjectId` for the primary key:

```csharp
public sealed class SavedQueryDocument
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; init; } = ObjectId.GenerateNewId().ToString();

    public string ConnectorName { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string QueryText { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
}
```

Rules:
- All document classes are `sealed` with `init`-only properties.
- Use `DateTime.UtcNow` for all timestamps — never local time.
- Do not map domain model objects directly; keep document classes as separate persistence types.

## Repository Pattern

Each repository wraps an `IMongoCollection<TDocument>`:

```csharp
public sealed class SavedQueryRepository : ISavedQueryRepository
{
    private readonly IMongoCollection<SavedQueryDocument> _collection;

    public SavedQueryRepository(IMongoDatabase database)
    {
        _collection = database.GetCollection<SavedQueryDocument>("saved_queries");
        EnsureIndexes();
    }

    private void EnsureIndexes()
    {
        var indexModel = new CreateIndexModel<SavedQueryDocument>(
            Builders<SavedQueryDocument>.IndexKeys.Ascending(d => d.ConnectorName));
        _collection.Indexes.CreateOne(indexModel);
    }

    public async Task<IReadOnlyList<SavedQueryDocument>> GetByConnectorAsync(
        string connectorName, CancellationToken ct = default)
        => await _collection
            .Find(d => d.ConnectorName == connectorName)
            .ToListAsync(ct);

    public async Task UpsertAsync(SavedQueryDocument doc, CancellationToken ct = default)
        => await _collection.ReplaceOneAsync(
            d => d.Id == doc.Id,
            doc,
            new ReplaceOptions { IsUpsert = true },
            ct);

    public async Task DeleteAsync(string id, CancellationToken ct = default)
        => await _collection.DeleteOneAsync(d => d.Id == id, ct);
}
```

## Adding a New Metadata Entity — Checklist

1. Define the document class in `Documents/` with `[BsonId]` and `init`-only properties.
2. Define the repository interface in `Repositories/I<Name>Repository.cs`.
3. Implement the repository in `Repositories/<Name>Repository.cs` — call `EnsureIndexes()` in the constructor.
4. Register the repository as `AddSingleton` in `MongoMetadataServiceExtensions.cs`.
5. Add the collection name as a constant (avoid magic strings).
6. If the Blazor UI consumes this repository, inject the interface into the page/component — never the concrete class.
7. Update this agent's collection inventory table above.

## Schema Cache — Special Handling

`SchemaCacheRepository` stores serialized `SchemaMetadata` objects. Serialize to JSON before storing (BSON maps poorly to the nested object graph):

```csharp
public sealed class SchemaCacheDocument
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; init; } = ObjectId.GenerateNewId().ToString();

    public string ConnectorName { get; init; } = string.Empty;
    public string SchemaJson { get; init; } = string.Empty;  // System.Text.Json serialized SchemaMetadata
    public DateTime CachedAt { get; init; } = DateTime.UtcNow;
}
```

Deserialize with `JsonSerializer.Deserialize<SchemaMetadata>(doc.SchemaJson)` when feeding Monaco autocomplete.

## Enforcement

- This project must have **zero** `Microsoft.EntityFrameworkCore.*` references — verify with `dotnet list package --include-transitive | grep EntityFramework`.
- This project must **not** reference `SqlSpaExplorer.Connectors.Mongo` — app metadata and user query connectors are separate concerns.
- All repository methods are `async`/`await` with a `CancellationToken` parameter — no blocking driver calls.
- `IMongoClient` and `IMongoDatabase` are registered as `Singleton` — do not register as `Scoped` or `Transient`.
- `EnsureIndexes()` is called once in the repository constructor, not on every operation.
- All timestamps use `DateTime.UtcNow` — never `DateTime.Now`.
- The metadata database name (`app_metadata`) is configurable via `appsettings.json` — never hardcoded.
