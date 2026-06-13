# Skill: powershell-scripts

Covers `setup.ps1` and any other cross-platform PowerShell scripts in the repo root.

## setup.ps1 — Purpose

One-command first-time setup on a fresh machine. It:
1. Checks prerequisites (Docker/OrbStack, .NET 8 SDK, `dotnet ef` global tool).
2. Copies `docker/.env.example` → `docker/.env` if `.env` doesn't exist yet.
3. Pulls all DB Docker images (including `linux/amd64` images that need Rosetta).
4. Runs `docker compose up -d` to start the stack.
5. Runs `dotnet restore` on the solution.
6. Applies pending EF migrations for all four EF providers.

## Cross-Platform Notes

Scripts target **PowerShell 7+** (`pwsh`), not Windows PowerShell 5. This runs on macOS, Linux, and Windows:

```powershell
#!/usr/bin/env pwsh
#Requires -Version 7
```

Use `$IsWindows`, `$IsMacOS`, `$IsLinux` guards for platform-specific paths — avoid hardcoded `/` vs `\` separators; use `Join-Path` instead.

## Image List Maintenance

`setup.ps1` contains an explicit list of images to pull. When adding a new database, update this list:

```powershell
$images = @(
    'postgres:16',
    'mcr.microsoft.com/mssql/server:2022-latest',
    'gvenzl/oracle-free:latest',
    'mongo:7',
    'exasol/docker-db:latest'
)
foreach ($img in $images) {
    docker pull $img
}
```

## EF Migration Step

The migration loop iterates over the four EF provider project paths:

```powershell
$efProjects = @(
    'src/SqlSpaExplorer.Connectors.Postgres',
    'src/SqlSpaExplorer.Connectors.SqlServer',
    'src/SqlSpaExplorer.Connectors.Oracle',
    'src/SqlSpaExplorer.Connectors.Sqlite'
)
foreach ($proj in $efProjects) {
    dotnet ef database update --project $proj
}
```

Do **not** add Exasol or MongoDB to this list — they have no EF migrations.

## Error Handling

Use `$ErrorActionPreference = 'Stop'` at the top so any failed command aborts the script immediately. Print a friendly message before each major step so users can see progress.
