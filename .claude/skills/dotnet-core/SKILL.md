# Skill: dotnet-core

General .NET 8 conventions for the SqlSpaExplorer solution.

## Solution Layout

- `src/SqlSpaExplorer.sln` — solution root
- `SqlSpaExplorer.Core` — abstractions and shared models; no UI, no DB drivers
- `SqlSpaExplorer.Web` — Blazor host; references Core and all connector projects
- `SqlSpaExplorer.Connectors.<Provider>` — one project per database (see CLAUDE.md for the full list)
- `tests/` — three test projects (Core unit, Connectors integration, Web bUnit)

## Dependency Injection

Connectors register themselves via extension methods on `IServiceCollection`. The Web project calls each in `Program.cs`:

```csharp
builder.Services.AddPostgresConnector(builder.Configuration);
builder.Services.AddMongoConnector(builder.Configuration);
// …one call per connector
```

`ConnectorRegistry` is a singleton that holds the resolved `IDatabaseConnector` list; register it after all connectors:

```csharp
builder.Services.AddSingleton<ConnectorRegistry>();
```

## Configuration

Connection strings live in `appsettings.json` / `appsettings.Development.json` under a `Connectors` section, keyed by connector name. Each connector's extension method binds its own `Options` class via `IOptions<T>`.

## Async Rules

- All public connector methods are `async Task<T>` — never `Task.Result` or `.Wait()`.
- Pass `CancellationToken` through to every DB call.

## Adding a New Connector Project

```bash
dotnet new classlib -n SqlSpaExplorer.Connectors.<Name> -o src/SqlSpaExplorer.Connectors.<Name>
dotnet sln src/SqlSpaExplorer.sln add src/SqlSpaExplorer.Connectors.<Name>
dotnet add src/SqlSpaExplorer.Connectors.<Name> reference src/SqlSpaExplorer.Core
dotnet add src/SqlSpaExplorer.Web reference src/SqlSpaExplorer.Connectors.<Name>
```

Then implement `IDatabaseConnector` and wire up DI (see `connector-abstraction` skill).
