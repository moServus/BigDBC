# Skill: radzen-components

Covers Radzen.Blazor usage patterns in SqlSpaExplorer.

## Registration

In `Program.cs`:

```csharp
builder.Services.AddRadzenComponents();
```

In `MainLayout.razor` (or `App.razor`):

```razor
<RadzenComponents />
```

## RadzenDataGrid — Dynamic Columns

`TabularResult` has runtime-defined columns, so grid columns cannot be declared statically. Use the template approach:

```razor
<RadzenDataGrid Data="@_result.Rows" TItem="IReadOnlyList<object?>">
    <Columns>
        @foreach (var col in _result.Columns)
        {
            var colName = col; // capture for lambda
            <RadzenDataGridColumn TItem="IReadOnlyList<object?>" Title="@colName"
                Property="@colName">
                <Template Context="row">
                    @row[_result.Columns.IndexOf(colName)]
                </Template>
            </RadzenDataGridColumn>
        }
    </Columns>
</RadzenDataGrid>
```

Enable `AllowSorting="true"` and `AllowFiltering="true"` by default; pagination via `PageSize="50"`.

## Dialogs

Inject `RadzenDialogService` and use `OpenAsync<TComponent>` for confirmation or detail views:

```csharp
await _dialog.OpenAsync<ConfirmDialog>("Confirm", new Dictionary<string, object>
{
    { "Message", "Are you sure?" }
});
```

## Notifications

Inject `RadzenNotificationService` for transient toasts:

```csharp
_notify.Notify(NotificationSeverity.Error, "Query failed", ex.Message, duration: 5000);
_notify.Notify(NotificationSeverity.Success, "Done", $"{result.Rows.Count} rows in {result.Elapsed.TotalMilliseconds:F0} ms");
```

## Theming

Theme is set in `wwwroot/css/app.css` via a Radzen theme import. To switch theme, change the CSS file import — do not inline Radzen theme overrides in component files.
