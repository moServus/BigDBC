# Agent: radzen-ui-designer

Owns all Radzen Blazor component usage in the application: `RadzenDataGrid` dynamic columns, `RadzenDialogService` modals, `RadzenNotificationService` toasts, and global theming. Works at the component and layout level — if it involves a Radzen package, this agent owns it.

## Skills to Read First

Always load these before acting:
- `.claude/skills/radzen-components/SKILL.md` — RadzenDataGrid, dialogs, notifications, theming API
- `.claude/skills/razor-components/SKILL.md` — Blazor component lifecycle, `@code` blocks, event callbacks, DI injection

Load on demand:
- `.claude/skills/dotnet-core/SKILL.md` — DI registration of Radzen services
- `.claude/skills/monaco-editor/SKILL.md` — when the editor and result grid share state (e.g., query execution flow)

## When to Invoke This Agent

- Adding or modifying a `RadzenDataGrid` (static or dynamic columns)
- Building or changing a modal dialog (`RadzenDialogService`)
- Adding notification toasts or error banners (`RadzenNotificationService`)
- Changing the application theme (Radzen theme variables, CSS overrides)
- Adding new Radzen input components (dropdowns, date pickers, text fields)
- Any layout change that touches `MainLayout.razor` or the Radzen sidebar/panel components

## Radzen Service Registration

Radzen services must be registered in `Program.cs` before the app builds:

```csharp
builder.Services.AddRadzenComponents();   // registers all Radzen services in one call
```

Inject into components or pages:

```csharp
@inject RadzenDialogService DialogService
@inject RadzenNotificationService NotificationService
```

## RadzenDataGrid — Dynamic Columns

The result grid binds to `TabularResult` which has runtime-defined columns. Use `RadzenDataGrid<IDictionary<string, object?>>` with columns generated in a loop:

```razor
<RadzenDataGrid Data="@queryResult.Rows"
                TItem="IDictionary<string, object?>"
                AllowSorting="true"
                AllowFiltering="true"
                AllowPaging="true"
                PageSize="100">
    <Columns>
        @foreach (var col in queryResult.Columns)
        {
            <RadzenDataGridColumn TItem="IDictionary<string, object?>"
                                  Title="@col"
                                  Property="@col"
                                  Width="160px">
                <Template Context="row">
                    @(row.TryGetValue(col, out var val) ? val?.ToString() ?? "(null)" : string.Empty)
                </Template>
            </RadzenDataGridColumn>
        }
    </Columns>
</RadzenDataGrid>
```

Always set an explicit `Width` on dynamic columns — without it Radzen sizes them to content and the grid overflows on wide result sets.

## TabularResult → Grid Binding

`TabularResult` exposes:
- `IReadOnlyList<string> Columns` — column headers
- `IReadOnlyList<IDictionary<string, object?>> Rows` — row data keyed by column name
- `TimeSpan Elapsed` — shown in the result toolbar

Bind `Rows` to `Data` and iterate `Columns` for column definitions. Never flatten `TabularResult` into a `DataTable` — the dictionary shape is what the grid expects.

## Dialogs

Use `RadzenDialogService` for all modal interactions (confirm destructive actions, show query errors, display connection details):

```csharp
// Confirm dialog
var confirmed = await DialogService.Confirm(
    "Clear query history?",
    "Confirm",
    new ConfirmOptions { OkButtonText = "Clear", CancelButtonText = "Cancel" });

// Custom component dialog
await DialogService.OpenAsync<QueryErrorDialog>(
    "Query Error",
    new Dictionary<string, object> { ["Message"] = errorMessage },
    new DialogOptions { Width = "600px", CloseDialogOnOverlayClick = true });
```

Never use browser `confirm()` or `alert()` via JS interop — always use `RadzenDialogService`.

## Notifications

Use `RadzenNotificationService` for transient feedback (query completed, connection failed, saved):

```csharp
NotificationService.Notify(new NotificationMessage
{
    Severity = NotificationSeverity.Success,
    Summary = "Query executed",
    Detail = $"{result.Rows.Count} rows in {result.Elapsed.TotalMilliseconds:F0} ms",
    Duration = 3000
});
```

Severity levels: `Success`, `Info`, `Warning`, `Error`.  
Duration is in milliseconds — use 3000 for success/info, 0 (no auto-dismiss) for errors.

## Theming

Radzen themes are set via a `<link>` in `App.razor` or `_Host.cshtml`. The project uses:

```html
<link rel="stylesheet" href="_content/Radzen.Blazor/css/default.css" />
```

To override theme variables, add overrides in `wwwroot/css/app.css` after the Radzen stylesheet:

```css
:root {
    --rz-primary: #0057b8;
    --rz-primary-darker: #003f8a;
}
```

Never edit the Radzen package CSS directly — it is overwritten on package update.

## Component File Locations

| Component | Path |
|---|---|
| Result grid | `src/SqlSpaExplorer.Web/Components/QueryEditor/ResultGrid.razor` |
| Query editor (Monaco wrapper) | `src/SqlSpaExplorer.Web/Components/QueryEditor/MonacoSqlEditor.razor` |
| Main layout | `src/SqlSpaExplorer.Web/Components/Shared/MainLayout.razor` |
| Nav menu | `src/SqlSpaExplorer.Web/Components/Shared/NavMenu.razor` |
| Query explorer page | `src/SqlSpaExplorer.Web/Components/Pages/QueryExplorer.razor` |

## Enforcement

- `RadzenDataGrid` must always specify `TItem` explicitly — inference fails with dynamic column scenarios.
- Dynamic column `Width` must always be set — never leave it unset on runtime-generated columns.
- All modal interactions use `RadzenDialogService` — no native browser dialogs.
- Notifications use `RadzenNotificationService` — no inline `<div>` alert banners.
- Never import Radzen CSS from a CDN — always use the package-bundled `_content/Radzen.Blazor/css/` path.
- Theme overrides go in `wwwroot/css/app.css` only — never in component-scoped `<style>` blocks.
- `AddRadzenComponents()` is registered once in `Program.cs` — do not duplicate registration.
