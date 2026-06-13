# Agent: ui-designer

Builds and maintains the query-facing UI: the Monaco SQL editor, the result grid, the query explorer page, and the connector selector. Owns the full interaction flow from the user typing SQL to the rendered result — component structure, state management, error display, and JS interop wiring.

## Skills to Read First

Always load these before acting:
- `.claude/skills/razor-components/SKILL.md` — Blazor component lifecycle, `@code` blocks, `EventCallback`, DI injection
- `.claude/skills/radzen-components/SKILL.md` — RadzenDataGrid dynamic columns, dialogs, notifications
- `.claude/skills/monaco-editor/SKILL.md` — JS interop, language modes, schema-driven autocomplete

Load on demand:
- `.claude/skills/connector-abstraction/SKILL.md` — `TabularResult`, `SchemaMetadata`, `ConnectorRegistry` — what the UI receives
- `.claude/skills/dotnet-core/SKILL.md` — DI and `@inject` patterns

## When to Invoke This Agent

- Adding or modifying `QueryExplorer.razor` (the main query page)
- Changing `MonacoSqlEditor.razor` or `monaco-interop.js`
- Changing `ResultGrid.razor` (column rendering, null handling, paging)
- Adding a connector selector, database picker, or schema tree in the UI
- Implementing keyboard shortcuts, toolbar buttons, or execution state (loading spinner, cancel)
- Changing how `SchemaMetadata` is fed into Monaco autocomplete providers
- Adding error/warning UI for query failures, connection drops, or timeout

## Component Map

| Component | Path | Responsibility |
|---|---|---|
| `QueryExplorer.razor` | `Components/Pages/QueryExplorer.razor` | Page root — owns connector selection, query state, result wiring |
| `MonacoSqlEditor.razor` | `Components/QueryEditor/MonacoSqlEditor.razor` | Monaco wrapper — JS interop, language mode, schema feed |
| `ResultGrid.razor` | `Components/QueryEditor/ResultGrid.razor` | Renders `TabularResult` via `RadzenDataGrid` |
| `MainLayout.razor` | `Components/Shared/MainLayout.razor` | App shell — sidebar, top bar |
| `NavMenu.razor` | `Components/Shared/NavMenu.razor` | Connector navigation list |
| `monaco-interop.js` | `wwwroot/js/monaco-interop.js` | JS side of editor interop |

## QueryExplorer — Page State Model

The page owns:
- Selected connector (`IDatabaseConnector`) — drives Monaco language mode and schema
- Current query text — two-way bound to `MonacoSqlEditor`
- Execution state: idle / running / error
- `TabularResult` — passed to `ResultGrid` after successful execution

```razor
@inject ConnectorRegistry Registry
@inject RadzenNotificationService NotificationService

@code {
    private IDatabaseConnector? _connector;
    private string _query = string.Empty;
    private TabularResult? _result;
    private bool _running;

    private async Task ExecuteQueryAsync()
    {
        if (_connector is null || string.IsNullOrWhiteSpace(_query)) return;
        _running = true;
        _result = null;
        try
        {
            _result = await _connector.ExecuteQueryAsync(_query);
            NotificationService.Notify(NotificationSeverity.Success,
                "Done", $"{_result.Rows.Count} rows · {_result.Elapsed.TotalMilliseconds:F0} ms", 3000);
        }
        catch (Exception ex)
        {
            NotificationService.Notify(NotificationSeverity.Error, "Query failed", ex.Message, 0);
        }
        finally
        {
            _running = false;
        }
    }
}
```

## Monaco Editor — Blazor Interop

`MonacoSqlEditor.razor` calls into `monaco-interop.js` via `IJSRuntime`. Key interop methods:

```csharp
// Initialize editor in a div
await JS.InvokeVoidAsync("monaco.initEditor", _editorRef, initialValue, languageMode);

// Get current editor value
var query = await JS.InvokeAsync<string>("monaco.getValue", _editorRef);

// Set schema for autocomplete
await JS.InvokeVoidAsync("monaco.setSchema", connectorName, schemaJson);
```

Language mode maps from `ConnectorMetadata.QueryLanguage`:
- `"sql"` → Monaco `sql` language
- `"json"` → Monaco `json` language (for MongoDB aggregation)

When the user switches connectors, call `monaco.setSchema` with the new connector's `SchemaMetadata` serialized to JSON. Feed it on `OnAfterRenderAsync` after the connector change — not in `OnInitializedAsync`.

## Schema Feed Timing

Schema must be loaded asynchronously after connector selection and pushed to Monaco before the user starts typing:

```csharp
private async Task OnConnectorChangedAsync(IDatabaseConnector connector)
{
    _connector = connector;
    var schema = await connector.GetSchemaAsync();
    var schemaJson = JsonSerializer.Serialize(schema);
    await JS.InvokeVoidAsync("monaco.setSchema", connector.Metadata.Name, schemaJson);
}
```

Cache `SchemaMetadata` per connector in the page — do not call `GetSchemaAsync` on every keystroke.

## ResultGrid — Null and Type Handling

`TabularResult.Rows` contains `IDictionary<string, object?>`. Render nulls explicitly:

```razor
<Template Context="row">
    @{
        var val = row.TryGetValue(col, out var v) ? v : null;
        var display = val switch
        {
            null      => "(null)",
            byte[] b  => $"<binary {b.Length} bytes>",
            _         => val.ToString() ?? string.Empty
        };
    }
    <span class="@(val is null ? "cell-null" : string.Empty)">@display</span>
</Template>
```

Add a `cell-null` CSS class in `app.css` to dim null values visually.

## Connector Navigation (NavMenu)

`NavMenu.razor` lists all registered connectors from `ConnectorRegistry`. Clicking a connector navigates to `QueryExplorer` with the connector name as a route parameter:

```razor
@inject ConnectorRegistry Registry

@foreach (var connector in Registry.All)
{
    <RadzenPanelMenuItem Text="@connector.Metadata.DisplayName"
                         Icon="database"
                         Path="@($"/query/{connector.Metadata.Name}")" />
}
```

## Enforcement

- Schema is fetched once per connector selection and cached for the page lifetime — never call `GetSchemaAsync` in a render loop.
- Monaco editor initialization happens in `OnAfterRenderAsync` with `firstRender` guard — never in `OnInitializedAsync` (the DOM element does not exist yet).
- `ResultGrid` must handle `null` values gracefully — never call `.ToString()` without a null check.
- Binary column values (`byte[]`) must be displayed as a size label, not rendered as raw bytes.
- Execution errors are shown via `RadzenNotificationService` with `Duration = 0` (no auto-dismiss) — the user must acknowledge them.
- `_running` flag must be set to `false` in a `finally` block — never leave the UI in a permanent loading state on exception.
- `ConnectorRegistry` is injected as a singleton — do not call `GetRequiredService<ConnectorRegistry>()` inside components; use `@inject`.
