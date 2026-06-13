# V1: Blazor Example + Docker Infrastructure
# Cross-platform first-time setup: prerequisites, .env, image pull, dotnet restore, proto stack up.
# Usage: pwsh ./setup.ps1

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "    OK   $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "    WARN $msg" -ForegroundColor Yellow }

# ── 1. Prerequisites ────────────────────────────────────────────────────────────
Write-Step "Checking prerequisites"

foreach ($tool in @('docker', 'dotnet', 'pwsh')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool not found: $tool. Install it and re-run."
    }
    Write-Ok "$tool found"
}

# ── 2. .env file ───────────────────────────────────────────────────────────────
Write-Step "Checking docker/.env"
$envFile    = Join-Path $PSScriptRoot 'docker/.env'
$envExample = Join-Path $PSScriptRoot 'docker/.env.example'

if (-not (Test-Path $envFile)) {
    Copy-Item $envExample $envFile
    Write-Warn ".env created from .env.example — edit docker/.env and set real passwords before production use"
} else {
    Write-Ok ".env already exists"
}

# ── 3. Pull Docker images (proto stack) ─────────────────────────────────────────
Write-Step "Pulling Docker images for proto stack"
Push-Location (Join-Path $PSScriptRoot 'docker')
try {
    docker compose -f docker-compose.proto.yml pull
    Write-Ok "Images pulled"
} finally {
    Pop-Location
}

# ── 4. Restore .NET packages ────────────────────────────────────────────────────
Write-Step "Restoring .NET packages"
dotnet restore (Join-Path $PSScriptRoot 'src/SqlSpaExplorer.sln')
Write-Ok "Packages restored"

# ── 5. Build and start proto stack ──────────────────────────────────────────────
Write-Step "Building and starting proto stack (metaMongoDB + bigdbc)"
Push-Location (Join-Path $PSScriptRoot 'docker')
try {
    docker compose -f docker-compose.proto.yml up -d --build
    Write-Ok "Proto stack started"
} finally {
    Pop-Location
}

Write-Host "`nSetup complete." -ForegroundColor Green
Write-Host "App:     http://localhost:42080" -ForegroundColor White
Write-Host "MongoDB: localhost:40217" -ForegroundColor White
Write-Host "`nRun 'dotnet run --project src/SqlSpaExplorer.Web' to run the app locally (outside Docker)." -ForegroundColor DarkGray
