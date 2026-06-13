// V1: Blazor Example + Docker Infrastructure
// Integration smoke tests — require the Docker-compose stack to be running.
// Run: docker compose -f docker/docker-compose.proto.yml up -d
//      dotnet test tests/SqlSpaExplorer.Connectors.Tests

using Xunit;

namespace SqlSpaExplorer.Connectors.Tests;

// Placeholder — connector-specific test classes go here (one per connector).
// Each class should inherit a base that resolves the connector from DI
// and calls TestConnectionAsync() + ExecuteQueryAsync() with a simple SELECT.
public sealed class ConnectorSmokeTest
{
    [Fact(Skip = "Placeholder — implement per-connector smoke tests")]
    public void Placeholder() { }
}
