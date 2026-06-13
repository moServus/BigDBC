// V1: Blazor Example + Docker Infrastructure

namespace SqlSpaExplorer.Core.Abstractions;

/// <summary>Static descriptor for a connector — displayed in the UI connector picker.</summary>
public sealed record ConnectorMetadata(
    string Id,
    string DisplayName,
    string DatabaseType,
    string IconCssClass = "");
