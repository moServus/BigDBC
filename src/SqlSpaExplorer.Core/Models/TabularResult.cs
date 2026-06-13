// V1: Blazor Example + Docker Infrastructure

namespace SqlSpaExplorer.Core.Models;

/// <summary>
/// Universal result shape returned by every IDatabaseConnector.
/// RadzenDataGrid renders this identically regardless of the source database.
/// </summary>
public sealed class TabularResult
{
    public IReadOnlyList<string> Columns { get; init; } = [];
    public IReadOnlyList<IReadOnlyList<object?>> Rows { get; init; } = [];
    public int RowCount => Rows.Count;
    public TimeSpan Elapsed { get; init; }
    public string? WarningMessage { get; init; }

    public static TabularResult Empty(TimeSpan elapsed = default) =>
        new() { Elapsed = elapsed };
}
