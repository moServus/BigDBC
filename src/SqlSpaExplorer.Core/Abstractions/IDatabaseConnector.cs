// V1: Blazor Example + Docker Infrastructure

using SqlSpaExplorer.Core.Models;

namespace SqlSpaExplorer.Core.Abstractions;

/// <summary>Contract every database connector must implement.</summary>
public interface IDatabaseConnector
{
    ConnectorMetadata Metadata { get; }

    Task<TabularResult> ExecuteQueryAsync(string query, CancellationToken cancellationToken = default);

    Task<SchemaMetadata> GetSchemaAsync(CancellationToken cancellationToken = default);

    Task<bool> TestConnectionAsync(CancellationToken cancellationToken = default);
}
