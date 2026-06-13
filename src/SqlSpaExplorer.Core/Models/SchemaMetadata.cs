// V1: Blazor Example + Docker Infrastructure

namespace SqlSpaExplorer.Core.Models;

/// <summary>Schema introspection result — tables and columns — used to drive Monaco autocomplete.</summary>
public sealed class SchemaMetadata
{
    public IReadOnlyList<TableSchema> Tables { get; init; } = [];
}

public sealed record TableSchema(
    string SchemaName,
    string TableName,
    IReadOnlyList<ColumnSchema> Columns);

public sealed record ColumnSchema(
    string ColumnName,
    string DataType,
    bool IsNullable);
