// V1: Blazor Example + Docker Infrastructure

using Xunit;
using SqlSpaExplorer.Core.Models;

namespace SqlSpaExplorer.Core.Tests;

public sealed class TabularResultTests
{
    [Fact]
    public void Empty_ReturnsZeroRowCount()
    {
        var result = TabularResult.Empty();

        Assert.Equal(0, result.RowCount);
        Assert.Empty(result.Columns);
        Assert.Empty(result.Rows);
    }

    [Fact]
    public void RowCount_MatchesRowsCount()
    {
        var result = new TabularResult
        {
            Columns = ["id", "name"],
            Rows =
            [
                [1, "Alice"],
                [2, "Bob"],
            ]
        };

        Assert.Equal(2, result.RowCount);
    }
}
