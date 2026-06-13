# Skill: razor-components

Covers Blazor/Razor component conventions for `SqlSpaExplorer.Web`.

## Component Locations

| Path | Purpose |
|---|---|
| `Components/Pages/` | Routable pages (`@page` directive) |
| `Components/Shared/` | Layout and global nav (`MainLayout.razor`, `NavMenu.razor`) |
| `Components/QueryEditor/` | Reusable query-input and result-display components |

## Page Routing

Pages use `@page "/path"`. The `QueryExplorer.razor` page is the main feature page and receives the active connector name as a route or query parameter.

## Component Parameter Pattern

Use `[Parameter]` for public inputs. Prefer `EventCallback<T>` over `Action<T>` for child→parent events so Blazor's render cycle stays consistent:

```razor
[Parameter] public string ConnectorName { get; set; } = string.Empty;
[Parameter] public EventCallback<TabularResult> OnQueryExecuted { get; set; }
```

## State and Rendering

- Keep business logic (DB calls) in injected services or connectors — not in component code-behind.
- Use `StateHasChanged()` after async operations that mutate visible state.
- Wrap long-running connector calls in `try/catch` and surface errors via `RadzenNotificationService` (see `radzen-components` skill).

## JS Interop

Monaco Editor interop lives in `MonacoSqlEditor.razor` and `wwwroot/js/monaco-interop.js`. Use `IJSRuntime.InvokeVoidAsync` / `InvokeAsync<T>` for all JS calls. Never call JS from a constructor or `OnInitialized` — use `OnAfterRenderAsync(firstRender: true)`.

## Layout

`MainLayout.razor` wraps all pages. The nav sidebar lists connectors dynamically from `ConnectorRegistry`. Clicking a connector name navigates to `QueryExplorer` with that connector pre-selected.
