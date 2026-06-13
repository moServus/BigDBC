// V1: Blazor Example + Docker Infrastructure

using SqlSpaExplorer.Core.Abstractions;

namespace SqlSpaExplorer.Core.Registry;

/// <summary>
/// Holds all registered IDatabaseConnector instances.
/// Populated via DI — each connector project registers itself in its ServiceCollectionExtensions.
/// </summary>
public sealed class ConnectorRegistry
{
    private readonly Dictionary<string, IDatabaseConnector> _connectors;

    public ConnectorRegistry(IEnumerable<IDatabaseConnector> connectors)
    {
        _connectors = connectors.ToDictionary(c => c.Metadata.Id, StringComparer.OrdinalIgnoreCase);
    }

    public IReadOnlyCollection<IDatabaseConnector> All => _connectors.Values;

    public IDatabaseConnector? Get(string id) =>
        _connectors.GetValueOrDefault(id);

    public bool TryGet(string id, out IDatabaseConnector connector) =>
        _connectors.TryGetValue(id, out connector!);
}
