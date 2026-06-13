# Stage 1: build & publish
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY src/SqlSpaExplorer.sln ./
COPY src/SqlSpaExplorer.Web/SqlSpaExplorer.Web.csproj                         SqlSpaExplorer.Web/
COPY src/SqlSpaExplorer.Core/SqlSpaExplorer.Core.csproj                       SqlSpaExplorer.Core/
COPY src/SqlSpaExplorer.Connectors.Postgres/SqlSpaExplorer.Connectors.Postgres.csproj   SqlSpaExplorer.Connectors.Postgres/
COPY src/SqlSpaExplorer.Connectors.SqlServer/SqlSpaExplorer.Connectors.SqlServer.csproj SqlSpaExplorer.Connectors.SqlServer/
COPY src/SqlSpaExplorer.Connectors.Oracle/SqlSpaExplorer.Connectors.Oracle.csproj       SqlSpaExplorer.Connectors.Oracle/
COPY src/SqlSpaExplorer.Connectors.Sqlite/SqlSpaExplorer.Connectors.Sqlite.csproj       SqlSpaExplorer.Connectors.Sqlite/
COPY src/SqlSpaExplorer.Connectors.Mongo/SqlSpaExplorer.Connectors.Mongo.csproj         SqlSpaExplorer.Connectors.Mongo/
COPY src/SqlSpaExplorer.Connectors.Exasol/SqlSpaExplorer.Connectors.Exasol.csproj       SqlSpaExplorer.Connectors.Exasol/

RUN dotnet restore SqlSpaExplorer.sln

COPY src/ .
RUN dotnet publish SqlSpaExplorer.Web/SqlSpaExplorer.Web.csproj \
      -c Release -o /app/publish --no-restore

# Stage 2: runtime (arm64-native; CI builds both amd64 and arm64 via QEMU)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet", "SqlSpaExplorer.Web.dll"]
