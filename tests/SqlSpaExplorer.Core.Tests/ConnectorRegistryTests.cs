// V1: Blazor Example + Docker Infrastructure

using Xunit;
using SqlSpaExplorer.Core.Abstractions;
using SqlSpaExplorer.Core.Models;
using SqlSpaExplorer.Core.Registry;

namespace SqlSpaExplorer.Core.Tests;

public sealed class ConnectorRegistryTests
{
    [Fact]
    public void Get_ReturnsConnector_WhenIdMatches()
    {
        var connector = new FakeConnector("postgres");
        var registry = new ConnectorRegistry([connector]);

        var result = registry.Get("postgres");

        Assert.NotNull(result);
        Assert.Equal("postgres", result.Metadata.Id);
    }

    [Fact]
    public void Get_IsCaseInsensitive()
    {
        var registry = new ConnectorRegistry([new FakeConnector("postgres")]);

        Assert.NotNull(registry.Get("POSTGRES"));
    }

    [Fact]
    public void Get_ReturnsNull_WhenIdUnknown()
    {
        var registry = new ConnectorRegistry([]);

        Assert.Null(registry.Get("unknown"));
    }

    [Fact]
    public void All_ReturnsAllRegisteredConnectors()
    {
        var connectors = new IDatabaseConnector[]
        {
            new FakeConnector("postgres"),
            new FakeConnector("mongo"),
        };
        var registry = new ConnectorRegistry(connectors);

        Assert.Equal(2, registry.All.Count);
    }

    // ── Fake ────────────────────────────────────────────────────────────────────

    private sealed class FakeConnector(string id) : IDatabaseConnector
    {
        public ConnectorMetadata Metadata { get; } = new(id, id, "FakeDb");

        public Task<TabularResult> ExecuteQueryAsync(string query, CancellationToken ct = default) =>
            Task.FromResult(TabularResult.Empty());

        public Task<SchemaMetadata> GetSchemaAsync(CancellationToken ct = default) =>
            Task.FromResult(new SchemaMetadata());

        public Task<bool> TestConnectionAsync(CancellationToken ct = default) =>
            Task.FromResult(true);
    }
}
